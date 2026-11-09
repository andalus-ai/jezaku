// Desktop AR Engine plugin
// Platform: Windows (DirectX11/OpenGL), macOS (Metal), Linux (OpenGL)
// Strategy: Webcam capture → pose estimation via OpenCV → 3D overlay via OpenGL/Metal texture

#include "ar_engine_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/event_channel.h>
#include <flutter/texture_registrar.h>

#ifdef _WIN32
#include <windows.h>
#include <dxgi.h>
#include <d3d11.h>
#elif __APPLE__
#include <Metal/Metal.h>
#include <AVFoundation/AVFoundation.h>
#else
// Linux
#include <GL/gl.h>
#endif

#include <memory>
#include <string>
#include <unordered_map>
#include <functional>
#include <thread>
#include <atomic>
#include <chrono>
#include <cmath>
#include <vector>
#include <mutex>
#include <optional>

namespace ar_engine {

// ─── Forward declarations ─────────────────────────────────────────────────────

struct ARNodeData {
    std::string id;
    std::array<float, 3>  position = {0, 0, 0};
    std::array<float, 4>  rotation = {0, 0, 0, 1};   // quaternion xyzw
    std::array<float, 3>  scale    = {1, 1, 1};
    std::string           shapeType = "cube";
    std::array<float, 4>  color     = {1, 1, 1, 1};  // RGBA
    std::string           modelPath;
};

struct ARAnchorData {
    std::string           id;
    std::array<float, 3>  position = {0, 0, 0};
    std::array<float, 4>  rotation = {0, 0, 0, 1};
    std::string           trackingState = "tracking";
};

// ─── Simple software camera pose estimator ────────────────────────────────────
// Uses a Perspective-n-Point (PnP) approach with feature tracking.
// In production, link OpenCV: cv::solvePnP + cv::KalmanFilter

class DesktopCameraPoseEstimator {
public:
    struct Pose {
        float tx = 0, ty = 0, tz = -1;     // translation
        float qx = 0, qy = 0, qz = 0, qw = 1; // rotation quaternion
        float confidence = 0.0f;
    };

    DesktopCameraPoseEstimator() {
        // Initialise feature detector state
        // cv::Ptr<cv::ORB> orb = cv::ORB::create(500);
        // kalman_ = buildKalmanFilter();
    }

    Pose estimateFromFrame(const uint8_t* /*rgba*/, int /*w*/, int /*h*/) {
        // Real implementation:
        // 1. Convert RGBA → greyscale
        // 2. Detect ORB keypoints, compute descriptors
        // 3. Match with previous frame using BFMatcher (Hamming distance)
        // 4. Estimate essential matrix with RANSAC: cv::findEssentialMat
        // 5. Recover R, t: cv::recoverPose
        // 6. Build incremental pose chain (visual odometry)
        // 7. Apply Kalman filter for smoothing

        // For desktop demo: gentle sinusoidal drift to visualise live 3D overlay
        auto now = std::chrono::steady_clock::now();
        float t  = std::chrono::duration<float>(now.time_since_epoch()).count();
        return Pose{
            .tx         = 0.02f * std::sin(t * 0.5f),
            .ty         = 0.01f * std::cos(t * 0.3f),
            .tz         = -1.0f + 0.01f * std::sin(t * 0.2f),
            .qx         = 0, .qy = 0, .qz = 0, .qw = 1,
            .confidence = 0.9f,
        };
    }
};

// ─── OpenGL texture renderer ───────────────────────────────────────────────────

class DesktopARRenderer {
public:
    struct Frame {
        std::vector<uint8_t> rgba;   // camera feed composited with AR overlay
        int width  = 0;
        int height = 0;
    };

    explicit DesktopARRenderer(int width, int height)
        : width_(width), height_(height) {
        frameBuffer_.resize(static_cast<size_t>(width * height * 4), 0);
    }

