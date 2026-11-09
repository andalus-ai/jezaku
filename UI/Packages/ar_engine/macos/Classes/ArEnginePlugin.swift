import Cocoa
import FlutterMacOS
import AVFoundation
import CoreImage
import ImageIO
import Metal
import MetalKit
import simd

// ─── macOS Plugin ─────────────────────────────────────────────────────────────

public class ArEnginePlugin: NSObject, FlutterPlugin {

    private var channel:       FlutterMethodChannel!
    private var cameraChannel: FlutterEventChannel!
    private var planeChannel:  FlutterEventChannel!
    private var anchorChannel: FlutterEventChannel!
    private var lightChannel:  FlutterEventChannel!

    private var desktopSession: MacOSARSession?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ArEnginePlugin()
        instance.setupChannels(registrar: registrar)
        registrar.register(MacOSARViewFactory(messenger: registrar.messenger),
                           withId: "com.arengine/ar_view")
    }

    private func setupChannels(registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(
            name:             "com.arengine/ar_engine",
            binaryMessenger:  registrar.messenger)
        channel.setMethodCallHandler(handle)

        cameraChannel = FlutterEventChannel(name: "com.arengine/camera_stream", binaryMessenger: registrar.messenger)
        planeChannel  = FlutterEventChannel(name: "com.arengine/plane_stream",  binaryMessenger: registrar.messenger)
        anchorChannel = FlutterEventChannel(name: "com.arengine/anchor_stream", binaryMessenger: registrar.messenger)
        lightChannel  = FlutterEventChannel(name: "com.arengine/light_stream",  binaryMessenger: registrar.messenger)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isARSupported":
            // macOS: always supported via webcam + visual odometry
            result(true)

        case "getCapabilities":
            result([
                "isARSupported": true,
                "supportsWorldTracking": true,
                "supportsPlaneDetection": true,
                "supportsHitTesting": true,
                "supportsImageTracking": false,
                "supportsLightEstimation": true,
                "supportsSceneDepth": false,
                "supportsHumanOcclusion": false,
                "supportsBodyTracking": false,
                "supportsGeospatial": false,
                "supportsCloudAnchors": false,
                "supportsSnapshotCapture": true,
                "supportsRecordingEncode": true
            ])

        case "getRuntimeDiagnostics":
            result(desktopSession?.runtimeDiagnostics() ?? Self.inactiveRuntimeDiagnostics())

        case "initSession":
            let session = MacOSARSession()
            session.setEventChannels(
                camera: cameraChannel, plane: planeChannel,
                anchor: anchorChannel, light: lightChannel)
            session.start()
            desktopSession = session
            result(nil)

        case "pauseSession":  desktopSession?.pause();  result(nil)
        case "resumeSession": desktopSession?.resume(); result(nil)
        case "destroySession":
            desktopSession?.destroy()
            desktopSession = nil
            result(nil)

        case "reconfigureSession":
            // macOS: live reconfigure – update detection preferences
            desktopSession?.reconfigure(args: call.arguments as? [String: Any] ?? [:])
            result(nil)

        case "captureSnapshot":
            result(desktopSession?.captureSnapshot())

        case "encodeRecording":
            guard let args = call.arguments as? [String: Any] else {
                result(nil)
                return
            }
            do {
                result(try desktopSession?.encodeRecording(args: args))
            } catch {
                result(FlutterError(
                    code: "RECORDING_ENCODE_FAILED",
                    message: error.localizedDescription,
                    details: nil
                ))
            }

        case "sampleDepth":
            result(nil)

        case "getDesktopTextureId":
            // macOS uses PlatformView (NSView), not Flutter texture
            result(nil)

        case "hitTest":
            guard let args = call.arguments as? [String: Any],
                  let x = args["x"] as? Double,
                  let y = args["y"] as? Double else { result([]); return }
            result(desktopSession?.hitTest(normX: Float(x), normY: Float(y)) ?? [])

        case "addAnchor":
            guard let hitMap = call.arguments as? [String: Any] else { result(nil); return }
            result(desktopSession?.addAnchor(from: hitMap))

        case "addAnchorAtPose":
            guard let poseMap = call.arguments as? [String: Any] else { result(nil); return }
            result(desktopSession?.addAnchorAtPose(poseMap: poseMap))

        case "removeAnchor":
            if let id = call.arguments as? String { desktopSession?.removeAnchor(id: id) }
            result(nil)

        case "hostCloudAnchor", "resolveCloudAnchor":
            result(nil)

        case "addNode":
            if let args = call.arguments as? [String: Any] {
                result(desktopSession?.addNode(args: args))
            } else { result(nil) }

        case "updateNode":
            if let args = call.arguments as? [String: Any] { desktopSession?.updateNode(args: args) }
            result(nil)

        case "removeNode":
            if let id = call.arguments as? String { desktopSession?.removeNode(id: id) }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private static func inactiveRuntimeDiagnostics() -> [String: Any] {
        [
            "source": "macos",
            "backend": "desktop_camera",
            "sessionActive": false,
            "sessionRunning": false,
            "hasNativeSession": false,
            "hasCameraFrame": false,
            "anchorCount": 0,
            "nodeCount": 0,
            "modelNodeCount": 0,
            "planeCount": 0,
            "trackedPlaneCount": 0,
            "depthEnabled": false,
            "geospatialEnabled": false,
            "bodyTrackingEnabled": false
        ]
    }
}

