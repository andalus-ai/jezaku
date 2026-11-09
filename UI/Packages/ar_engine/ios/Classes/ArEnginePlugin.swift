import Flutter
import UIKit
import ARKit
import AVFoundation
import SceneKit
import Metal
import MetalKit
import VideoToolbox
import ImageIO
import CoreLocation

// ─── Plugin entry point ───────────────────────────────────────────────────────

@objc public class ArEnginePlugin: NSObject, FlutterPlugin {

    private var channel:       FlutterMethodChannel!
    private var cameraChannel: FlutterEventChannel!
    private var planeChannel:  FlutterEventChannel!
    private var anchorChannel: FlutterEventChannel!
    private var lightChannel:  FlutterEventChannel!

    private var arSession: ARKitSession?
    private var assetKeyResolver: ((String) -> String)?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ArEnginePlugin()
        let assetKeyResolver: (String) -> String = { assetPath in
            registrar.lookupKey(forAsset: assetPath)
        }
        instance.setupChannels(registrar: registrar, assetKeyResolver: assetKeyResolver)
        // Use ARMetalViewFactory (MTKView + real Metal renderer) instead of the old ARSCNView stub
        registrar.register(
            ARMetalViewFactory(
                messenger: registrar.messenger(),
                assetKeyResolver: assetKeyResolver
            ),
            withId: "com.arengine/ar_view"
        )
    }

    private func setupChannels(registrar: FlutterPluginRegistrar,
                               assetKeyResolver: @escaping (String) -> String) {
        self.assetKeyResolver = assetKeyResolver
        channel = FlutterMethodChannel(name: "com.arengine/ar_engine",
                                       binaryMessenger: registrar.messenger())
        channel.setMethodCallHandler(handle)
        cameraChannel = FlutterEventChannel(name: "com.arengine/camera_stream", binaryMessenger: registrar.messenger())
        planeChannel  = FlutterEventChannel(name: "com.arengine/plane_stream",  binaryMessenger: registrar.messenger())
        anchorChannel = FlutterEventChannel(name: "com.arengine/anchor_stream", binaryMessenger: registrar.messenger())
        lightChannel  = FlutterEventChannel(name: "com.arengine/light_stream",  binaryMessenger: registrar.messenger())
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        // ── Session lifecycle ────────────────────────────────────────────────

        case "isARSupported":
            result(ARWorldTrackingConfiguration.isSupported)

        case "getCapabilities":
            result(Self.capabilitiesMap())

        case "getRuntimeDiagnostics":
            result(arSession?.runtimeDiagnostics() ?? Self.inactiveRuntimeDiagnostics())

        case "initSession":
            let args = call.arguments as? [String: Any] ?? [:]
            do {
                let s = try ARKitSession(config: args,
                    cameraChannel: cameraChannel, planeChannel: planeChannel,
                    anchorChannel: anchorChannel, lightChannel: lightChannel,
                    assetKeyResolver: assetKeyResolver)
                s.start()
                arSession = s
                ARMetalViewFactory.activeSession = s
                result(nil)
            } catch {
                result(FlutterError(code: "INIT_FAILED", message: error.localizedDescription, details: nil))
            }

        case "reconfigureSession":
            guard let args = call.arguments as? [String: Any] else { result(nil); return }
            do {
                try arSession?.reconfigure(args: args)
                result(nil)
            } catch {
                result(FlutterError(code: "RECONFIGURE_FAILED", message: error.localizedDescription, details: nil))
            }

        case "pauseSession":
            arSession?.pause(); result(nil)

        case "resumeSession":
            arSession?.resume(); result(nil)

        case "destroySession":
            arSession?.destroy()
            arSession = nil
            ARMetalViewFactory.activeSession = nil
            result(nil)

        // ── Snapshot ─────────────────────────────────────────────────────────

        case "captureSnapshot":
            if let jpeg = arSession?.captureSnapshot() {
                result(FlutterStandardTypedData(bytes: jpeg))
            } else {
                result(nil)
            }

        case "encodeRecording":
            guard let args = call.arguments as? [String: Any] else {
                result(nil)
                return
            }
            do {
                result(try arSession?.encodeRecording(args: args))
            } catch {
                result(FlutterError(
                    code: "RECORDING_ENCODE_FAILED",
                    message: error.localizedDescription,
                    details: nil
                ))
            }

        case "sampleDepth":
            guard let args = call.arguments as? [String: Any],
                  let x = args["x"] as? Double,
                  let y = args["y"] as? Double else {
                result(nil)
                return
            }
            result(arSession?.sampleDepth(normX: Float(x), normY: Float(y)))

        // ── Hit testing ───────────────────────────────────────────────────────

        case "hitTest":
            guard let args = call.arguments as? [String: Any],
                  let x = args["x"] as? Double, let y = args["y"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "x and y required", details: nil))
                return
            }
            result(arSession?.hitTest(normX: Float(x), normY: Float(y)) ?? [])

        // ── Anchors ───────────────────────────────────────────────────────────

        case "addAnchor":
            guard let hitMap = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil)); return
            }
            do {
                result(try arSession?.addAnchor(from: hitMap))
            } catch {
                result(FlutterError(code: "ANCHOR_FAILED", message: error.localizedDescription, details: nil))
            }

        case "addAnchorAtPose":
            guard let poseMap = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil)); return
            }
            do {
                result(try arSession?.addAnchorAtPose(poseMap: poseMap))
            } catch {
                result(FlutterError(code: "ANCHOR_FAILED", message: error.localizedDescription, details: nil))
            }

        case "addGeospatialAnchor":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil)); return
            }
            do {
                result(try arSession?.addGeospatialAnchor(args: args))
            } catch {
                let nsError = error as NSError
                let code = nsError.code == 4 ? "UNSUPPORTED_GEOSPATIAL" : "GEOSPATIAL_ANCHOR_FAILED"
                result(FlutterError(code: code, message: error.localizedDescription, details: nil))
            }

        case "removeAnchor":
            if let id = call.arguments as? String { arSession?.removeAnchor(id: id) }
            result(nil)

        case "hostCloudAnchor", "resolveCloudAnchor":
            result(nil)

        // ── Nodes ─────────────────────────────────────────────────────────────

        case "addNode":
            if let args = call.arguments as? [String: Any] {
                result(arSession?.addNode(args: args) ?? UUID().uuidString)
            } else { result(nil) }

        case "updateNode":
            if let args = call.arguments as? [String: Any] { arSession?.updateNode(args: args) }
            result(nil)

        case "removeNode":
            if let id = call.arguments as? String { arSession?.removeNode(id: id) }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // Workaround: Swift doesn't have implicit self capture in nested closures
    private var session: ARKitSession? { arSession }

    private static func capabilitiesMap() -> [String: Any] {
        let worldTracking = ARWorldTrackingConfiguration.isSupported
        let sceneDepth =
            worldTracking &&
            (ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) ||
             ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth))
        let humanOcclusion =
            worldTracking &&
            (ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) ||
             ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation))
        let geospatial: Bool
        if #available(iOS 14.0, *) {
            geospatial = ARGeoTrackingConfiguration.isSupported
        } else {
            geospatial = false
        }

        return [
            "isARSupported": worldTracking,
            "supportsWorldTracking": worldTracking,
            "supportsPlaneDetection": worldTracking,
            "supportsHitTesting": worldTracking,
            "supportsImageTracking": worldTracking,
            "supportsLightEstimation": worldTracking,
            "supportsSceneDepth": sceneDepth,
            "supportsHumanOcclusion": humanOcclusion,
            "supportsBodyTracking": ARBodyTrackingConfiguration.isSupported,
            "supportsGeospatial": geospatial,
            "supportsCloudAnchors": false,
            "supportsSnapshotCapture": worldTracking,
            "supportsRecordingEncode": worldTracking
        ]
    }

    private static func inactiveRuntimeDiagnostics() -> [String: Any] {
        [
            "source": "ios",
            "backend": "arkit",
            "sessionActive": false,
            "sessionRunning": false,
            "hasNativeSession": false,
            "hasCameraFrame": false,
            "anchorCount": 0,
            "nodeCount": 0,
            "modelNodeCount": 0,
            "planeCount": 0,
            "imageAnchorCount": 0,
            "trackedImageAnchorCount": 0,
            "depthEnabled": false,
            "geospatialEnabled": false,
            "bodyTrackingEnabled": false
        ]
    }
}