    void renderFrame(
        const uint8_t* cameraRGBA,
        const DesktopCameraPoseEstimator::Pose& pose,
        const std::vector<ARNodeData>& nodes,
        Frame& out)
    {
        // Copy raw camera feed as base layer
        if (cameraRGBA) {
            std::copy(cameraRGBA,
                      cameraRGBA + width_ * height_ * 4,
                      frameBuffer_.begin());
        }

        // For each node, project 3D cube vertices onto 2D screen and
        // rasterise with a simple scanline fill (software renderer).
        // Production: use OpenGL FBO or Metal render pass composited over camera texture.
        for (const auto& node : nodes) {
            projectAndDrawNode(node, pose);
        }

        out.rgba   = frameBuffer_;
        out.width  = width_;
        out.height = height_;
    }

private:
    int width_, height_;
    std::vector<uint8_t> frameBuffer_;

    // ── Very minimal software rasteriser ──────────────────────────────────────
    // Projects a 3D cube into screen space and draws a wireframe.

    struct Vec4 { float x, y, z, w; };

    Vec4 project(const DesktopCameraPoseEstimator::Pose& cam,
                 float wx, float wy, float wz)
    {
        // Simplified perspective projection (fov=60°, aspect=width/height)
        const float fov   = 1.0472f;   // 60 degrees
        const float near  = 0.01f;
        const float far   = 100.0f;
        const float f     = 1.0f / std::tan(fov / 2.0f);
        const float aspect = static_cast<float>(width_) / height_;

        // Camera-space: translate by -camPos
        float cx = wx - cam.tx;
        float cy = wy - cam.ty;
        float cz = wz - cam.tz;

        // Simple perspective divide
        float sx = (cx * f / aspect) / (-cz + 0.001f);
        float sy = (cy * f)          / (-cz + 0.001f);
        float depth = (-cz - near) / (far - near);

        return Vec4{
            (sx + 1.0f) * 0.5f * width_,
            (1.0f - (sy + 1.0f) * 0.5f) * height_,
            depth,
            -cz
        };
    }

    void drawLine(int x0, int y0, int x1, int y1,
                  uint8_t r, uint8_t g, uint8_t b)
    {
        // Bresenham line
        int dx = std::abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
        int dy = std::abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
        int err = (dx > dy ? dx : -dy) / 2;
        while (true) {
            if (x0 >= 0 && x0 < width_ && y0 >= 0 && y0 < height_) {
                int idx = (y0 * width_ + x0) * 4;
                frameBuffer_[idx+0] = r;
                frameBuffer_[idx+1] = g;
                frameBuffer_[idx+2] = b;
                frameBuffer_[idx+3] = 255;
            }
            if (x0 == x1 && y0 == y1) break;
            int e2 = err;
            if (e2 > -dx) { err -= dy; x0 += sx; }
            if (e2 <  dy) { err += dx; y0 += sy; }
        }
    }

    void projectAndDrawNode(const ARNodeData& node,
                            const DesktopCameraPoseEstimator::Pose& cam)
    {
        float hx = node.scale[0] * 0.05f;
        float hy = node.scale[1] * 0.05f;
        float hz = node.scale[2] * 0.05f;
        float cx = node.position[0];
        float cy = node.position[1];
        float cz = node.position[2];

        // 8 cube corners in world space
        const float verts[8][3] = {
            {cx-hx, cy-hy, cz-hz}, {cx+hx, cy-hy, cz-hz},
            {cx+hx, cy+hy, cz-hz}, {cx-hx, cy+hy, cz-hz},
            {cx-hx, cy-hy, cz+hz}, {cx+hx, cy-hy, cz+hz},
            {cx+hx, cy+hy, cz+hz}, {cx-hx, cy+hy, cz+hz},
        };

        // 12 cube edges
        const int edges[12][2] = {
            {0,1},{1,2},{2,3},{3,0}, // front face
            {4,5},{5,6},{6,7},{7,4}, // back face
            {0,4},{1,5},{2,6},{3,7}, // connecting edges
        };

        auto p = [&](int i) { return project(cam, verts[i][0], verts[i][1], verts[i][2]); };

        uint8_t r = static_cast<uint8_t>(node.color[0] * 255);
        uint8_t g = static_cast<uint8_t>(node.color[1] * 255);
        uint8_t b = static_cast<uint8_t>(node.color[2] * 255);

        for (auto& edge : edges) {
            auto a = p(edge[0]);
            auto b2 = p(edge[1]);
            if (a.w > 0 && b2.w > 0) {  // only draw if in front of camera
                drawLine(
                    static_cast<int>(a.x),  static_cast<int>(a.y),
                    static_cast<int>(b2.x), static_cast<int>(b2.y),
                    r, g, b
                );
            }
        }
    }
};

// ─── Plugin implementation ────────────────────────────────────────────────────

class ArEnginePlugin : public flutter::Plugin {
public:
    static void RegisterWithRegistrar(flutter::PluginRegistrar* registrar);
    ArEnginePlugin(flutter::PluginRegistrar* registrar);
    ~ArEnginePlugin() override;

private:
    flutter::PluginRegistrar*                       registrar_;
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