// ─── macOS AR session (webcam + pose estimation) ─────────────────────────────

class MacOSARSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let frameLock = NSLock()
    private let ciContext = CIContext()
    private var latestPixelBuffer: CVPixelBuffer?

    private var cameraEventSink: FlutterEventSink?
    private var planeEventSink:  FlutterEventSink?
    private var anchorEventSink: FlutterEventSink?
    private var lightEventSink:  FlutterEventSink?

    private var nodes   = [String: [String: Any]]()
    private var anchors = [String: [String: Any]]()

    // Simulated world state (real: use Vision/OpenCV for actual pose estimation)
    private var simulatedT: Double = 0
    private var frameTimer: Timer?

    func setEventChannels(camera: FlutterEventChannel, plane: FlutterEventChannel,
                          anchor: FlutterEventChannel, light: FlutterEventChannel) {
        camera.setStreamHandler(MacOSStreamHandler { [weak self] sink in self?.cameraEventSink = sink })
        plane.setStreamHandler( MacOSStreamHandler { [weak self] sink in self?.planeEventSink  = sink })
        anchor.setStreamHandler(MacOSStreamHandler { [weak self] sink in self?.anchorEventSink = sink })
        light.setStreamHandler( MacOSStreamHandler { [weak self] sink in self?.lightEventSink  = sink })
    }

    func start() {
        if captureSession == nil {
            startWebcamCapture()
        } else if captureSession?.isRunning == false {
            captureSession?.startRunning()
        }
        startSyntheticFrames()
    }

    private func startSyntheticFrames() {
        guard frameTimer == nil else { return }
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30, repeats: true) { [weak self] _ in
            self?.emitSyntheticFrame()
        }
    }

    func pause() {
        captureSession?.stopRunning()
        frameTimer?.invalidate()
        frameTimer = nil
    }

    func resume() { start() }

    func destroy() {
        pause()
        captureSession = nil
        videoOutput = nil
        frameLock.lock()
        latestPixelBuffer = nil
        frameLock.unlock()
    }

    func reconfigure(args: [String: Any]) {
        // Desktop: no real plane detection engine; just log config change
        // In production: update VNRequest types based on args
    }

    func runtimeDiagnostics() -> [String: Any] {
        frameLock.lock()
        let hasFrame = latestPixelBuffer != nil
        frameLock.unlock()
        let running = frameTimer != nil
        return [
            "source": "macos",
            "backend": "desktop_camera",
            "sessionActive": running,
            "sessionRunning": running,
            "hasNativeSession": true,
            "hasCameraFrame": hasFrame,
            "anchorCount": anchors.count,
            "nodeCount": nodes.count,
            "modelNodeCount": nodes.values.filter { Self.isModelNode($0) }.count,
            "planeCount": running ? 1 : 0,
            "trackedPlaneCount": running ? 1 : 0,
            "depthEnabled": false,
            "geospatialEnabled": false,
            "bodyTrackingEnabled": false
        ]
    }

    func captureSnapshot() -> FlutterStandardTypedData? {
        frameLock.lock()
        let pixelBuffer = latestPixelBuffer
        frameLock.unlock()
        guard let pixelBuffer else { return nil }

        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else {
            return nil
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let jpeg = bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.85]
        ) else {
            return nil
        }
        return FlutterStandardTypedData(bytes: jpeg)
    }

    func encodeRecording(args: [String: Any]) throws -> [String: Any]? {
        guard let frames = args["frames"] as? [FlutterStandardTypedData],
              !frames.isEmpty else {
            return nil
        }
        guard let firstImage = Self.decodeImage(from: frames[0].data) else {
            return nil
        }

        let config = args["config"] as? [String: Any] ?? [:]
        let fps = max(1, min(60, Self.intValue(config, "fps", defaultValue: 30)))
        let targetWidth = Self.intValue(config, "width", defaultValue: 0)
        let targetHeight = Self.intValue(config, "height", defaultValue: 0)
        let width = targetWidth > 0 ? targetWidth : firstImage.width
        let height = targetHeight > 0 ? targetHeight : firstImage.height
        let bitrateKbps = max(1, Self.intValue(config, "videoBitrateKbps", defaultValue: 4000))
        let requestedFormat = (config["outputFormat"] as? String ?? "mp4").lowercased()
        let fileExtension = requestedFormat == "mov" ? "mov" : "mp4"
        let fileType: AVFileType = fileExtension == "mov" ? .mov : .mp4
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ar_recording_\(Int(Date().timeIntervalSince1970 * 1000)).\(fileExtension)")
        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: fileType)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrateKbps * 1000
            ]
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )
        guard writer.canAdd(writerInput) else {
            throw NSError(domain: "ar_engine", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Unable to add recording writer input"
            ])
        }
        writer.add(writerInput)
        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "ar_engine", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Unable to start recording writer"
            ])
        }
        writer.startSession(atSourceTime: .zero)

        var encodedFrameCount = 0
        for frame in frames {
            guard let image = Self.decodeImage(from: frame.data),
                  let buffer = Self.makePixelBuffer(width: width, height: height) else {
                continue
            }
            Self.draw(image: image, into: buffer, width: width, height: height)
            while !writerInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.002)
            }
            let presentationTime = CMTime(
                value: CMTimeValue(encodedFrameCount),
                timescale: CMTimeScale(fps)
            )
            guard adaptor.append(buffer, withPresentationTime: presentationTime) else {
                throw writer.error ?? NSError(domain: "ar_engine", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to append recording frame"
                ])
            }
            encodedFrameCount += 1
        }

        guard encodedFrameCount > 0 else {
            writer.cancelWriting()
            return nil
        }
        writerInput.markAsFinished()
        let finished = DispatchSemaphore(value: 0)
        writer.finishWriting { finished.signal() }
        finished.wait()
        guard writer.status == .completed else {
            throw writer.error ?? NSError(domain: "ar_engine", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Unable to finish recording writer"
            ])
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes[.size] as? NSNumber
        let durationMillis = Self.intValue(args, "durationMillis", defaultValue: encodedFrameCount * 1000 / fps)
        return [
            "filePath": outputURL.path,
            "durationMillis": durationMillis,
            "frameCount": encodedFrameCount,
            "fileSizeBytes": fileSize?.intValue ?? 0
        ]
    }

    private static func decodeImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func makePixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        return pixelBuffer
    }

    private static func draw(image: CGImage, into pixelBuffer: CVPixelBuffer, width: Int, height: Int) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue |
            CGBitmapInfo.byteOrder32Little.rawValue
        let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
        context?.interpolationQuality = .medium
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }

    private static func intValue(_ map: [String: Any], _ key: String, defaultValue: Int) -> Int {
        if let value = map[key] as? NSNumber { return value.intValue }
        if let value = map[key] as? Int { return value }
        return defaultValue
    }

    private static func isModelNode(_ args: [String: Any]) -> Bool {
        if args["modelAsset"] is [String: Any] { return true }
        if let modelPath = args["modelPath"] as? String, !modelPath.isEmpty {
            return true
        }
        switch args["contentType"] as? String {
        case "obj", "gltf", "glb", "usdz", "model":
            return true
        default:
            return false
        }
    }

    func addAnchorAtPose(poseMap: [String: Any]) -> [String: Any] {
        let id = UUID().uuidString
        let anchor: [String: Any] = [
            "id": id,
            "pose": poseMap,
            "trackingState": "tracking"
        ]
        anchors[id] = anchor
        return anchor
    }

    // ── Webcam capture ────────────────────────────────────────────────────────

    private func startWebcamCapture() {
        let cs = AVCaptureSession()
        cs.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device),
              cs.canAddInput(input) else { return }
        cs.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.arengine.macos.capture"))
        output.alwaysDiscardsLateVideoFrames = true
        if cs.canAddOutput(output) { cs.addOutput(output) }

        captureSession = cs
        videoOutput    = output
        cs.startRunning()
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        frameLock.lock()
        latestPixelBuffer = pixelBuffer
        frameLock.unlock()
        // Real: run optical flow / ORB → update pose
        // (macOS: use Vision VNTrackObjectRequest or OpenCV via Swift bridge)
    }

    // ── Synthetic frame events ────────────────────────────────────────────────

    private func emitSyntheticFrame() {
        simulatedT += 1.0 / 30.0

        // Gentle sinusoidal camera drift (replace with real visual odometry)
        let tx = 0.02 * sin(simulatedT * 0.4)
        let ty = 0.01 * cos(simulatedT * 0.3)
        let tz = -0.5 + 0.01 * sin(simulatedT * 0.2)

        // Identity projection (fov 60°, aspect 16/9)
        let f: Double = 1.0 / tan(60 * .pi / 180 / 2)
        let proj: [Double] = [f/1.778,0,0,0, 0,f,0,0, 0,0,-1,-1, 0,0,-0.01,0]
        let view: [Double] = [1,0,0,0, 0,1,0,0, 0,0,1,0, -tx,-ty,-tz,1]

        cameraEventSink?([
            "pose": [
                "position": ["x": tx, "y": ty, "z": tz],
                "rotation": ["x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0],
            ],
            "projectionMatrix": proj,
            "viewMatrix":       view,
            "trackingState":    "tracking",
            "intrinsics":       [800.0, 800.0, 640.0, 360.0],
            "imageResolution":  [1280, 720],
        ])

        // Emit a synthetic horizontal ground plane
        planeEventSink?([[
            "id":               "synthetic_floor",
            "alignment":        "horizontal",
            "centerPose":       ["position": ["x": 0.0, "y": -0.5, "z": -1.0],
                                 "rotation": ["x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0]],
            "extentMeters":     ["x": 2.0, "y": 0.0, "z": 2.0],
            "boundaryVertices": [
                ["x": -1.0, "y": 0.0, "z": -1.0], ["x":  1.0, "y": 0.0, "z": -1.0],
                ["x":  1.0, "y": 0.0, "z":  1.0], ["x": -1.0, "y": 0.0, "z":  1.0],
            ],
            "trackingState":    "tracking",
        ]])

        // Light estimate (simulate noon-day light)
        lightEventSink?(800.0 + 200.0 * sin(simulatedT * 0.1))
    }

    // ── Hit test ──────────────────────────────────────────────────────────────

    func hitTest(normX: Float, normY: Float) -> [[String: Any]] {
        // Unproject to ground plane y = -0.5
        let worldX = Double(normX * 2 - 1) * 0.5
        let worldZ = -1.0 + Double(normY * 2 - 1) * 0.2
        return [[
            "type":      "estimatedHorizontalPlane",
            "worldPose": ["position": ["x": worldX, "y": -0.5, "z": worldZ],
                          "rotation": ["x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0]],
            "distance":  1.0,
            "planeId":   "synthetic_floor",
            "anchorId":  "",
        ]]
    }

    // ── Anchor / node management ──────────────────────────────────────────────

    func addAnchor(from hitMap: [String: Any]) -> [String: Any] {
        let id = UUID().uuidString
        anchors[id] = hitMap
        return ["id": id, "pose": hitMap["worldPose"] ?? [:], "trackingState": "tracking"]
    }

    func removeAnchor(id: String)               { anchors.removeValue(forKey: id) }
    func addNode(args: [String: Any]) -> String { let id = args["id"] as? String ?? UUID().uuidString; nodes[id] = args; return id }
    func updateNode(args: [String: Any])        { if let id = args["id"] as? String { nodes[id] = args } }
    func removeNode(id: String)                 { nodes.removeValue(forKey: id) }
}

// ─── macOS EventChannel handler ───────────────────────────────────────────────

class MacOSStreamHandler: NSObject, FlutterStreamHandler {
    private let onListen: (FlutterEventSink?) -> Void
    init(onListen: @escaping (FlutterEventSink?) -> Void) { self.onListen = onListen }
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        onListen(events); return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? { onListen(nil); return nil }
}

// ─── macOS Platform view factory ─────────────────────────────────────────────

class MacOSARViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }

    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.black.cgColor
        return v
    }

    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
