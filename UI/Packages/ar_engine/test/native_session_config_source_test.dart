import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('native session config sources', () {
    test('Android maps Dart session flags into ARCore Config', () {
      final source = File(
        'android/src/main/kotlin/com/arengine/ar_engine/ArEnginePlugin.kt',
      ).readAsStringSync();

      expect(
        source,
        contains('fun buildConfig(session: Session, args: Map<*, *>?): Config'),
      );
      expect(
        source,
        contains('FlutterPlugin.FlutterAssets'),
      );
      expect(
        source,
        contains(
          'buildAugmentedImageDatabase(session, args, context, flutterAssets)',
        ),
      );
      expect(source, contains('AugmentedImageDatabase(session)'));
      expect(source, contains('getAssetFilePathByName(assetPath)'));
      expect(source, contains('BitmapFactory.decodeStream(input)'));
      expect(
        source,
        contains('database.addImage(name, bitmap, physicalWidth)'),
      );
      expect(
        source,
        contains('session?.getAllTrackables(AugmentedImage::class.java)'),
      );
      expect(source, contains('private fun AugmentedImage.toAnchorMap()'));
      expect(source, contains('"imageTargetName" to name'));
      expect(source, contains('Config.PlaneFindingMode.DISABLED'));
      expect(source, contains('Config.CloudAnchorMode.ENABLED'));
      expect(source, contains('Config.DepthMode.AUTOMATIC'));
      expect(
        source,
        contains('session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)'),
      );
      expect(source, contains('"getCapabilities"'));
      expect(source, contains('private fun handleGetCapabilities'));
      expect(source, contains('"supportsSceneDepth" to sceneDepthSupported'));
      expect(source, contains('"supportsGeospatial" to geospatialSupported'));
      expect(source, contains('"supportsRecordingEncode" to arSupported'));
      expect(source, contains('"getRuntimeDiagnostics"'));
      expect(source, contains('private fun handleRuntimeDiagnostics'));
      expect(source, contains('fun runtimeDiagnostics(): Map<String, Any?>'));
      expect(source, contains('"source" to "android"'));
      expect(source, contains('"backend" to "arcore"'));
      expect(source, contains('"sessionActive" to (s != null && isRunning)'));
      expect(source, contains('"hasCameraFrame" to (latestFrame != null)'));
      expect(source, contains('"anchorCount" to anchors.size'));
      expect(source, contains('"nodeCount" to nodes.size'));
      expect(source, contains('"modelNodeCount" to nodes.values.count'));
      expect(source, contains('"sampleDepth"'));
      expect(source, contains('"encodeRecording"'));
      expect(source, contains('private fun handleEncodeRecording'));
      expect(source, contains('MediaCodec.createEncoderByType'));
      expect(source, contains('MediaMuxer(outputFile.absolutePath'));
      expect(source, contains('MediaFormat.MIMETYPE_VIDEO_AVC'));
      expect(source, contains('BitmapFactory.decodeByteArray'));
      expect(source, contains('private fun Bitmap.toYuv420'));
      expect(source, contains('"filePath" to outputFile.absolutePath'));
      expect(source, contains('private fun handleSampleDepth'));
      expect(source, contains('frame.acquireDepthImage16Bits()'));
      expect(source, contains('ByteOrder.LITTLE_ENDIAN'));
      expect(source, contains('"hostCloudAnchor"'));
      expect(source, contains('"resolveCloudAnchor"'));
      expect(source, contains('s.hostCloudAnchorAsync(anchor, clampedTtl)'));
      expect(source, contains('s.resolveCloudAnchorAsync(cloudId)'));
      expect(source, contains('"nativeCloudAnchor" to true'));
      expect(
        source,
        contains(
          'val geospatialEnabled = boolArg(args, "geospatialEnabled", false)',
        ),
      );
      expect(source, contains('Config.GeospatialMode.ENABLED'));
      expect(
        source,
        contains(
          'session.isGeospatialModeSupported(Config.GeospatialMode.ENABLED)',
        ),
      );
      expect(source, contains('"addGeospatialAnchor"'));
      expect(source, contains('fun addGeospatialAnchor(args: Map<*, *>)'));
      expect(source, contains('earth.createAnchor('));
      expect(source, contains('"nativeGeospatial"'));
      expect(source, contains('metadata["correctionEastMeters"]'));
      expect(source, contains('metadata["correctionNorthMeters"]'));
      expect(source, contains('metadata["correctionUpMeters"]'));
      expect(
        source,
        contains(
          'val bodyTrackingEnabled = boolArg(args, "bodyTrackingEnabled", false)',
        ),
      );
      expect(
        source,
        contains('ARCore Session Config has no native body skeleton tracking'),
      );
      expect(
        source,
        contains('updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE'),
      );
    });

    test('Android normalizes model-backed node payloads', () {
      final pluginSource = File(
        'android/src/main/kotlin/com/arengine/ar_engine/ArEnginePlugin.kt',
      ).readAsStringSync();
      final rendererSource = File(
        'android/src/main/kotlin/com/arengine/ar_engine/gl/ARCoreGLRenderer.kt',
      ).readAsStringSync();

      expect(pluginSource, contains('normalizeNodeArgs(args)'));
      expect(pluginSource, contains('modelAssetResolvedPath'));
      expect(
        pluginSource,
        contains('resolveModelAssetPath(modelPath, source)'),
      );
      expect(
        pluginSource,
        contains('flutterAssets?.getAssetFilePathByName(path)'),
      );
      expect(
        pluginSource,
        contains('inferContentTypeFromModelPath(modelPath)'),
      );
      expect(pluginSource, contains('"fallbackSizeMeters"'));
      expect(pluginSource, contains('normalized["modelFallbackShape"]'));
      expect(rendererSource, contains('fallbackPrimitiveShape(nodeMap)'));
      expect(rendererSource, contains('isModelNode(nodeMap)'));
      expect(
        rendererSource,
        contains(
          'Model assets render with primitive fallback until Android mesh loading is available.',
        ),
      );
    });

    test('Android has cached OBJ model mesh loader', () {
      final pluginSource = File(
        'android/src/main/kotlin/com/arengine/ar_engine/ArEnginePlugin.kt',
      ).readAsStringSync();
      final rendererSource = File(
        'android/src/main/kotlin/com/arengine/ar_engine/gl/ARCoreGLRenderer.kt',
      ).readAsStringSync();
      final cacheSource = File(
        'android/src/main/kotlin/com/arengine/ar_engine/gl/ModelMeshCache.kt',
      ).readAsStringSync();

      expect(
        pluginSource,
        contains('modelInputStreamProvider = { nodeMap, path ->'),
      );
      expect(
        pluginSource,
        contains('openAndroidModelInputStream(context, nodeMap, path)'),
      );
      expect(
        rendererSource,
        contains('ModelMeshCache.getOrNull(nodeMap, modelInputStreamProvider)'),
      );
      expect(rendererSource, contains('ModelMeshCache.releaseAll()'));
      expect(
        rendererSource,
        contains('internal fun openAndroidModelInputStream('),
      );
      expect(cacheSource, contains('object ModelMeshCache'));
      expect(
        cacheSource,
        contains('private val cache = mutableMapOf<String, GPUMesh>()'),
      );
      expect(
        cacheSource,
        contains('private val failedKeys = mutableSetOf<String>()'),
      );
      expect(cacheSource, contains('if (format != "obj") return null'));
      expect(cacheSource, contains('cache[key] = mesh'));
      expect(cacheSource, contains('private object ObjMeshParser'));
      expect(
        cacheSource,
        contains(
          'fun parse(inputStream: InputStream, centerOrigin: Boolean): GPUMesh',
        ),
      );
      expect(
        cacheSource,
        contains(
          'appendFace(parts.drop(1), positions, texCoords, normals, vertices)',
        ),
      );
      expect(
        cacheSource,
        contains('appendTriangle(face[0], face[i], face[i + 1], vertices)'),
      );
      expect(
        cacheSource,
        contains('GPUMesh.upload(vertices.toFloatArray())'),
      );
      expect(
        cacheSource,
        contains('if (centerOrigin) centerVertices(vertices)'),
      );
    });

    test('native hanging photo frame renderers consume style metadata', () {
      final androidRendererSource = File(
        'android/src/main/kotlin/com/arengine/ar_engine/gl/ARCoreGLRenderer.kt',
      ).readAsStringSync();
      final iosPluginSource =
          File('ios/Classes/ArEnginePlugin.swift').readAsStringSync();
      final iosMetalRendererSource =
          File('ios/Classes/Rendering/MetalARRenderer.swift')
              .readAsStringSync();

      expect(androidRendererSource, contains('photoFrameStyle'));
      expect(androidRendererSource, contains('frameMaterial('));
      expect(androidRendererSource, contains('backingMaterial'));
      expect(androidRendererSource, contains('highlightMaterial'));
      expect(androidRendererSource, contains('frameBackingThicknessMeters'));
      expect(androidRendererSource, contains('frameTopLipHeightMeters'));
      expect(androidRendererSource, contains('preset='));
      expect(
        androidRendererSource,
        contains('styleKey = "backingThicknessMeters"'),
      );

      expect(iosPluginSource, contains('photoFrameMaterial('));
      expect(iosPluginSource, contains('style["frameMaterial"]'));
      expect(iosPluginSource, contains('style["backingMaterial"]'));
      expect(iosPluginSource, contains('style["highlightMaterial"]'));
      expect(
        iosPluginSource,
        contains('mat.transparency       = clamped('),
      );

      expect(iosMetalRendererSource, contains('struct MetalNodeMaterial'));
      expect(iosMetalRendererSource, contains('let anchorTransforms'));
      expect(iosMetalRendererSource, contains('drawHangingPhotoFrame('));
      expect(iosMetalRendererSource, contains('includePrimitiveSize: false'));
      expect(iosMetalRendererSource, contains('primitiveSizeScale(for:'));
      expect(iosMetalRendererSource, contains('meshBaseExtent(for: shape)'));
      expect(iosMetalRendererSource, contains('frameStyleFloat('));
      expect(iosMetalRendererSource, contains('Float(value.doubleValue)'));
      expect(iosMetalRendererSource, contains('MTKTextureLoader'));
      expect(iosMetalRendererSource, contains('photoTextureBytes'));
      expect(iosMetalRendererSource, contains('FlutterStandardTypedData'));
      expect(iosMetalRendererSource, contains('setFragmentTexture'));
      expect(iosMetalRendererSource, contains('baseColorUvTransform'));
      expect(iosMetalRendererSource, contains('useBaseColorTexture'));
      expect(iosMetalRendererSource, contains('coverUvTransform('));
    });

    test('web renderer preserves scene graphs and cached photo textures', () {
      final webSource = File('lib/ar_engine_web.dart').readAsStringSync();

      expect(
        webSource,
        contains('final _nodeAnchorIds = <String, String?>{};'),
      );
      expect(
        webSource,
        contains('final _nodeRenderEpochs = <String, int>{};'),
      );
      expect(
        webSource,
        contains('final _threeTextureCache = <String, Object?>{};'),
      );
      expect(
        webSource,
        contains('final _threeModelCache = <String, Object?>{};'),
      );
      expect(webSource, contains('class _WebRuntimeDiagnostics'));
      expect(webSource, contains('__arEngineWebDiagnostics'));
      expect(webSource, contains("increment('nodesAdded')"));
      expect(webSource, contains("increment('nodesUpdated')"));
      expect(webSource, contains("increment('nodesRemoved')"));
      expect(webSource, contains("increment('nodesRendered')"));
      expect(webSource, contains("increment('nodesSkippedMissingThree')"));
      expect(webSource, contains('recordThreeAvailability(three)'));
      expect(
        webSource,
        contains('_injectWebGLNode(node, anchorId: resolvedAnchorId)'),
      );
      expect(
        webSource,
        contains('_rebuildWebGLNode(node, anchorId: resolvedAnchorId)'),
      );
      expect(webSource, contains('_nodeRenderEpochs.remove(nodeId)'));
      expect(webSource, contains("getProperty(three, 'Group')"));
      expect(
        webSource,
        contains('_applyThreeAnchorTransform(root, anchorId)'),
      );
      expect(webSource, contains('for (final child in node.children)'));
      expect(
        webSource,
        contains('node.primitiveSize ?? _defaultPrimitiveSize(shape)'),
      );
      expect(webSource, contains("setProperty(scale, 'x', node.scale.x)"));
      expect(webSource, contains('math.pi / 2'));
      expect(
        webSource,
        contains("_metadataBytes(node.metadata['photoTextureBytes'])"),
      );
      expect(webSource, contains('base64Encode(bytes)'));
      expect(webSource, contains('_threeTextureCache[cacheKey] = texture'));
      expect(
        webSource,
        contains('node.primitiveShape == ARPrimitiveShape.plane'),
      );
      expect(
        webSource,
        contains('final renderEpoch = _beginWebGLNodeRender(node.id)'),
      );
      expect(webSource, contains('rootNodeId: node.id'));
      expect(webSource, contains('renderEpoch: renderEpoch'));
      expect(
        webSource,
        contains(
          'bool _isCurrentWebGLNodeRender(String rootNodeId, int renderEpoch)',
        ),
      );
      expect(
        webSource,
        contains(
          'if (!_isCurrentWebGLNodeRender(rootNodeId, renderEpoch)) return;',
        ),
      );
      expect(webSource, contains("'glb' || 'gltf' => 'GLTFLoader'"));
      expect(webSource, contains("'obj' => 'OBJLoader'"));
      expect(webSource, contains("'gltfLoaderAvailable'"));
      expect(webSource, contains("'objLoaderAvailable'"));
      expect(webSource, contains("'textureLoaderAvailable'"));
      expect(webSource, contains('getProperty(web.window, constructorName)'));
      expect(webSource, contains("increment('modelLoadStarted')"));
      expect(webSource, contains("increment('modelLoadSucceeded')"));
      expect(webSource, contains("increment('modelLoadFailed')"));
      expect(webSource, contains("increment('modelFallbackUsed')"));
      expect(webSource, contains("increment('modelCacheHits')"));
      expect(
        webSource,
        contains("increment('modelStaleCallbacksIgnored')"),
      );
      expect(webSource, contains('_threeModelCache[cacheKey] = model'));
      expect(webSource, contains("'lastModelStatus': 'loaded'"));
      expect(webSource, contains("'lastModelStatus': 'staleLoadIgnored'"));
      expect(
        webSource,
        contains("'lastModelStatus': 'fallbackAfterLoadError'"),
      );
      expect(webSource, contains('_flutterWebAssetUrl(path'));
      expect(
        webSource,
        contains(r"'packages/${package.trim()}/$normalized'"),
      );
      expect(
        webSource,
        contains(
          'Keep the primitive fallback visible when a web model loader fails.',
        ),
      );
      expect(webSource, contains("increment('textureLoadStarted')"));
      expect(webSource, contains("increment('textureLoadSucceeded')"));
      expect(webSource, contains("increment('textureLoadFailed')"));
      expect(webSource, contains("increment('textureCacheHits')"));
    });

    test('iOS maps Dart session flags into ARKit configuration', () {
      final pluginSource =
          File('ios/Classes/ArEnginePlugin.swift').readAsStringSync();
      final viewSource = File('ios/Classes/Rendering/ARMetalPlatformView.swift')
          .readAsStringSync();
      final combinedSource = '$pluginSource\n$viewSource';

      expect(pluginSource, contains('arSession = s'));
      expect(
        pluginSource,
        contains('registrar.lookupKey(forAsset: assetPath)'),
      );
      expect(pluginSource, contains('buildModelSCNNode(args: args)'));
      expect(pluginSource, contains('buildPhotoFrameSCNNode(args: args)'));
      expect(pluginSource, contains('photoFrameKind'));
      expect(pluginSource, contains('hanging_3d_photo_frame'));
      expect(pluginSource, contains('photoTextureBytes'));
      expect(pluginSource, contains('FlutterStandardTypedData'));
      expect(pluginSource, contains('UIImage(data: typedData.data)'));
      expect(pluginSource, contains('SCNPlane(width: photoWidth'));
      expect(pluginSource, contains('SCNBox('));
      expect(pluginSource, contains('modelAssetURL(for: path'));
      expect(pluginSource, contains('assetKeyResolver?(path)'));
      expect(pluginSource, contains('SCNScene(url: url, options: nil)'));
      expect(pluginSource, contains('applyMaterialRecursively(to: modelNode'));
      expect(
        pluginSource,
        contains('assetKeyResolver: @escaping (String) -> String'),
      );
      expect(
        pluginSource,
        contains('assetKeyResolver: ((String) -> String)? = nil'),
      );
      expect(
        pluginSource,
        contains('static func buildConfig('),
      );
      expect(
        pluginSource,
        contains(') throws -> ARConfiguration'),
      );
      expect(
        pluginSource,
        contains('return try buildBodyTrackingConfig(from: args)'),
      );
      expect(
        pluginSource,
        contains('if boolArg(args, "geospatialEnabled", false)'),
      );
      expect(
        pluginSource,
        contains('return try buildGeoTrackingConfig(from: args)'),
      );
      expect(
        pluginSource,
        contains('ARGeoTrackingConfiguration.isSupported'),
      );
      expect(pluginSource, contains('case "getCapabilities"'));
      expect(pluginSource, contains('private static func capabilitiesMap()'));
      expect(pluginSource, contains('"supportsSceneDepth": sceneDepth'));
      expect(pluginSource, contains('"supportsGeospatial": geospatial'));
      expect(
        pluginSource,
        contains('"supportsRecordingEncode": worldTracking'),
      );
      expect(pluginSource, contains('case "getRuntimeDiagnostics"'));
      expect(
        pluginSource,
        contains('private static func inactiveRuntimeDiagnostics'),
      );
      expect(
        pluginSource,
        contains('func runtimeDiagnostics() -> [String: Any]'),
      );
      expect(pluginSource, contains('"source": "ios"'));
      expect(pluginSource, contains('"backend": "arkit"'));
      expect(pluginSource, contains('"sessionActive": isRunning'));
      expect(pluginSource, contains('"hasCameraFrame": latestFrame != nil'));
      expect(pluginSource, contains('"anchorCount": anchors.count'));
      expect(pluginSource, contains('"nodeCount": nodes.count'));
      expect(pluginSource, contains('"modelNodeCount": nodes.values.filter'));
      expect(pluginSource, contains('case "sampleDepth"'));
      expect(pluginSource, contains('case "encodeRecording"'));
      expect(
        pluginSource,
        contains('try arSession?.encodeRecording(args: args)'),
      );
      expect(
        pluginSource,
        contains('func encodeRecording(args: [String: Any]) throws'),
      );
      expect(pluginSource, contains('AVAssetWriter(outputURL: outputURL'));
      expect(pluginSource, contains('AVAssetWriterInputPixelBufferAdaptor'));
      expect(pluginSource, contains('AVVideoCodecType.h264'));
      expect(pluginSource, contains('CGImageSourceCreateWithData'));
      expect(pluginSource, contains('"filePath": outputURL.path'));
      expect(
        pluginSource,
        contains('func sampleDepth(normX: Float, normY: Float)'),
      );
      expect(
        pluginSource,
        contains('latestFrame?.smoothedSceneDepth?.depthMap'),
      );
      expect(pluginSource, contains('kCVPixelFormatType_DepthFloat32'));
      expect(
        pluginSource,
        contains('case "hostCloudAnchor", "resolveCloudAnchor"'),
      );
      expect(pluginSource, contains('"addGeospatialAnchor"'));
      expect(
        pluginSource,
        contains('func addGeospatialAnchor(args: [String: Any]) throws'),
      );
      expect(pluginSource, contains('ARGeoAnchor('));
      expect(pluginSource, contains('metadata["nativeGeospatial"] = true'));
      expect(pluginSource, contains('metadata["correctionEastMeters"]'));
      expect(pluginSource, contains('metadata["correctionNorthMeters"]'));
      expect(pluginSource, contains('metadata["correctionUpMeters"]'));
      expect(
        pluginSource,
        contains('code = nsError.code == 4 ? "UNSUPPORTED_GEOSPATIAL"'),
      );
      expect(
        viewSource,
        contains('assetKeyResolver: assetKeyResolver'),
      );
      expect(
        viewSource,
        contains('guard let cfg = try? ARKitSession.buildConfig('),
      );
      expect(
        pluginSource,
        contains(
          'applyImageTargets(from: args, to: cfg, assetKeyResolver: assetKeyResolver)',
        ),
      );
      expect(
        pluginSource,
        contains('private static func buildDetectionImages'),
      );
      expect(pluginSource, contains('ARReferenceImage('));
      expect(pluginSource, contains('UIImage(named: assetKey)?.cgImage'));
      expect(pluginSource, contains('cfg.detectionImages = detectionImages'));
      expect(
        pluginSource,
        contains('cfg.maximumNumberOfTrackedImages = detectionImages.count'),
      );
      expect(
        pluginSource,
        contains('if let imageAnchor = anchor as? ARImageAnchor'),
      );
      expect(
        pluginSource,
        contains(
          'metadata["imageTargetName"] = imageAnchor.referenceImage.name ?? ""',
        ),
      );
      expect(
        pluginSource,
        contains('cfg.frameSemantics = supportedFrameSemantics('),
      );
      expect(
        pluginSource,
        contains(
          'supports: ARWorldTrackingConfiguration.supportsFrameSemantics',
        ),
      );
      expect(
        pluginSource,
        contains(
          'supportedVideoFormats: ARWorldTrackingConfiguration.supportedVideoFormats',
        ),
      );
      expect(
        pluginSource,
        contains(
          'private static func buildBodyTrackingConfig(from args: [String: Any]) throws -> ARBodyTrackingConfiguration',
        ),
      );
      expect(pluginSource, contains('ARBodyTrackingConfiguration.isSupported'));
      expect(
        pluginSource,
        contains('AR body tracking is not supported on this device'),
      );
      expect(
        pluginSource,
        contains(
          'supports: ARBodyTrackingConfiguration.supportsFrameSemantics',
        ),
      );
      expect(
        pluginSource,
        contains(
          'supportedVideoFormats: ARBodyTrackingConfiguration.supportedVideoFormats',
        ),
      );
      expect(
        pluginSource,
        contains('supportedVideoFormats.min'),
      );
      expect(pluginSource, contains('cfg.videoFormat = format'));
      expect(
        pluginSource,
        contains('if let value = args[key] as? NSNumber'),
      );
      expect(
        pluginSource,
        contains('try arSession?.reconfigure(args: args)'),
      );
      expect(
        pluginSource,
        contains('FlutterError(code: "RECONFIGURE_FAILED"'),
      );
      expect(
        pluginSource,
        contains('if let bodyAnchor = anchor as? ARBodyAnchor'),
      );
      expect(
        pluginSource,
        contains('metadata = bodyAnchorMetadata(bodyAnchor)'),
      );
      expect(
        pluginSource,
        contains('private func bodyAnchorMetadata(_ bodyAnchor: ARBodyAnchor)'),
      );
      expect(pluginSource, contains('skeleton.jointModelTransforms'));
      expect(
        pluginSource,
        contains('"bodyId": bodyAnchor.identifier.uuidString'),
      );
      expect(pluginSource, contains('"joints": joints'));
      expect(
        pluginSource,
        contains('private func dartBodyJointName(from rawName: String)'),
      );
      expect(pluginSource, contains('return "leftWrist"'));
      expect(
        RegExp('class ARMetalViewFactory').allMatches(combinedSource),
        hasLength(1),
      );
      expect(
        pluginSource,
        contains('private final class WeakARMetalPlatformView'),
      );
      expect(
        pluginSource,
        contains(
          'private static var activeViews = [WeakARMetalPlatformView]()',
        ),
      );
      expect(
        pluginSource,
        contains('private static func register(_ view: ARMetalPlatformView)'),
      );
      expect(
        pluginSource,
        contains(
          r'activeViews.removeAll { $0.value == nil || $0.value === view }',
        ),
      );
      expect(
        pluginSource,
        contains(r'for view in activeViews.compactMap({ $0.value })'),
      );
      expect(pluginSource, contains('apply(session: activeSession, to: view)'));
      expect(pluginSource, contains('sharedSession: Self.activeSession'));
      expect(
        viewSource,
        contains('sharedSession: ARKitSession? = nil'),
      );
      expect(
        viewSource,
        contains('func attachSharedSession(_ sharedSession: ARKitSession)'),
      );
      expect(viewSource, contains('func detachSharedSession()'));
      expect(viewSource, contains('deinit {'));
      expect(viewSource, contains('stopStandaloneSessionIfOwned()'));
      expect(
        viewSource,
        contains(
          'sharedKitSession?.latestFrame ?? currentFrame ?? arSession.currentFrame',
        ),
      );
      expect(viewSource, contains('return Array(shared.nodes.values)'));
      expect(
        combinedSource,
        contains('supports(.smoothedSceneDepth)'),
      );
      expect(combinedSource, contains('supports(.sceneDepth)'));
      expect(
        combinedSource,
        contains('supports(.personSegmentationWithDepth)'),
      );
      expect(
        combinedSource,
        contains('supports(.personSegmentation)'),
      );
    });

    test('macOS reports desktop fallback capabilities', () {
      final source = File(
        'macos/Classes/ArEnginePlugin.swift',
      ).readAsStringSync();

      expect(source, contains('case "getCapabilities"'));
      expect(source, contains('case "getRuntimeDiagnostics"'));
      expect(
        source,
        contains('private static func inactiveRuntimeDiagnostics'),
      );
      expect(source, contains('func runtimeDiagnostics() -> [String: Any]'));
      expect(source, contains('"source": "macos"'));
      expect(source, contains('"backend": "desktop_camera"'));
      expect(source, contains('"sessionActive": running'));
      expect(source, contains('"hasCameraFrame": hasFrame'));
      expect(source, contains('"anchorCount": anchors.count'));
      expect(source, contains('"nodeCount": nodes.count'));
      expect(source, contains('"modelNodeCount": nodes.values.filter'));
      expect(source, contains('case "sampleDepth"'));
      expect(source, contains('case "encodeRecording"'));
      expect(source, contains('case "hostCloudAnchor", "resolveCloudAnchor"'));
      expect(source, contains('"supportsWorldTracking": true'));
      expect(source, contains('"supportsSceneDepth": false'));
      expect(source, contains('"supportsGeospatial": false'));
      expect(source, contains('"supportsSnapshotCapture": true'));
      expect(source, contains('"supportsRecordingEncode": true'));
      expect(source, contains('private var latestPixelBuffer: CVPixelBuffer?'));
      expect(source, contains('CMSampleBufferGetImageBuffer(sampleBuffer)'));
      expect(source, contains('CIImage(cvPixelBuffer: pixelBuffer)'));
      expect(source, contains('NSBitmapImageRep(cgImage: cgImage)'));
      expect(source, contains('FlutterStandardTypedData(bytes: jpeg)'));
      expect(
        source,
        contains('try desktopSession?.encodeRecording(args: args)'),
      );
      expect(source, contains('AVAssetWriter(outputURL: outputURL'));
      expect(source, contains('AVAssetWriterInputPixelBufferAdaptor'));
      expect(source, contains('AVVideoCodecType.h264'));
      expect(source, contains('CGImageSourceCreateWithData'));
      expect(source, contains('"filePath": outputURL.path'));
      expect(source, contains('kCVPixelBufferPixelFormatTypeKey as String'));
      expect(source, contains('guard frameTimer == nil else { return }'));
    });
  });
}