// ─── ARKit session wrapper ────────────────────────────────────────────────────

class ARKitSession: NSObject, ARSessionDelegate {

    internal let arSession = ARSession()
    internal var configuration: ARConfiguration

    // Event sinks
    private var cameraEventSink: FlutterEventSink?
    private var planeEventSink:  FlutterEventSink?
    private var anchorEventSink: FlutterEventSink?
    private var lightEventSink:  FlutterEventSink?

    // Node + anchor registries
    internal var anchors  = [String: ARAnchor]()
    private var anchorMetadata = [UUID: [String: Any]]()
    internal var nodes    = [String: [String: Any]]()
    internal var scnScene = SCNScene()

    private(set) var latestFrame: ARFrame?
    private(set) var isRunning = false
    private let assetKeyResolver: ((String) -> String)?

    // MARK: - Init

    init(config: [String: Any],
         cameraChannel: FlutterEventChannel,
         planeChannel:  FlutterEventChannel,
         anchorChannel: FlutterEventChannel,
         lightChannel:  FlutterEventChannel,
         assetKeyResolver: ((String) -> String)? = nil) throws {

        guard ARWorldTrackingConfiguration.isSupported else {
            throw NSError(domain: "AREngine", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "ARWorldTracking not supported on this device"])
        }
        self.assetKeyResolver = assetKeyResolver
        configuration = try ARKitSession.buildConfig(
            from: config,
            assetKeyResolver: assetKeyResolver
        )
        super.init()
        arSession.delegate = self