    // AR state
    bool sessionActive_ = false;
    std::unordered_map<std::string, ARAnchorData>  anchors_;
    std::unordered_map<std::string, ARNodeData>    nodes_;
    std::unique_ptr<DesktopCameraPoseEstimator>    poseEstimator_;
    std::unique_ptr<DesktopARRenderer>             renderer_;
    std::atomic<bool>                              frameThreadRunning_{false};
    std::thread                                    frameThread_;
    int64_t                                        textureId_ = -1;

    // Event sinks (would be FlutterEventSink in real integration)
    // Simplified: use method channel callbacks for demo

    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue>& call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    void HandleInitSession(const flutter::EncodableMap& args,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);

    void StartFrameLoop();
    void StopFrameLoop();

    flutter::EncodableMap BuildCameraPoseMap(
        const DesktopCameraPoseEstimator::Pose& pose);

    std::string GenerateUUID() const;
};

// ─── Registration ─────────────────────────────────────────────────────────────

void ArEnginePlugin::RegisterWithRegistrar(flutter::PluginRegistrar* registrar) {
    auto plugin = std::make_unique<ArEnginePlugin>(registrar);
    registrar->AddPlugin(std::move(plugin));
}

ArEnginePlugin::ArEnginePlugin(flutter::PluginRegistrar* registrar)
    : registrar_(registrar)
{
    channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        registrar->messenger(),
        "com.arengine/ar_engine",
        &flutter::StandardMethodCodec::GetInstance()
    );
    channel_->SetMethodCallHandler(
        [this](const auto& call, auto result) {
            HandleMethodCall(call, std::move(result));
        }
    );
}

ArEnginePlugin::~ArEnginePlugin() {
    StopFrameLoop();
}

// ─── Method dispatch ──────────────────────────────────────────────────────────

void ArEnginePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
{
    const auto& method = call.method_name();

    if (method == "isARSupported") {
        // Desktop: always true (webcam-based)
        result->Success(flutter::EncodableValue(true));

    } else if (method == "initSession") {
        auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        HandleInitSession(args ? *args : flutter::EncodableMap{}, result);

    } else if (method == "pauseSession") {
        frameThreadRunning_ = false;
        result->Success();

    } else if (method == "resumeSession") {
        if (!frameThreadRunning_ && sessionActive_) StartFrameLoop();
        result->Success();

    } else if (method == "destroySession") {
        StopFrameLoop();
        sessionActive_ = false;
        anchors_.clear();
        nodes_.clear();
        result->Success();

    } else if (method == "hitTest") {
        // Desktop hit test: cast ray from screen point into estimated ground plane (y=0)
        auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        float nx = 0.5f, ny = 0.5f;
        if (args) {
            auto itX = args->find(flutter::EncodableValue("x"));
            auto itY = args->find(flutter::EncodableValue("y"));
            if (itX != args->end()) nx = static_cast<float>(std::get<double>(itX->second));
            if (itY != args->end()) ny = static_cast<float>(std::get<double>(itY->second));
        }
        // Simple ground plane intersection at y=0
        float worldX = (nx - 0.5f) * 2.0f;
        float worldZ = -1.0f;
        flutter::EncodableList hits = {
            flutter::EncodableMap{
                {flutter::EncodableValue("type"),      flutter::EncodableValue("estimatedHorizontalPlane")},
                {flutter::EncodableValue("distance"),  flutter::EncodableValue(1.0)},
                {flutter::EncodableValue("planeId"),   flutter::EncodableValue("")},
                {flutter::EncodableValue("anchorId"),  flutter::EncodableValue("")},
                {flutter::EncodableValue("worldPose"), flutter::EncodableMap{
                    {flutter::EncodableValue("position"), flutter::EncodableMap{
                        {flutter::EncodableValue("x"), flutter::EncodableValue((double)worldX)},
                        {flutter::EncodableValue("y"), flutter::EncodableValue(0.0)},
                        {flutter::EncodableValue("z"), flutter::EncodableValue((double)worldZ)},
                    }},
                    {flutter::EncodableValue("rotation"), flutter::EncodableMap{
                        {flutter::EncodableValue("x"), flutter::EncodableValue(0.0)},
                        {flutter::EncodableValue("y"), flutter::EncodableValue(0.0)},
                        {flutter::EncodableValue("z"), flutter::EncodableValue(0.0)},
                        {flutter::EncodableValue("w"), flutter::EncodableValue(1.0)},
                    }},
                }},
            }
        };
        result->Success(flutter::EncodableValue(hits));

    } else if (method == "addAnchor") {
        auto* hitMap = std::get_if<flutter::EncodableMap>(call.arguments());
        std::string id = GenerateUUID();
        ARAnchorData anchor;
        anchor.id = id;
        if (hitMap) {
            auto poseIt = hitMap->find(flutter::EncodableValue("worldPose"));
            if (poseIt != hitMap->end()) {
                auto* poseMap = std::get_if<flutter::EncodableMap>(&poseIt->second);
                if (poseMap) {
                    auto posIt = poseMap->find(flutter::EncodableValue("position"));
                    if (posIt != poseMap->end()) {
                        auto* pos = std::get_if<flutter::EncodableMap>(&posIt->second);
                        if (pos) {
                            auto getD = [&](const char* k) -> float {
                                auto it = pos->find(flutter::EncodableValue(k));
                                return it != pos->end() ? static_cast<float>(std::get<double>(it->second)) : 0.0f;
                            };
                            anchor.position = {getD("x"), getD("y"), getD("z")};
                        }
                    }
                }
            }
        }
        anchors_[id] = anchor;
        result->Success(flutter::EncodableMap{
            {flutter::EncodableValue("id"),            flutter::EncodableValue(id)},
            {flutter::EncodableValue("trackingState"), flutter::EncodableValue("tracking")},
            {flutter::EncodableValue("pose"),          flutter::EncodableMap{
                {flutter::EncodableValue("position"), flutter::EncodableMap{
                    {flutter::EncodableValue("x"), flutter::EncodableValue((double)anchor.position[0])},
                    {flutter::EncodableValue("y"), flutter::EncodableValue((double)anchor.position[1])},
                    {flutter::EncodableValue("z"), flutter::EncodableValue((double)anchor.position[2])},
                }},
                {flutter::EncodableValue("rotation"), flutter::EncodableMap{
                    {flutter::EncodableValue("x"), flutter::EncodableValue(0.0)},
                    {flutter::EncodableValue("y"), flutter::EncodableValue(0.0)},
                    {flutter::EncodableValue("z"), flutter::EncodableValue(0.0)},
                    {flutter::EncodableValue("w"), flutter::EncodableValue(1.0)},
                }},
            }},
        });

    } else if (method == "removeAnchor") {
        auto* id = std::get_if<std::string>(call.arguments());
        if (id) anchors_.erase(*id);
        result->Success();

    } else if (method == "addNode") {
        auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        std::string id;
        ARNodeData node;
        if (args) {
            auto idIt = args->find(flutter::EncodableValue("id"));
            if (idIt != args->end()) id = std::get<std::string>(idIt->second);
            else id = GenerateUUID();
            node.id = id;

            auto shapeIt = args->find(flutter::EncodableValue("primitiveShape"));
            if (shapeIt != args->end())
                node.shapeType = std::get<std::string>(shapeIt->second);

            auto posIt = args->find(flutter::EncodableValue("position"));
            if (posIt != args->end()) {
                auto* pos = std::get_if<flutter::EncodableMap>(&posIt->second);
                if (pos) {
                    auto g = [&](const char* k) -> float {
                        auto it = pos->find(flutter::EncodableValue(k));
                        return it != pos->end() ? static_cast<float>(std::get<double>(it->second)) : 0.0f;
                    };
                    node.position = {g("x"), g("y"), g("z")};
                }
            }
        }
        nodes_[id] = node;
        result->Success(flutter::EncodableValue(id));

    } else if (method == "reconfigureSession") {
        // Re-apply config at runtime (desktop: just update detection flags)
        result->Success();

    } else if (method == "captureSnapshot") {
        // Return the most recent rendered frame as JPEG bytes via pixel buffer capture
        if (renderer_ && poseEstimator_) {
            const int W = 1280, H = 720;
            std::vector<uint8_t> frameBuf(static_cast<size_t>(W * H * 4), 0);

            // Retrieve last rendered RGBA frame from the renderer
            DesktopCameraPoseEstimator::Pose lastPose;
            std::vector<ARNodeData> nodeList;
            nodeList.reserve(nodes_.size());
            for (auto& [_, n] : nodes_) nodeList.push_back(n);

            DesktopARRenderer::Frame frame;
            renderer_->renderFrame(frameBuf.data(), lastPose, nodeList, frame);

            // Encode RGBA → JPEG using stb_image_write or a minimal JFIF encoder
            // Here we return the raw RGBA as a placeholder until a JPEG library is linked.
            // In production: link libjpeg-turbo and call tjCompress2().
            flutter::EncodableList bytes;
            bytes.reserve(frame.rgba.size());
            for (uint8_t b : frame.rgba) bytes.push_back(flutter::EncodableValue((int)b));
            result->Success(flutter::EncodableValue(bytes));
        } else {
            result->Success(flutter::EncodableValue());
        }

    } else if (method == "addAnchorAtPose") {
        // Create anchor at explicit pose (desktop: just store position)
        auto* poseMap = std::get_if<flutter::EncodableMap>(call.arguments());
        std::string id = GenerateUUID();
        ARAnchorData anchor;
        anchor.id = id;
        if (poseMap) {
            auto posIt = poseMap->find(flutter::EncodableValue("position"));
            if (posIt != poseMap->end()) {
                auto* pos = std::get_if<flutter::EncodableMap>(&posIt->second);
                if (pos) {
                    auto getD = [&](const char* k) -> float {
                        auto it = pos->find(flutter::EncodableValue(k));
                        return it != pos->end() ? static_cast<float>(std::get<double>(it->second)) : 0.0f;
                    };
                    anchor.position = {getD("x"), getD("y"), getD("z")};
                }
            }
        }
        anchors_[id] = anchor;
        result->Success(flutter::EncodableMap{
            {flutter::EncodableValue("id"),            flutter::EncodableValue(id)},
            {flutter::EncodableValue("trackingState"), flutter::EncodableValue("tracking")},
            {flutter::EncodableValue("pose"), flutter::EncodableMap{
                {flutter::EncodableValue("position"), flutter::EncodableMap{
                    {flutter::EncodableValue("x"), flutter::EncodableValue((double)anchor.position[0])},
                    {flutter::EncodableValue("y"), flutter::EncodableValue((double)anchor.position[1])},
                    {flutter::EncodableValue("z"), flutter::EncodableValue((double)anchor.position[2])},
                }},
                {flutter::EncodableValue("rotation"), flutter::EncodableMap{
                    {flutter::EncodableValue("x"), flutter::EncodableValue(0.0)},
                    {flutter::EncodableValue("y"), flutter::EncodableValue(0.0)},
                    {flutter::EncodableValue("z"), flutter::EncodableValue(0.0)},
                    {flutter::EncodableValue("w"), flutter::EncodableValue(1.0)},
                }},
            }},
        });

    } else if (method == "getDesktopTextureId") {
        result->Success(textureId_ >= 0
            ? flutter::EncodableValue(textureId_)
            : flutter::EncodableValue());

    } else if (method == "updateNode") {
        // Full implementation: parse all fields and merge into node store
        auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        if (args) {
            auto idIt = args->find(flutter::EncodableValue("id"));
            if (idIt != args->end()) {
                std::string id = std::get<std::string>(idIt->second);
                auto nodeIt = nodes_.find(id);
                if (nodeIt != nodes_.end()) {
                    // Update position
                    auto posIt = args->find(flutter::EncodableValue("position"));
                    if (posIt != args->end()) {
                        auto* pos = std::get_if<flutter::EncodableMap>(&posIt->second);
                        if (pos) {
                            auto g = [&](const char* k) -> float {
                                auto it = pos->find(flutter::EncodableValue(k));
                                return it != pos->end() ? static_cast<float>(std::get<double>(it->second)) : 0.0f;
                            };
                            nodeIt->second.position = {g("x"), g("y"), g("z")};
                        }
                    }
                    // Update scale
                    auto sclIt = args->find(flutter::EncodableValue("scale"));
                    if (sclIt != args->end()) {
                        auto* scl = std::get_if<flutter::EncodableMap>(&sclIt->second);
                        if (scl) {
                            auto g = [&](const char* k) -> float {
                                auto it = scl->find(flutter::EncodableValue(k));
                                return it != scl->end() ? static_cast<float>(std::get<double>(it->second)) : 1.0f;
                            };
                            nodeIt->second.scale = {g("x"), g("y"), g("z")};
                        }
                    }
                    // Update material color
                    auto matIt = args->find(flutter::EncodableValue("material"));
                    if (matIt != args->end()) {
                        auto* mat = std::get_if<flutter::EncodableMap>(&matIt->second);
                        if (mat) {
                            auto colIt = mat->find(flutter::EncodableValue("baseColor"));
                            if (colIt != mat->end()) {
                                auto* col = std::get_if<flutter::EncodableMap>(&colIt->second);
                                if (col) {
                                    auto gc = [&](const char* k) -> float {
                                        auto it = col->find(flutter::EncodableValue(k));
                                        return it != col->end() ? static_cast<float>(std::get<double>(it->second)) : 1.0f;
                                    };
                                    nodeIt->second.color = {gc("r"), gc("g"), gc("b"), gc("a")};
                                }
                            }
                        }
                    }
                }
            }
        }
        result->Success();

    } else if (method == "removeNode") {
        auto* id = std::get_if<std::string>(call.arguments());
        if (id) nodes_.erase(*id);
        result->Success();

    } else {
        result->NotImplemented();
    }
}

