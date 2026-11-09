import Flutter
import UIKit
import ARKit
import MetalKit

/// Full Metal-backed AR platform view.
/// Replaces the ARSCNView placeholder with a proper MTKView + ARSession.
class ARMetalPlatformView: NSObject, FlutterPlatformView, MTKViewDelegate, ARSessionDelegate {

    private let mtkView:    MTKView
    private var arSession:  ARSession
    private let renderer:   MetalARRenderer?
    private let fallbackConfig: [String: Any]
    private let assetKeyResolver: ((String) -> String)?
    private weak var sharedKitSession: ARKitSession?
    private var ownsStandaloneSession: Bool
    private var isUsingSharedSession: Bool

    // Scene data updated from the plugin
    var nodes: [[String: Any]] = []

    // Shared hit-test frame
    private(set) var currentFrame: ARFrame?

    init(frame: CGRect, device: MTLDevice?, config: [String: Any],
         assetKeyResolver: ((String) -> String)? = nil,
         sharedSession: ARKitSession? = nil) {
        fallbackConfig = config
        self.assetKeyResolver = assetKeyResolver
        sharedKitSession = sharedSession
        ownsStandaloneSession = sharedSession == nil
        isUsingSharedSession = sharedSession != nil
        arSession = sharedSession?.arSession ?? ARSession()
        mtkView   = MTKView(frame: frame, device: device ?? MTLCreateSystemDefaultDevice())
        renderer  = device.flatMap { MetalARRenderer(device: $0) }
            ?? MTLCreateSystemDefaultDevice().flatMap { MetalARRenderer(device: $0) }

        super.init()

        mtkView.delegate              = self
        mtkView.colorPixelFormat      = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.framebufferOnly       = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.backgroundColor       = .clear

        if ownsStandaloneSession {
            arSession.delegate = self
            startARSession(config: config)
        } else {
            currentFrame = sharedSession?.latestFrame
        }
    }

    deinit {
        stopStandaloneSessionIfOwned()
        mtkView.delegate = nil
    }

    func view() -> UIView { mtkView }

    func attachSharedSession(_ sharedSession: ARKitSession) {
        if isUsingSharedSession, let current = sharedKitSession, current === sharedSession {
            return
        }

        stopStandaloneSessionIfOwned()

        sharedKitSession = sharedSession
        arSession = sharedSession.arSession
        isUsingSharedSession = true
        currentFrame = sharedSession.latestFrame
    }

    func detachSharedSession() {
        guard isUsingSharedSession else { return }
        sharedKitSession = nil
        isUsingSharedSession = false
        ownsStandaloneSession = false
        currentFrame = nil
        arSession = ARSession()
    }

    private func stopStandaloneSessionIfOwned() {
        guard ownsStandaloneSession else { return }
        arSession.pause()
        arSession.delegate = nil
        ownsStandaloneSession = false
    }

    // ── ARSession setup ───────────────────────────────────────────────────────

    private func startARSession(config: [String: Any]) {
        guard ownsStandaloneSession else { return }
        guard ARWorldTrackingConfiguration.isSupported else { return }
        guard let cfg = try? ARKitSession.buildConfig(
            from: config,
            assetKeyResolver: assetKeyResolver
        ) else { return }
        arSession.run(cfg, options: [.resetTracking, .removeExistingAnchors])
    }

    func pause() {
        guard ownsStandaloneSession else { return }
        arSession.pause()
    }

    func resume() {
        guard ownsStandaloneSession else { return }
        guard ARWorldTrackingConfiguration.isSupported else { return }
        startARSession(config: fallbackConfig)
    }

    // ── ARSessionDelegate ─────────────────────────────────────────────────────

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard ownsStandaloneSession else { return }
        currentFrame = frame
    }

    // ── MTKViewDelegate ───────────────────────────────────────────────────────

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard
            let frame     = renderFrame,
            let renderer  = renderer,
            let drawable  = view.currentDrawable,
            let rpDesc    = view.currentRenderPassDescriptor
        else { return }

        rpDesc.colorAttachments[0].clearColor  = MTLClearColorMake(0, 0, 0, 1)
        rpDesc.colorAttachments[0].loadAction  = .clear
        rpDesc.colorAttachments[0].storeAction = .store

        // Draw camera background using ARKit's captured image
        drawCameraBackground(frame: frame, drawable: drawable, descriptor: rpDesc)
    }

    private var renderFrame: ARFrame? {
        sharedKitSession?.latestFrame ?? currentFrame ?? arSession.currentFrame
    }

    private var renderNodes: [[String: Any]] {
        guard let shared = sharedKitSession else { return nodes }
        return Array(shared.nodes.values)
    }

    private var commandQueue: MTLCommandQueue? {
        guard let d = mtkView.device else { return nil }
        return d.makeCommandQueue()
    }

    private var _cmdQueue: MTLCommandQueue?

    private func drawCameraBackground(frame: ARFrame, drawable: CAMetalDrawable,
                                       descriptor: MTLRenderPassDescriptor) {
        if _cmdQueue == nil, let d = mtkView.device {
            _cmdQueue = d.makeCommandQueue()
        }
        guard let queue = _cmdQueue,
              let cmdBuf  = queue.makeCommandBuffer(),
              let encoder = cmdBuf.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        // Draw all scene content through MetalARRenderer
        renderer?.draw(frame: frame, nodes: renderNodes, renderEncoder: encoder)

        encoder.endEncoding()
        cmdBuf.present(drawable)
        cmdBuf.commit()
    }

    /// Perform a raycast hit-test from normalised screen coordinates.
    func hitTest(normX: Float, normY: Float) -> [[String: Any]] {
        guard let frame = renderFrame else { return [] }
        let point = CGPoint(x: CGFloat(normX), y: CGFloat(normY))
        let query = frame.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .any)
        return arSession.raycast(query).map { r in [
            "type":      r.anchor is ARPlaneAnchor ? "plane" : "estimatedHorizontalPlane",
            "worldPose": poseFromTransform(r.worldTransform),
            "distance":  Double(simd_length(r.worldTransform.columns.3.xyz)),
            "planeId":   (r.anchor as? ARPlaneAnchor)?.identifier.uuidString ?? "",
            "anchorId":  "",
        ]}
    }

    private func poseFromTransform(_ t: simd_float4x4) -> [String: Any] {
        let q = simd_quatf(t)
        return [
            "position": ["x": Double(t.columns.3.x),
                         "y": Double(t.columns.3.y),
                         "z": Double(t.columns.3.z)],
            "rotation": ["x": Double(q.imag.x), "y": Double(q.imag.y),
                         "z": Double(q.imag.z), "w": Double(q.real)],
        ]
    }
}