        cameraChannel.setStreamHandler(StreamHandler { [weak self] s in self?.cameraEventSink = s })
        planeChannel.setStreamHandler( StreamHandler { [weak self] s in self?.planeEventSink  = s })
        anchorChannel.setStreamHandler(StreamHandler { [weak self] s in self?.anchorEventSink = s })
        lightChannel.setStreamHandler( StreamHandler { [weak self] s in self?.lightEventSink  = s })
    }

    static func buildConfig(
        from args: [String: Any],
        assetKeyResolver: ((String) -> String)? = nil
    ) throws -> ARConfiguration {
        if boolArg(args, "bodyTrackingEnabled", false) {
            return try buildBodyTrackingConfig(from: args)
        }
        if boolArg(args, "geospatialEnabled", false) {
            if #available(iOS 14.0, *) {
                return try buildGeoTrackingConfig(from: args)
            }
            throw NSError(domain: "AREngine", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "AR geospatial tracking requires iOS 14 or newer"])
        }
        return buildWorldTrackingConfig(
            from: args,
            assetKeyResolver: assetKeyResolver
        )
    }

    private static func buildWorldTrackingConfig(
        from args: [String: Any],
        assetKeyResolver: ((String) -> String)?
    ) -> ARWorldTrackingConfiguration {
        let cfg = ARWorldTrackingConfiguration()
        let h = args["detectHorizontalPlanes"] as? Bool ?? true
        let v = args["detectVerticalPlanes"]   as? Bool ?? false
        cfg.planeDetection = h && v ? [.horizontal, .vertical] : h ? [.horizontal] : v ? [.vertical] : []
        cfg.environmentTexturing = (args["lightingEstimationEnabled"] as? Bool ?? true) ? .automatic : .none
        cfg.frameSemantics = supportedFrameSemantics(
            from: args,
            supports: ARWorldTrackingConfiguration.supportsFrameSemantics
        )
        applyImageTargets(from: args, to: cfg, assetKeyResolver: assetKeyResolver)
        applyTargetFrameRate(
            from: args,
            to: cfg,
            supportedVideoFormats: ARWorldTrackingConfiguration.supportedVideoFormats
        )
        return cfg
    }

    private static func buildBodyTrackingConfig(from args: [String: Any]) throws -> ARBodyTrackingConfiguration {
        guard ARBodyTrackingConfiguration.isSupported else {
            throw NSError(domain: "AREngine", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "AR body tracking is not supported on this device"])
        }
        let cfg = ARBodyTrackingConfiguration()
        cfg.frameSemantics = supportedFrameSemantics(
            from: args,
            supports: ARBodyTrackingConfiguration.supportsFrameSemantics
        )
        applyTargetFrameRate(
            from: args,
            to: cfg,
            supportedVideoFormats: ARBodyTrackingConfiguration.supportedVideoFormats
        )
        return cfg
    }

    @available(iOS 14.0, *)
    private static func buildGeoTrackingConfig(from args: [String: Any]) throws -> ARGeoTrackingConfiguration {
        guard ARGeoTrackingConfiguration.isSupported else {
            throw NSError(domain: "AREngine", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "AR geospatial tracking is not supported on this device"])
        }
        let cfg = ARGeoTrackingConfiguration()
        applyTargetFrameRate(
            from: args,
            to: cfg,
            supportedVideoFormats: ARGeoTrackingConfiguration.supportedVideoFormats
        )
        return cfg
    }

    private static func applyImageTargets(
        from args: [String: Any],
        to cfg: ARWorldTrackingConfiguration,
        assetKeyResolver: ((String) -> String)?
    ) {
        let detectionImages = buildDetectionImages(
            from: args,
            assetKeyResolver: assetKeyResolver
        )
        guard !detectionImages.isEmpty else { return }
        cfg.detectionImages = detectionImages
        cfg.maximumNumberOfTrackedImages = detectionImages.count
    }

    private static func buildDetectionImages(
        from args: [String: Any],
        assetKeyResolver: ((String) -> String)?
    ) -> Set<ARReferenceImage> {
        guard let imageTargets = args["imageTargets"] as? [[String: Any]],
              !imageTargets.isEmpty else { return [] }

        var detectionImages = Set<ARReferenceImage>()
        for target in imageTargets {
            guard let name = target["name"] as? String,
                  let assetPath = target["assetPath"] as? String,
                  let physicalWidthMeters = doubleArg(target, "physicalWidthMeters"),
                  physicalWidthMeters > 0 else { continue }
            let assetKey = assetKeyResolver?(assetPath) ?? assetPath
            guard let cgImage = UIImage(named: assetKey)?.cgImage else { continue }
            let referenceImage = ARReferenceImage(
                cgImage,
                orientation: CGImagePropertyOrientation.up,
                physicalWidth: CGFloat(physicalWidthMeters)
            )
            referenceImage.name = name
            detectionImages.insert(referenceImage)
        }
        return detectionImages
    }

    private static func applyTargetFrameRate(
        from args: [String: Any],
        to cfg: ARConfiguration,
        supportedVideoFormats: [ARConfiguration.VideoFormat]
    ) {
        guard let targetFrameRate = intArg(args, "targetFrameRate"),
              targetFrameRate > 0,
              let format = nearestVideoFormat(
                to: targetFrameRate,
                supportedVideoFormats: supportedVideoFormats
              ) else { return }
        cfg.videoFormat = format
    }

    private static func nearestVideoFormat(
        to targetFrameRate: Int,
        supportedVideoFormats: [ARConfiguration.VideoFormat]
    ) -> ARConfiguration.VideoFormat? {
        supportedVideoFormats.min { lhs, rhs in
            abs(lhs.framesPerSecond - targetFrameRate) <
                abs(rhs.framesPerSecond - targetFrameRate)
        }
    }

    private static func boolArg(_ args: [String: Any], _ key: String, _ defaultValue: Bool) -> Bool {
        if let value = args[key] as? Bool { return value }
        if let value = args[key] as? NSNumber { return value.boolValue }
        return defaultValue
    }

    private static func intArg(_ args: [String: Any], _ key: String) -> Int? {
        if let value = args[key] as? Int { return value }
        if let value = args[key] as? NSNumber { return value.intValue }
        return nil
    }

    private static func doubleArg(_ args: [String: Any], _ key: String) -> Double? {
        if let value = args[key] as? Double { return value }
        if let value = args[key] as? NSNumber { return value.doubleValue }
        return nil
    }

    private static func supportedFrameSemantics(
        from args: [String: Any],
        supports: (ARConfiguration.FrameSemantics) -> Bool
    ) -> ARConfiguration.FrameSemantics {
        var semantics: ARConfiguration.FrameSemantics = []
        let wantsDepth = args["depthEnabled"] as? Bool ?? false
        let wantsOcclusion = args["occlusionEnabled"] as? Bool ?? false

        if wantsDepth {
            if supports(.smoothedSceneDepth) {
                semantics.insert(.smoothedSceneDepth)
            } else if supports(.sceneDepth) {
                semantics.insert(.sceneDepth)
            }
        }

        if wantsOcclusion {
            if supports(.personSegmentationWithDepth) {
                semantics.insert(.personSegmentationWithDepth)
            } else if supports(.personSegmentation) {
                semantics.insert(.personSegmentation)
            }
        }

        return semantics
    }

    func start() {
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
    }

    func pause() {
        arSession.pause()
        isRunning = false
    }

    func resume() {
        arSession.run(configuration)
        isRunning = true
    }

    func destroy() {
        arSession.pause()
        isRunning = false
        anchors.removeAll(); anchorMetadata.removeAll(); nodes.removeAll()
    }

    // MARK: - Reconfigure (live, no teardown)

    func reconfigure(args: [String: Any]) throws {
        configuration = try ARKitSession.buildConfig(
            from: args,
            assetKeyResolver: assetKeyResolver
        )
        arSession.run(configuration, options: [])
        isRunning = true
    }

    func runtimeDiagnostics() -> [String: Any] {
        let frameAnchors = latestFrame?.anchors ?? []
        let planeCount = frameAnchors.compactMap { $0 as? ARPlaneAnchor }.count
        let imageAnchors = frameAnchors.compactMap { $0 as? ARImageAnchor }
        let trackedImageAnchorCount = imageAnchors.filter { $0.isTracked }.count
        let frameSemantics = configuration.frameSemantics
        let depthEnabled =
            frameSemantics.contains(.sceneDepth) ||
            frameSemantics.contains(.smoothedSceneDepth)
        return [
            "source": "ios",
            "backend": "arkit",
            "sessionActive": isRunning,
            "sessionRunning": isRunning,
            "hasNativeSession": true,
            "hasCameraFrame": latestFrame != nil,
            "anchorCount": anchors.count,
            "nodeCount": nodes.count,
            "modelNodeCount": nodes.values.filter { isModelNode($0) }.count,
            "planeCount": planeCount,
            "imageAnchorCount": imageAnchors.count,
            "trackedImageAnchorCount": trackedImageAnchorCount,
            "depthEnabled": depthEnabled,
            "geospatialEnabled": configuration is ARGeoTrackingConfiguration,
            "bodyTrackingEnabled": configuration is ARBodyTrackingConfiguration
        ]
    }

    // MARK: - Snapshot

    func captureSnapshot() -> Data? {
        guard let frame = latestFrame,
              let pixelBuffer = Optional(frame.capturedImage) else { return nil }

        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        guard let cg = cgImage else { return nil }
        let uiImage = UIImage(cgImage: cg)
        return uiImage.jpegData(compressionQuality: 0.85)
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
        let durationMillis = Self.intValue(
            args,
            "durationMillis",
            defaultValue: encodedFrameCount * 1000 / fps
        )
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

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        latestFrame = frame
        let camera = frame.camera

        let projMatrix = camera.projectionMatrix(for: .landscapeRight,
            viewportSize: frame.camera.imageResolution, zNear: 0.001, zFar: 1000)
        let viewMatrix = camera.viewMatrix(for: .landscapeRight)
        let intr       = camera.intrinsics

        cameraEventSink?([
            "pose":             poseToMap(transform: camera.transform),
            "projectionMatrix": matrixToList(projMatrix),
            "viewMatrix":       matrixToList(viewMatrix),
            "trackingState":    trackingStateName(camera.trackingState),
            "failureReason":    failureReasonName(camera.trackingState),
            "intrinsics":       [Double(intr[0][0]), Double(intr[1][1]),
                                 Double(intr[2][0]), Double(intr[2][1])],
            "imageResolution":  [Int(camera.imageResolution.width),
                                 Int(camera.imageResolution.height)],
        ] as [String: Any])

        if let le = frame.lightEstimate {
            lightEventSink?(le.ambientIntensity)
        }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        emitPlaneUpdates(anchors: anchors)
        emitAnchorUpdates(anchors: anchors)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        emitPlaneUpdates(anchors: anchors)
        emitAnchorUpdates(anchors: anchors)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        emitAnchorUpdates(anchors: anchors, removed: true)
    }

    // MARK: - Hit test (ARKit 4+ raycast)

    func hitTest(normX: Float, normY: Float) -> [[String: Any]] {
        guard let frame = latestFrame else { return [] }
        let pt    = CGPoint(x: CGFloat(normX), y: CGFloat(normY))
        let query = frame.raycastQuery(from: pt, allowing: .estimatedPlane, alignment: .any)
        return arSession.raycast(query).map { r in
            let dist = simd_length(SIMD3<Float>(r.worldTransform.columns.3.x,
                                                r.worldTransform.columns.3.y,
                                                r.worldTransform.columns.3.z))
            return [
                "type":      r.anchor is ARPlaneAnchor ? "plane" : "estimatedHorizontalPlane",
                "worldPose": poseToMap(transform: r.worldTransform),
                "distance":  Double(dist),
                "planeId":   (r.anchor as? ARPlaneAnchor)?.identifier.uuidString ?? "",
                "anchorId":  "",
            ] as [String: Any]
        }
    }

    func sampleDepth(normX: Float, normY: Float) -> Double? {
        guard normX.isFinite, normY.isFinite,
              normX >= 0, normX <= 1, normY >= 0, normY <= 1 else {
            return nil
        }
        guard #available(iOS 14.0, *),
              let depthMap = latestFrame?.smoothedSceneDepth?.depthMap ??
                             latestFrame?.sceneDepth?.depthMap else {
            return nil
        }
        guard CVPixelBufferGetPixelFormatType(depthMap) == kCVPixelFormatType_DepthFloat32 else {
            return nil
        }

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return nil
        }
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard width > 0, height > 0 else { return nil }

        let x = min(max(Int(normX * Float(width - 1)), 0), width - 1)
        let y = min(max(Int(normY * Float(height - 1)), 0), height - 1)
        let stride = CVPixelBufferGetBytesPerRow(depthMap) / MemoryLayout<Float32>.stride
        let values = baseAddress.assumingMemoryBound(to: Float32.self)
        let depthMeters = values[y * stride + x]
        return depthMeters.isFinite && depthMeters > 0 ? Double(depthMeters) : nil
    }

    // MARK: - Anchors

    func addAnchor(from hitMap: [String: Any]) throws -> [String: Any] {
        return try _createAnchor(from: poseFromMap(hitMap["worldPose"] as? [String: Any] ?? [:]))
    }

    func addAnchorAtPose(poseMap: [String: Any]) throws -> [String: Any] {
        return try _createAnchor(from: poseFromMap(poseMap))
    }

    private func _createAnchor(from transform: simd_float4x4) throws -> [String: Any] {
        let arAnchor = ARAnchor(transform: transform)
        arSession.add(anchor: arAnchor)
        let id = arAnchor.identifier.uuidString
        anchors[id] = arAnchor
        return ["id": id, "pose": poseToMap(transform: transform), "trackingState": "tracking"]
    }

    func addGeospatialAnchor(args: [String: Any]) throws -> [String: Any] {
        if #available(iOS 14.0, *) {
            guard configuration is ARGeoTrackingConfiguration else {
                throw NSError(domain: "AREngine", code: 4,
                              userInfo: [NSLocalizedDescriptionKey: "ARKit geospatial tracking is not enabled"])
            }
            guard let anchorArgs = args["anchor"] as? [String: Any],
                  let latitude = Self.doubleArg(anchorArgs, "latitude"),
                  let longitude = Self.doubleArg(anchorArgs, "longitude") else {
                throw NSError(domain: "AREngine", code: 5,
                              userInfo: [NSLocalizedDescriptionKey: "latitude and longitude are required"])
            }
            let altitude = Self.doubleArg(anchorArgs, "altitudeMeters") ?? 0.0
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            guard CLLocationCoordinate2DIsValid(coordinate) else {
                throw NSError(domain: "AREngine", code: 5,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid geospatial coordinate"])
            }

            let geoAnchor = ARGeoAnchor(
                coordinate: coordinate,
                altitude: CLLocationDistance(altitude)
            )
            anchorMetadata[geoAnchor.identifier] = geospatialMetadata(anchorArgs)
            arSession.add(anchor: geoAnchor)
            let id = geoAnchor.identifier.uuidString
            anchors[id] = geoAnchor
            return anchorToMap(geoAnchor)
        }

        throw NSError(domain: "AREngine", code: 4,
                      userInfo: [NSLocalizedDescriptionKey: "AR geospatial tracking requires iOS 14 or newer"])
    }

    private func poseFromMap(_ map: [String: Any]) -> simd_float4x4 {
        let pos = map["position"] as? [String: Any] ?? [:]
        let rot = map["rotation"] as? [String: Any] ?? [:]
        let tx  = (pos["x"] as? Float) ?? 0
        let ty  = (pos["y"] as? Float) ?? 0
        let tz  = (pos["z"] as? Float) ?? 0
        let qx  = (rot["x"] as? Float) ?? 0
        let qy  = (rot["y"] as? Float) ?? 0
        let qz  = (rot["z"] as? Float) ?? 0
        let qw  = (rot["w"] as? Float) ?? 1
        var m   = simd_float4x4(simd_quatf(ix: qx, iy: qy, iz: qz, r: qw))
        m.columns.3 = SIMD4<Float>(tx, ty, tz, 1)
        return m
    }

    func removeAnchor(id: String) {
        if let a = anchors[id] {
            arSession.remove(anchor: a)
            anchorMetadata.removeValue(forKey: a.identifier)
        }
        anchors.removeValue(forKey: id)
    }

    // MARK: - Nodes (SceneKit maintained for fallback; Metal renderer uses nodes dict)

    func addNode(args: [String: Any]) -> String {
        let id = args["id"] as? String ?? UUID().uuidString
        nodes[id] = args
        let scnNode = buildSCNNode(args: args)
        scnNode.name = id
        scnScene.rootNode.addChildNode(scnNode)
        return id
    }

    func updateNode(args: [String: Any]) {
        guard let id = args["id"] as? String else { return }
        nodes[id] = args
        guard let scnNode = scnScene.rootNode.childNode(withName: id, recursively: false) else { return }
        if isPhotoFrameNode(args) || (isModelNode(args) && scnNode.geometry != nil) {
            let replacement = buildSCNNode(args: args)
            replacement.name = id
            scnNode.removeFromParentNode()
            scnScene.rootNode.addChildNode(replacement)
            return
        }
        applyTransform(to: scnNode, from: args)
        // Live-update material if it changed
        if let matMap = args["material"] as? [String: Any] {
            applyMaterial(to: scnNode, from: matMap)
            applyMaterialRecursively(to: scnNode, from: matMap)
        }
    }

    func removeNode(id: String) {
        scnScene.rootNode.childNode(withName: id, recursively: false)?.removeFromParentNode()
        nodes.removeValue(forKey: id)
    }

    // MARK: - SceneKit node builder

    private func buildSCNNode(args: [String: Any]) -> SCNNode {
        if let photoFrameNode = buildPhotoFrameSCNNode(args: args) {
            applyTransform(to: photoFrameNode, from: args)
            return photoFrameNode
        }

        if let modelNode = buildModelSCNNode(args: args) {
            applyTransform(to: modelNode, from: args)
            if let matMap = args["material"] as? [String: Any] {
                applyMaterialRecursively(to: modelNode, from: matMap)
            }
            return modelNode
        }

        let node  = SCNNode()
        let shape = args["primitiveShape"] as? String ?? "cube"
        let szMap = args["primitiveSize"]  as? [String: Any]
        let sx = szMap?["x"] as? CGFloat ?? 0.1
        let sy = szMap?["y"] as? CGFloat ?? 0.1
        let sz = szMap?["z"] as? CGFloat ?? 0.1

        let geometry: SCNGeometry
        switch shape {
        case "sphere":   geometry = SCNSphere(radius: sx / 2)
        case "cylinder": geometry = SCNCylinder(radius: sx / 2, height: sy)
        case "plane":    geometry = SCNPlane(width: sx, height: sz)
        case "capsule":  geometry = SCNCapsule(capRadius: sx / 2, height: sy)
        default:         geometry = SCNBox(width: sx, height: sy, length: sz, chamferRadius: 0)
        }

        if let matMap = args["material"] as? [String: Any] {
            let mat = SCNMaterial()
            applyMaterial(mat: mat, from: matMap)
            geometry.materials = [mat]
        }
        node.geometry = geometry
        applyTransform(to: node, from: args)
        return node
    }

    private func buildPhotoFrameSCNNode(args: [String: Any]) -> SCNNode? {
        guard let metadata = args["metadata"] as? [String: Any],
              isPhotoFrameMetadata(metadata) else {
            return nil
        }

        let size = args["primitiveSize"] as? [String: Any] ?? [:]
        let photoWidth = clamped(CGFloat(Self.doubleArg(size, "x") ?? 0.42), min: 0.08, max: 2.4)
        let photoHeight = clamped(CGFloat(Self.doubleArg(size, "z") ?? 0.28), min: 0.08, max: 2.4)
        let frameDepth = clamped(CGFloat(Self.doubleArg(metadata, "frameDepthMeters") ?? 0.10), min: 0.025, max: 0.24)
        let frameBorder = clamped(CGFloat(Self.doubleArg(metadata, "frameBorderMeters") ?? 0.072), min: 0.02, max: 0.18)
        let photoRecess = CGFloat(Self.doubleArg(metadata, "photoRecessMeters") ?? Double(frameDepth * 0.46))
        let clampedPhotoRecess = clamped(photoRecess, min: 0.008, max: frameDepth * 0.72)
        let backingThickness = CGFloat(Self.doubleArg(metadata, "frameBackingThicknessMeters") ?? Double(frameDepth * 0.18))
        let clampedBackingThickness = clamped(backingThickness, min: 0.004, max: frameDepth * 0.36)
        let topLipHeight = CGFloat(Self.doubleArg(metadata, "frameTopLipHeightMeters") ?? 0.008)
        let clampedTopLipHeight = clamped(topLipHeight, min: 0.002, max: 0.04)
        let outerWidth = photoWidth + frameBorder * 2
        let outerHeight = photoHeight + frameBorder * 2
        let container = SCNNode()
        let style = metadata["photoFrameStyle"] as? [String: Any] ?? [:]
        let backingMaterial = photoFrameMaterial(
            from: style["backingMaterial"] as? [String: Any],
            color: UIColor(red: 0.035, green: 0.032, blue: 0.028, alpha: 1),
            roughness: 0.72
        )
        let frameMaterial = photoFrameMaterial(
            from: style["frameMaterial"] as? [String: Any],
            color: UIColor(red: 0.055, green: 0.046, blue: 0.036, alpha: 1),
            roughness: 0.55,
            doubleSided: true
        )
        let highlightMaterial = photoFrameMaterial(
            from: style["highlightMaterial"] as? [String: Any],
            color: UIColor(red: 0.12, green: 0.095, blue: 0.064, alpha: 1),
            roughness: 0.48
        )

        container.addChildNode(photoFrameBox(
            name: "backing",
            position: SCNVector3(0, Float(-frameDepth / 2 + clampedBackingThickness / 2), 0),
            size: SCNVector3(Float(outerWidth), Float(clampedBackingThickness), Float(outerHeight)),
            material: backingMaterial
        ))
        container.addChildNode(photoFrameBox(
            name: "topRail",
            position: SCNVector3(0, 0, Float(photoHeight / 2 + frameBorder / 2)),
            size: SCNVector3(Float(outerWidth), Float(frameDepth), Float(frameBorder)),
            material: frameMaterial
        ))
        container.addChildNode(photoFrameBox(
            name: "bottomRail",
            position: SCNVector3(0, 0, Float(-photoHeight / 2 - frameBorder / 2)),
            size: SCNVector3(Float(outerWidth), Float(frameDepth), Float(frameBorder)),
            material: frameMaterial
        ))
        container.addChildNode(photoFrameBox(
            name: "leftRail",
            position: SCNVector3(Float(-photoWidth / 2 - frameBorder / 2), 0, 0),
            size: SCNVector3(Float(frameBorder), Float(frameDepth), Float(photoHeight)),
            material: frameMaterial
        ))
        container.addChildNode(photoFrameBox(
            name: "rightRail",
            position: SCNVector3(Float(photoWidth / 2 + frameBorder / 2), 0, 0),
            size: SCNVector3(Float(frameBorder), Float(frameDepth), Float(photoHeight)),
            material: frameMaterial
        ))
        container.addChildNode(photoFrameBox(
            name: "topHighlightLip",
            position: SCNVector3(
                0,
                Float(frameDepth / 2 + clampedTopLipHeight / 2),
                Float(photoHeight / 2 + frameBorder * 0.78)
            ),
            size: SCNVector3(Float(outerWidth * 0.92), Float(clampedTopLipHeight), Float(frameBorder * 0.18)),
            material: highlightMaterial
        ))

        let photoPlane = SCNNode()
        photoPlane.name = "photo"
        photoPlane.geometry = SCNPlane(width: photoWidth, height: photoHeight)
        photoPlane.eulerAngles.x = -Float.pi / 2
        photoPlane.position = SCNVector3(0, Float(frameDepth / 2 - clampedPhotoRecess + 0.002), 0)
        let photoMaterial = SCNMaterial()
        if let image = imageFromPhotoTextureMetadata(metadata) {
            photoMaterial.diffuse.contents = image
            photoMaterial.lightingModel = .constant
        } else if let matMap = args["material"] as? [String: Any] {
            applyMaterial(mat: photoMaterial, from: matMap)
        } else {
            photoMaterial.diffuse.contents = UIColor.white
        }
        photoMaterial.isDoubleSided = true
        photoPlane.geometry?.materials = [photoMaterial]
        container.addChildNode(photoPlane)

        return container
    }

    private func isPhotoFrameNode(_ args: [String: Any]) -> Bool {
        guard let metadata = args["metadata"] as? [String: Any] else {
            return false
        }
        return isPhotoFrameMetadata(metadata)
    }

    private func isPhotoFrameMetadata(_ metadata: [String: Any]) -> Bool {
        guard metadata["photoFrame"] as? Bool == true else {
            return false
        }
        let kind = metadata["photoFrameKind"] as? String
        return kind == nil || kind == "hanging_3d_photo_frame"
    }

    private func clamped(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        return Swift.min(Swift.max(value, min), max)
    }

    private func photoFrameBox(
        name: String,
        position: SCNVector3,
        size: SCNVector3,
        material: SCNMaterial
    ) -> SCNNode {
        let node = SCNNode()
        node.name = name
        node.position = position
        let geometry = SCNBox(
            width: CGFloat(size.x),
            height: CGFloat(size.y),
            length: CGFloat(size.z),
            chamferRadius: 0.004
        )
        geometry.materials = [material]
        node.geometry = geometry
        return node
    }

    private func material(
        color: UIColor,
        roughness: CGFloat,
        metallic: CGFloat = 0,
        doubleSided: Bool = false,
        opacity: CGFloat = 1
    ) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.roughness.contents = roughness
        mat.metalness.contents = metallic
        mat.isDoubleSided = doubleSided
        mat.transparency = opacity
        return mat
    }

    private func photoFrameMaterial(
        from matMap: [String: Any]?,
        color: UIColor,
        roughness: CGFloat,
        metallic: CGFloat = 0,
        doubleSided: Bool = false
    ) -> SCNMaterial {
        let mat = material(
            color: color,
            roughness: roughness,
            metallic: metallic,
            doubleSided: doubleSided
        )
        if let resolvedMap = matMap {
            applyMaterial(mat: mat, from: resolvedMap)
        }
        return mat
    }

    private func imageFromPhotoTextureMetadata(_ metadata: [String: Any]) -> UIImage? {
        if let typedData = metadata["photoTextureBytes"] as? FlutterStandardTypedData {
            return UIImage(data: typedData.data)
        }
        if let data = metadata["photoTextureBytes"] as? Data {
            return UIImage(data: data)
        }
        return nil
    }

    private func buildModelSCNNode(args: [String: Any]) -> SCNNode? {
        guard isModelNode(args) else { return nil }
        let modelAsset = args["modelAsset"] as? [String: Any]
        let rawPath = (modelAsset?["path"] as? String) ?? args["modelPath"] as? String
        guard let path = rawPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty,
              let url = modelAssetURL(for: path, source: modelAsset?["source"] as? String)
        else { return nil }

        guard let scene = try? SCNScene(url: url, options: nil) else { return nil }
        let container = SCNNode()
        for child in scene.rootNode.childNodes {
            container.addChildNode(child.clone())
        }
        if modelAsset?["centerOrigin"] as? Bool ?? true {
            centerPivot(of: container)
        }
        return container.childNodes.isEmpty ? nil : container
    }

    private func isModelNode(_ args: [String: Any]) -> Bool {
        if args["modelAsset"] is [String: Any] { return true }
        if let path = args["modelPath"] as? String,
           !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        let contentType = args["contentType"] as? String ?? "primitive"
        return contentType != "primitive"
    }

    private func modelAssetURL(for path: String, source: String?) -> URL? {
        if source == "file" {
            return URL(fileURLWithPath: path)
        }
        if source == "network" {
            return URL(string: path)
        }
        let assetKey = assetKeyResolver?(path) ?? path
        if let url = Bundle.main.url(forResource: assetKey, withExtension: nil) {
            return url
        }
        if let url = Bundle.main.url(forResource: path, withExtension: nil) {
            return url
        }
        return URL(fileURLWithPath: assetKey)
    }

    private func centerPivot(of node: SCNNode) {
        let bounds = node.boundingBox
        let min = bounds.min
        let max = bounds.max
        let center = SCNVector3(
            (min.x + max.x) / 2,
            (min.y + max.y) / 2,
            (min.z + max.z) / 2
        )
        node.pivot = SCNMatrix4MakeTranslation(center.x, center.y, center.z)
    }

    private func applyMaterial(to node: SCNNode, from matMap: [String: Any]) {
        guard let mat = node.geometry?.firstMaterial else { return }
        applyMaterial(mat: mat, from: matMap)
    }

    private func applyMaterialRecursively(to node: SCNNode, from matMap: [String: Any]) {
        if let geometry = node.geometry {
            let mat = geometry.firstMaterial ?? SCNMaterial()
            applyMaterial(mat: mat, from: matMap)
            geometry.materials = [mat]
        }
        for child in node.childNodes {
            applyMaterialRecursively(to: child, from: matMap)
        }
    }

    private func applyMaterial(mat: SCNMaterial, from matMap: [String: Any]) {
        if let col = matMap["baseColor"] as? [String: Any] {
            mat.diffuse.contents = UIColor(
                red:   (col["r"] as? CGFloat) ?? 1,
                green: (col["g"] as? CGFloat) ?? 1,
                blue:  (col["b"] as? CGFloat) ?? 1,
                alpha: (col["a"] as? CGFloat) ?? 1)
        }
        mat.metalness.contents = matMap["metallic"]   as? CGFloat ?? 0.0
        mat.roughness.contents = matMap["roughness"]  as? CGFloat ?? 0.5
        mat.isDoubleSided      = matMap["doubleSided"] as? Bool ?? false
        mat.transparency       = clamped(
            CGFloat(Self.doubleArg(matMap, "opacity") ?? 1.0),
            min: 0,
            max: 1
        )
        if let texPath = matMap["baseColorTexturePath"] as? String,
           let img = UIImage(named: texPath) { mat.diffuse.contents = img }
        if let nrmPath = matMap["normalMapPath"] as? String,
           let img = UIImage(named: nrmPath) { mat.normal.contents = img }
    }

    private func applyTransform(to node: SCNNode, from args: [String: Any]) {
        if let p = args["position"] as? [String: Any] {
            node.position = SCNVector3(p["x"] as? Float ?? 0, p["y"] as? Float ?? 0, p["z"] as? Float ?? 0)
        }
        if let r = args["rotation"] as? [String: Any] {
            node.orientation = SCNQuaternion(r["x"] as? Float ?? 0, r["y"] as? Float ?? 0,
                                              r["z"] as? Float ?? 0, r["w"] as? Float ?? 1)
        }
        if let s = args["scale"] as? [String: Any] {
            node.scale = SCNVector3(s["x"] as? Float ?? 1, s["y"] as? Float ?? 1, s["z"] as? Float ?? 1)
        }
    }

    // MARK: - Event emission helpers

    private func emitPlaneUpdates(anchors: [ARAnchor]) {
        let planes = anchors.compactMap { $0 as? ARPlaneAnchor }.map { planeToMap($0) }
        if !planes.isEmpty { planeEventSink?(planes) }
    }

    private func emitAnchorUpdates(anchors: [ARAnchor], removed: Bool = false) {
        for a in anchors {
            anchorEventSink?(anchorToMap(a, removed: removed))
        }
    }

    private func anchorToMap(_ anchor: ARAnchor, removed: Bool = false) -> [String: Any] {
        var trackingState = removed ? "stopped" : "tracking"
        var metadata = anchorMetadata[anchor.identifier] ?? [String: Any]()

        if let imageAnchor = anchor as? ARImageAnchor {
            trackingState = removed || !imageAnchor.isTracked ? "stopped" : "tracking"
            metadata["imageTargetName"] = imageAnchor.referenceImage.name ?? ""
            metadata["estimatedPhysicalWidth"] = Double(imageAnchor.referenceImage.physicalSize.width)
        }

        if #available(iOS 14.0, *), let geoAnchor = anchor as? ARGeoAnchor {
            metadata["latitude"] = geoAnchor.coordinate.latitude
            metadata["longitude"] = geoAnchor.coordinate.longitude
            metadata["altitudeMeters"] = geoAnchor.altitude
            metadata["nativeGeospatial"] = true
        }

        if let bodyAnchor = anchor as? ARBodyAnchor {
            trackingState = removed ? "stopped" : "tracking"
            metadata = bodyAnchorMetadata(bodyAnchor)
        }

        return ["id": anchor.identifier.uuidString,
                "pose": poseToMap(transform: anchor.transform),
                "trackingState": trackingState,
                "metadata": metadata]
    }

    private func geospatialMetadata(_ anchorArgs: [String: Any]) -> [String: Any] {
        var metadata = anchorArgs["metadata"] as? [String: Any] ?? [String: Any]()
        metadata["geospatialAnchorId"] = anchorArgs["id"] as? String ?? ""
        metadata["latitude"] = Self.doubleArg(anchorArgs, "latitude") ?? 0.0
        metadata["longitude"] = Self.doubleArg(anchorArgs, "longitude") ?? 0.0
        metadata["altitudeMeters"] = Self.doubleArg(anchorArgs, "altitudeMeters") ?? 0.0
        metadata["headingDegrees"] = Self.doubleArg(anchorArgs, "headingDegrees") ?? 0.0
        metadata["pitchDegrees"] = Self.doubleArg(anchorArgs, "pitchDegrees") ?? 0.0
        metadata["rollDegrees"] = Self.doubleArg(anchorArgs, "rollDegrees") ?? 0.0
        metadata["correctionEastMeters"] = Self.doubleArg(anchorArgs, "correctionEastMeters") ?? 0.0
        metadata["correctionNorthMeters"] = Self.doubleArg(anchorArgs, "correctionNorthMeters") ?? 0.0
        metadata["correctionUpMeters"] = Self.doubleArg(anchorArgs, "correctionUpMeters") ?? 0.0
        metadata["nativeGeospatial"] = true
        return metadata
    }

    private func bodyAnchorMetadata(_ bodyAnchor: ARBodyAnchor) -> [String: Any] {
        let skeleton = bodyAnchor.skeleton
        let jointNames = skeleton.definition.jointNames
        let jointTransforms = skeleton.jointModelTransforms
        var emittedJoints = Set<String>()
        var joints = [[String: Any]]()

        for index in 0..<min(jointNames.count, jointTransforms.count) {
            let rawName = jointNames[index]
            guard let joint = dartBodyJointName(from: rawName),
                  !emittedJoints.contains(joint) else { continue }
            emittedJoints.insert(joint)

            let worldTransform = bodyAnchor.transform * jointTransforms[index]
            joints.append([
                "joint": joint,
                "pose": poseToMap(transform: worldTransform),
                "confidence": 1.0,
                "isTracked": true,
            ])
        }

        return [
            "bodyId": bodyAnchor.identifier.uuidString,
            "joints": joints,
        ]
    }

    private func dartBodyJointName(from rawName: String) -> String? {
        let name = rawName.lowercased()

        if name.contains("head") { return "head" }
        if name.contains("neck") { return "neck" }
        if name.contains("hips") || name == "root" { return "hips" }
        if name.contains("spine_1") { return "spine1" }
        if name.contains("spine_2") { return "spine2" }
        if name.contains("spine_3") { return "spine3" }
        if name.contains("spine_4") || name.contains("spine_5") ||
            name.contains("spine_6") || name.contains("spine_7") {
            return "chest"
        }

        if name.contains("left_shoulder") { return "leftShoulder" }
        if name.contains("right_shoulder") { return "rightShoulder" }
        if name.contains("left_arm") { return "leftElbow" }
        if name.contains("right_arm") { return "rightElbow" }
        if name.contains("left_forearm") { return "leftWrist" }
        if name.contains("right_forearm") { return "rightWrist" }
        if name.contains("left_hand") { return "leftHand" }
        if name.contains("right_hand") { return "rightHand" }

        if name.contains("left_upleg") || name.contains("left_up_leg") { return "leftHip" }
        if name.contains("right_upleg") || name.contains("right_up_leg") { return "rightHip" }
        if name.contains("left_leg") { return "leftKnee" }
        if name.contains("right_leg") { return "rightKnee" }
        if name.contains("left_foot") { return "leftAnkle" }
        if name.contains("right_foot") { return "rightAnkle" }
        if name.contains("left_toes") { return "leftFoot" }
        if name.contains("right_toes") { return "rightFoot" }

        return nil
    }

    private func planeToMap(_ p: ARPlaneAnchor) -> [String: Any] {
        var boundary = [[String: Double]]()
        for v in p.geometry.boundaryVertices {
            boundary.append(["x": Double(v.x), "y": Double(v.y), "z": Double(v.z)])
        }
        let extent = planeExtentMeters(for: p)
        return ["id": p.identifier.uuidString,
                "alignment": p.alignment == .vertical ? "vertical" : "horizontal",
                "centerPose": poseToMap(transform: p.transform),
                "extentMeters": ["x": Double(extent.width), "y": 0.0,
                                 "z": Double(extent.height)],
                "boundaryVertices": boundary,
                "trackingState": "tracking"]
    }

    private func planeExtentMeters(for planeAnchor: ARPlaneAnchor) -> (width: Float, height: Float) {
        if #available(iOS 16.0, *) {
            return (
                Float(planeAnchor.planeExtent.width),
                Float(planeAnchor.planeExtent.height)
            )
        }
        return (planeAnchor.extent.x, planeAnchor.extent.z)
    }

    // MARK: - Utilities

    func poseToMap(transform t: simd_float4x4) -> [String: Any] {
        let q = simd_quatf(t)
        return ["position": ["x": Double(t.columns.3.x), "y": Double(t.columns.3.y),
                              "z": Double(t.columns.3.z)],
                "rotation": ["x": Double(q.imag.x), "y": Double(q.imag.y),
                              "z": Double(q.imag.z), "w": Double(q.real)]]
    }

    private func matrixToList(_ m: simd_float4x4) -> [Double] {
        [m.columns.0,m.columns.1,m.columns.2,m.columns.3].flatMap {
            [Double($0.x),Double($0.y),Double($0.z),Double($0.w)]
        }
    }

    private func trackingStateName(_ s: ARCamera.TrackingState) -> String {
        switch s {
        case .normal: return "tracking"
        case .notAvailable: return "initializing"
        case .limited(.initializing): return "initializing"
        case .limited(.relocalizing): return "relocalizing"
        case .limited(.excessiveMotion): return "paused"
        case .limited(.insufficientFeatures): return "paused"
        default: return "tracking"
        }
    }

    private func failureReasonName(_ s: ARCamera.TrackingState) -> String? {
        switch s {
        case .limited(.insufficientFeatures): return "insufficientFeatures"
        case .limited(.excessiveMotion):      return "excessiveMotion"
        case .limited(.relocalizing):         return "relocalizing"
        case .limited(.initializing):         return "initializing"
        default: return nil
        }
    }
}