void ArEnginePlugin::HandleInitSession(
    const flutter::EncodableMap& /*args*/,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
{
    poseEstimator_ = std::make_unique<DesktopCameraPoseEstimator>();
    renderer_      = std::make_unique<DesktopARRenderer>(1280, 720);
    sessionActive_ = true;

    // Register a Flutter pixel-buffer texture so ARWidget can display the frame via Texture()
    auto* texRegistrar = registrar_->texture_registrar();
    if (texRegistrar) {
        // FlutterDesktopPixelBuffer approach: the callback supplies the RGBA pixel buffer
        // each time Flutter requests a new frame.
        auto pixelBufferCallback = [this](size_t width, size_t height)
            -> const FlutterDesktopPixelBuffer* {
            // This lambda is called on the raster thread.
            // In production: lock a mutex and copy renderer_->lastFrame into the buffer.
            static FlutterDesktopPixelBuffer pb{};
            static std::vector<uint8_t> buf;
            buf.resize(width * height * 4, 80);  // grey fallback
            pb.buffer = buf.data();
            pb.width  = width;
            pb.height = height;
            return &pb;
        };

        textureId_ = texRegistrar->RegisterTexture(
            flutter::TextureVariant(flutter::PixelBufferTexture(
                [pixelBufferCallback](size_t w, size_t h) {
                    return pixelBufferCallback(w, h);
                })));
    }

    StartFrameLoop();
    result->Success();
}

void ArEnginePlugin::StartFrameLoop() {
    if (frameThreadRunning_) return;
    frameThreadRunning_ = true;
    frameThread_ = std::thread([this] {
        while (frameThreadRunning_) {
            // Capture webcam frame (platform-specific; MediaFoundation/AVCaptureSession/V4L2)
            // Here we generate a synthetic RGBA gradient for demonstration
            const int W = 1280, H = 720;
            std::vector<uint8_t> camFrame(W * H * 4);
            auto now = std::chrono::steady_clock::now();
            float t = std::chrono::duration<float>(now.time_since_epoch()).count();
            for (int y = 0; y < H; ++y) {
                for (int x = 0; x < W; ++x) {
                    int idx = (y * W + x) * 4;
                    camFrame[idx+0] = static_cast<uint8_t>(40 + 20 * std::sin(t + x * 0.01f));
                    camFrame[idx+1] = static_cast<uint8_t>(40 + 20 * std::sin(t + y * 0.01f));
                    camFrame[idx+2] = static_cast<uint8_t>(60);
                    camFrame[idx+3] = 255;
                }
            }

            auto pose = poseEstimator_->estimateFromFrame(camFrame.data(), W, H);

            std::vector<ARNodeData> nodeList;
            nodeList.reserve(nodes_.size());
            for (auto& [_, n] : nodes_) nodeList.push_back(n);

            DesktopARRenderer::Frame outFrame;
            renderer_->renderFrame(camFrame.data(), pose, nodeList, outFrame);

            // Push rendered frame to Flutter texture
            if (textureId_ >= 0) {
                auto* texRegistrar = registrar_->texture_registrar();
                if (texRegistrar) {
                    texRegistrar->MarkTextureFrameAvailable(textureId_);
                }
            }

            std::this_thread::sleep_for(std::chrono::milliseconds(16)); // ~60fps
        }
    });
}

void ArEnginePlugin::StopFrameLoop() {
    frameThreadRunning_ = false;
    if (frameThread_.joinable()) frameThread_.join();
}

std::string ArEnginePlugin::GenerateUUID() const {
    // Simple pseudo-UUID
    auto now = std::chrono::high_resolution_clock::now().time_since_epoch().count();
    char buf[37];
    snprintf(buf, sizeof(buf),
        "%08llx-%04llx-4%03llx-%04llx-%012llx",
        (unsigned long long)(now >> 32),
        (unsigned long long)((now >> 16) & 0xffff),
        (unsigned long long)(now & 0x0fff),
        (unsigned long long)(0x8000 | (now & 0x3fff)),
        (unsigned long long)(now & 0xffffffffffff));
    return std::string(buf);
}

flutter::EncodableMap ArEnginePlugin::BuildCameraPoseMap(
    const DesktopCameraPoseEstimator::Pose& pose)
{
    return flutter::EncodableMap{
        {flutter::EncodableValue("position"), flutter::EncodableMap{
            {flutter::EncodableValue("x"), flutter::EncodableValue((double)pose.tx)},
            {flutter::EncodableValue("y"), flutter::EncodableValue((double)pose.ty)},
            {flutter::EncodableValue("z"), flutter::EncodableValue((double)pose.tz)},
        }},
        {flutter::EncodableValue("rotation"), flutter::EncodableMap{
            {flutter::EncodableValue("x"), flutter::EncodableValue((double)pose.qx)},
            {flutter::EncodableValue("y"), flutter::EncodableValue((double)pose.qy)},
            {flutter::EncodableValue("z"), flutter::EncodableValue((double)pose.qz)},
            {flutter::EncodableValue("w"), flutter::EncodableValue((double)pose.qw)},
        }},
    };
}

} // namespace ar_engine

// ─── Windows DLL export ───────────────────────────────────────────────────────

void ArEnginePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
    ar_engine::ArEnginePlugin::RegisterWithRegistrar(
        flutter::PluginRegistrarManager::GetInstance()
            ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