// ─── Stream handler helper ────────────────────────────────────────────────────

class StreamHandler: NSObject, FlutterStreamHandler {
    private let cb: (FlutterEventSink?) -> Void
    init(_ cb: @escaping (FlutterEventSink?) -> Void) { self.cb = cb }
    func onListen(withArguments a: Any?, eventSink e: @escaping FlutterEventSink) -> FlutterError? { cb(e); return nil }
    func onCancel(withArguments a: Any?) -> FlutterError? { cb(nil); return nil }
}

// ─── Metal platform view factory (replaces ARViewFactory/ARKitPlatformView) ──

private final class WeakARMetalPlatformView {
    weak var value: ARMetalPlatformView?
    init(_ value: ARMetalPlatformView) { self.value = value }
}

class ARMetalViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private let assetKeyResolver: ((String) -> String)?
    private static var activeViews = [WeakARMetalPlatformView]()
    static weak var activeSession: ARKitSession? {
        didSet {
            syncActiveSessionToViews()
        }
    }

    init(messenger: FlutterBinaryMessenger,
         assetKeyResolver: ((String) -> String)? = nil) {
        self.messenger = messenger
        self.assetKeyResolver = assetKeyResolver
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
                arguments args: Any?) -> FlutterPlatformView {
        let config = args as? [String: Any] ?? [:]
        let view = ARMetalPlatformView(frame: frame,
                                       device: MTLCreateSystemDefaultDevice(),
                                       config: config,
                                       assetKeyResolver: assetKeyResolver,
                                       sharedSession: Self.activeSession)
        Self.register(view)
        return view
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    private static func register(_ view: ARMetalPlatformView) {
        activeViews.removeAll { $0.value == nil || $0.value === view }
        activeViews.append(WeakARMetalPlatformView(view))
        apply(session: activeSession, to: view)
    }

    private static func syncActiveSessionToViews() {
        activeViews.removeAll { $0.value == nil }
        for view in activeViews.compactMap({ $0.value }) {
            apply(session: activeSession, to: view)
        }
    }

    private static func apply(session: ARKitSession?, to view: ARMetalPlatformView) {
        if let session = session {
            view.attachSharedSession(session)
        } else {
            view.detachSharedSession()
        }
    }
}
