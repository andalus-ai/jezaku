package com.arengine.ar_engine

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaMuxer
import android.opengl.GLES30
import android.opengl.GLSurfaceView
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.PixelCopy
import android.view.SurfaceHolder
import android.view.View
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.google.ar.core.*
import com.google.ar.core.exceptions.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterAssets
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import java.io.ByteArrayOutputStream
import kotlin.math.cos
import kotlin.math.sin
import java.io.File
import java.nio.ByteOrder
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

// ─── Plugin entry point ───────────────────────────────────────────────────────

private const val TAG = "ArEnginePlugin"
private const val AR_RUNTIME_PERMISSION_REQUEST_CODE = 7302

class ArEnginePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var binding: FlutterPlugin.FlutterPluginBinding? = null
    private var flutterAssets: FlutterAssets? = null

    // Event channels
    private lateinit var cameraEventChannel: EventChannel
    private lateinit var planeEventChannel: EventChannel
    private lateinit var anchorEventChannel: EventChannel
    private lateinit var lightEventChannel: EventChannel

    private var arSession: ArCoreSession? = null
    @Volatile private var activePlatformView: ARPlatformView? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(flutterBinding: FlutterPlugin.FlutterPluginBinding) {
        binding = flutterBinding
        context = flutterBinding.applicationContext
        flutterAssets = flutterBinding.flutterAssets

        channel = MethodChannel(flutterBinding.binaryMessenger, "com.arengine/ar_engine")
        channel.setMethodCallHandler(this)

        cameraEventChannel = EventChannel(flutterBinding.binaryMessenger, "com.arengine/camera_stream")
        planeEventChannel  = EventChannel(flutterBinding.binaryMessenger, "com.arengine/plane_stream")
        anchorEventChannel = EventChannel(flutterBinding.binaryMessenger, "com.arengine/anchor_stream")
        lightEventChannel  = EventChannel(flutterBinding.binaryMessenger, "com.arengine/light_stream")

        // Register the platform view factory
        flutterBinding.platformViewRegistry.registerViewFactory(
            "com.arengine/ar_view",
            ARViewFactory(
                messenger = flutterBinding.binaryMessenger,
                sessionProvider = { arSession },
                onViewCreated = { activePlatformView = it },
                onViewReady = {
                    arSession?.requestStart()
                    activePlatformView?.resumeSessionWhenReady()
                },
                onViewDisposed = { view ->
                    if (activePlatformView === view) {
                        activePlatformView = null
                    }
                },
            )
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        activePlatformView?.pauseRendering()
        arSession?.close()
        arSession = null
        flutterAssets = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isARSupported"      -> handleIsARSupported(result)
            "getCapabilities"    -> handleGetCapabilities(result)
            "getRuntimeDiagnostics" -> handleRuntimeDiagnostics(result)
            "initSession"        -> handleInitSession(call, result)
            "reconfigureSession" -> handleReconfigureSession(call, result)
            "pauseSession"       -> {
                activePlatformView?.pauseRendering()
                arSession?.pause()
                result.success(null)
            }
            "resumeSession"      -> {
                val coreSession = arSession
                    ?: return result.error(
                        "SESSION_NOT_INITIALISED",
                        "AR session is not initialised",
                        null,
                    )
                if (context.checkSelfPermission(android.Manifest.permission.CAMERA) !=
                    PackageManager.PERMISSION_GRANTED
                ) {
                    activePlatformView?.pauseRendering()
                    coreSession.pause()
                    return result.error(
                        "CAMERA_PERMISSION_DENIED",
                        "Camera permission was revoked while the AR session was active",
                        null,
                    )
                }
                try {
                    // Resume synchronously so ARCore failures reach Flutter. The
                    // renderer's startIfRequested() path is best-effort and logs
                    // failures; it must not be used for this method-channel call.
                    coreSession.resume()
                    activePlatformView?.resumeRendering()
                    activePlatformView?.resumeSessionWhenReady()
                    result.success(null)
                } catch (e: SecurityException) {
                    coreSession.pause()
                    result.error(
                        "CAMERA_PERMISSION_DENIED",
                        "Camera permission is no longer available: ${e.message}",
                        null,
                    )
                } catch (e: Exception) {
                    coreSession.pause()
                    result.error(
                        "RESUME_FAILED",
                        "ARCore session resume failed: ${e.message}",
                        null,
                    )
                }
            }
            "destroySession"     -> {
                activePlatformView?.pauseRendering()
                arSession?.softDestroy()
                result.success(null)
            }
            "captureSnapshot"    -> handleCaptureSnapshot(result)
            "encodeRecording"    -> handleEncodeRecording(call, result)
            "sampleDepth"        -> handleSampleDepth(call, result)
            "hitTest"            -> handleHitTest(call, result)
            "addAnchor"          -> handleAddAnchor(call, result)
            "addAnchorAtPose"    -> handleAddAnchorAtPose(call, result)
            "addGeospatialAnchor"-> handleAddGeospatialAnchor(call, result)
            "checkVpsAvailability" -> handleCheckVpsAvailability(call, result)
            "getGeospatialStatus"  -> handleGetGeospatialStatus(result)
            "hostCloudAnchor"    -> handleHostCloudAnchor(call, result)
            "resolveCloudAnchor" -> handleResolveCloudAnchor(call, result)
            "removeAnchor"       -> handleRemoveAnchor(call, result)
            "addNode"            -> handleAddNode(call, result)
            "updateNode"         -> handleUpdateNode(call, result)
            "removeNode"         -> handleRemoveNode(call, result)
            "getDesktopTextureId"-> result.success(null)   // Android uses PlatformView, not texture
            else                 -> result.notImplemented()
        }
    }

    private fun handleEncodeRecording(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *> ?: return result.success(null)
        try {
            result.success(encodeRecording(args))
        } catch (e: Exception) {
            result.error("RECORDING_ENCODE_FAILED", e.message, null)
        }
    }

    private fun handleReconfigureSession(call: MethodCall, result: Result) {
        val coreSession = arSession ?: return result.success(null)
        val args = call.arguments as? Map<*, *>
        try {
            synchronized(coreSession.sessionLock) {
                val s = coreSession.session ?: return result.success(null)
                s.configure(ArCoreSession.buildConfig(s, args, context, flutterAssets))
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("RECONFIGURE_FAILED", "Session reconfigure failed: ${e.message}", null)
        }
    }

    @Suppress("DEPRECATION")
    private fun encodeRecording(args: Map<*, *>): Map<String, Any?>? {
        val frames = args["frames"] as? List<*> ?: return null
        if (frames.isEmpty()) return null
        val firstBytes = frames.firstOrNull()?.asByteArray() ?: return null
        val firstBitmap =
            BitmapFactory.decodeByteArray(firstBytes, 0, firstBytes.size) ?: return null

        val config = args["config"] as? Map<*, *> ?: emptyMap<Any, Any>()
        val fps = intArg(config, "fps", 30).coerceIn(1, 60)
        val width = evenDimension(
            intArg(config, "width", 0).takeIf { it > 0 } ?: firstBitmap.width
        )
        val height = evenDimension(
            intArg(config, "height", 0).takeIf { it > 0 } ?: firstBitmap.height
        )
        val bitrate = intArg(config, "videoBitrateKbps", 4000).coerceAtLeast(1) * 1000
        val outputFile = File(context.cacheDir, "ar_recording_${System.currentTimeMillis()}.mp4")
        if (outputFile.exists()) outputFile.delete()

        val mime = MediaFormat.MIMETYPE_VIDEO_AVC
        val colorFormat = selectAvcColorFormat()
        val planar = colorFormat == MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar
        val format = MediaFormat.createVideoFormat(mime, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, colorFormat)
            setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

        val encoder = MediaCodec.createEncoderByType(mime)
        var muxer: MediaMuxer? = null
        var muxerStarted = false
        var trackIndex = -1
        val bufferInfo = MediaCodec.BufferInfo()
        var encodedFrameCount = 0

        fun drainEncoder(endOfStream: Boolean) {
            while (true) {
                val outputIndex = encoder.dequeueOutputBuffer(bufferInfo, 10_000)
                when {
                    outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        if (!endOfStream) return
                    }
                    outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val outputFormat = encoder.outputFormat
                        trackIndex = muxer!!.addTrack(outputFormat)
                        muxer!!.start()
                        muxerStarted = true
                    }
                    outputIndex >= 0 -> {
                        val encodedData = encoder.getOutputBuffer(outputIndex)
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                            bufferInfo.size = 0
                        }
                        if (bufferInfo.size > 0 && encodedData != null) {
                            if (!muxerStarted) {
                                throw IllegalStateException("MediaMuxer has not started")
                            }
                            encodedData.position(bufferInfo.offset)
                            encodedData.limit(bufferInfo.offset + bufferInfo.size)
                            muxer!!.writeSampleData(trackIndex, encodedData, bufferInfo)
                        }
                        encoder.releaseOutputBuffer(outputIndex, false)
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            return
                        }
                    }
                }
            }
        }

        try {
            encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            encoder.start()

            for (frame in frames) {
                val bytes = frame.asByteArray() ?: continue
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: continue
                val inputIndex = encoder.dequeueInputBuffer(10_000)
                if (inputIndex < 0) {
                    bitmap.recycle()
                    drainEncoder(false)
                    continue
                }
                val inputBuffer = encoder.getInputBuffer(inputIndex) ?: run {
                    bitmap.recycle()
                    continue
                }
                val yuv = bitmap.toYuv420(width, height, planar)
                bitmap.recycle()
                inputBuffer.clear()
                inputBuffer.put(yuv)
                val presentationUs = encodedFrameCount * 1_000_000L / fps
                encoder.queueInputBuffer(inputIndex, 0, yuv.size, presentationUs, 0)
                encodedFrameCount += 1
                drainEncoder(false)
            }

            if (encodedFrameCount == 0) {
                return null
            }

            val eosIndex = encoder.dequeueInputBuffer(10_000)
            if (eosIndex >= 0) {
                val presentationUs = encodedFrameCount * 1_000_000L / fps
                encoder.queueInputBuffer(
                    eosIndex,
                    0,
                    0,
                    presentationUs,
                    MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                )
            }
            drainEncoder(true)
        } finally {
            firstBitmap.recycle()
            try { encoder.stop() } catch (_: Exception) {}
            encoder.release()
            try {
                if (muxerStarted) muxer?.stop()
            } catch (_: Exception) {}
            muxer?.release()
        }

        val durationMillis = intArg(
            args,
            "durationMillis",
            encodedFrameCount * 1000 / fps,
        )
        return mapOf(
            "filePath" to outputFile.absolutePath,
            "durationMillis" to durationMillis,
            "frameCount" to encodedFrameCount,
            "fileSizeBytes" to outputFile.length(),
        )
    }

    private fun Any?.asByteArray(): ByteArray? = when (this) {
        is ByteArray -> this
        is java.nio.ByteBuffer -> {
            val duplicate = duplicate()
            val bytes = ByteArray(duplicate.remaining())
            duplicate.get(bytes)
            bytes
        }
        else -> null
    }

    private fun intArg(map: Map<*, *>, key: String, defaultValue: Int): Int =
        (map[key] as? Number)?.toInt() ?: defaultValue

    private fun evenDimension(value: Int): Int {
        val safe = value.coerceAtLeast(2)
        return if (safe % 2 == 0) safe else safe + 1
    }

    @Suppress("DEPRECATION")
    private fun selectAvcColorFormat(): Int {
        val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
        val codecInfo = codecList.codecInfos.firstOrNull { info ->
            info.isEncoder &&
                info.supportedTypes.any { it.equals(MediaFormat.MIMETYPE_VIDEO_AVC, true) }
        } ?: return MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
        val capabilities = codecInfo.getCapabilitiesForType(MediaFormat.MIMETYPE_VIDEO_AVC)
        val preferred = listOf(
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar,
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar,
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible,
        )
        return preferred.firstOrNull { it in capabilities.colorFormats }
            ?: MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
    }

    private fun Bitmap.toYuv420(width: Int, height: Int, planar: Boolean): ByteArray {
        val scaled = if (this.width == width && this.height == height) {
            this
        } else {
            Bitmap.createScaledBitmap(this, width, height, true)
        }
        val pixels = IntArray(width * height)
        scaled.getPixels(pixels, 0, width, 0, 0, width, height)
        if (scaled !== this) scaled.recycle()

        val frameSize = width * height
        val yuv = ByteArray(frameSize * 3 / 2)
        var yIndex = 0
        var uvIndex = frameSize
        var uIndex = frameSize
        var vIndex = frameSize + frameSize / 4

        for (j in 0 until height) {
            for (i in 0 until width) {
                val pixel = pixels[j * width + i]
                val r = pixel shr 16 and 0xff
                val g = pixel shr 8 and 0xff
                val b = pixel and 0xff
                val y = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128

                yuv[yIndex++] = y.clampToByte()
                if (j % 2 == 0 && i % 2 == 0) {
                    if (planar) {
                        yuv[uIndex++] = u.clampToByte()
                        yuv[vIndex++] = v.clampToByte()
                    } else {
                        yuv[uvIndex++] = u.clampToByte()
                        yuv[uvIndex++] = v.clampToByte()
                    }
                }
            }
        }
        return yuv
    }

    private fun Int.clampToByte(): Byte = coerceIn(0, 255).toByte()

    private fun handleCaptureSnapshot(result: Result) {
        val view = activePlatformView ?: return result.success(null)
        view.captureSnapshot(mainHandler, result)
    }

    private fun handleSampleDepth(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *> ?: return result.success(null)
        val x = (args["x"] as? Number)?.toFloat() ?: return result.success(null)
        val y = (args["y"] as? Number)?.toFloat() ?: return result.success(null)
        result.success(arSession?.sampleDepth(x, y))
    }

    private fun handleAddAnchorAtPose(call: MethodCall, result: Result) {
        val poseMap = call.arguments as? Map<*, *> ?: return result.error("INVALID_ARGS", null, null)
        try {
            val anchor = arSession?.addAnchorAtPose(poseMap)
            result.success(anchor)
        } catch (e: Exception) {
            result.error("ANCHOR_FAILED", e.message, null)
        }
    }

    private fun handleAddGeospatialAnchor(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *> ?: return result.error("INVALID_ARGS", null, null)
        try {
            result.success(arSession?.addGeospatialAnchor(args))
        } catch (e: UnsupportedOperationException) {
            result.error("UNSUPPORTED_GEOSPATIAL", e.message, null)
        } catch (e: Exception) {
            result.error("GEOSPATIAL_ANCHOR_FAILED", e.message, null)
        }
    }

    private fun handleCheckVpsAvailability(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *> ?: return result.error("INVALID_ARGS", null, null)
        val latitude = (args["latitude"] as? Number)?.toDouble()
        val longitude = (args["longitude"] as? Number)?.toDouble()
        if (latitude == null || longitude == null) {
            return result.error("INVALID_ARGS", "latitude and longitude required", null)
        }
        try {
            arSession?.checkVpsAvailability(latitude, longitude, result)
                ?: result.error("SESSION_NOT_INITIALISED", "Session not initialised", null)
        } catch (e: UnsupportedOperationException) {
            result.error("UNSUPPORTED_GEOSPATIAL", e.message, null)
        } catch (e: Exception) {
            result.error("VPS_CHECK_FAILED", e.message, null)
        }
    }

    private fun handleGetGeospatialStatus(result: Result) {
        try {
            val status = arSession?.geospatialStatus()
                ?: return result.error("SESSION_NOT_INITIALISED", "Session not initialised", null)
            result.success(status)
        } catch (e: UnsupportedOperationException) {
            result.error("UNSUPPORTED_GEOSPATIAL", e.message, null)
        } catch (e: Exception) {
            result.error("GEOSPATIAL_STATUS_FAILED", e.message, null)
        }
    }

    private fun handleHostCloudAnchor(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *> ?: return result.error("INVALID_ARGS", null, null)
        val anchorId = args["anchorId"] as? String
            ?: return result.error("INVALID_ARGS", "anchorId required", null)
        val ttlDays = (args["ttlDays"] as? Number)?.toInt() ?: 30
        try {
            arSession?.hostCloudAnchor(anchorId, ttlDays, result)
                ?: result.error("SESSION_NOT_INITIALISED", "Session not initialised", null)
        } catch (e: UnsupportedOperationException) {
            result.error("UNSUPPORTED_CLOUD_ANCHORS", e.message, null)
        } catch (e: Exception) {
            result.error("CLOUD_ANCHOR_FAILED", e.message, null)
        }
    }

    private fun handleResolveCloudAnchor(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *> ?: return result.error("INVALID_ARGS", null, null)
        val cloudId = args["cloudId"] as? String
            ?: return result.error("INVALID_ARGS", "cloudId required", null)
        try {
            arSession?.resolveCloudAnchor(cloudId, result)
                ?: result.error("SESSION_NOT_INITIALISED", "Session not initialised", null)
        } catch (e: UnsupportedOperationException) {
            result.error("UNSUPPORTED_CLOUD_ANCHORS", e.message, null)
        } catch (e: Exception) {
            result.error("CLOUD_ANCHOR_FAILED", e.message, null)
        }
    }


    private fun handleIsARSupported(result: Result) {
        val availability = ArCoreApk.getInstance().checkAvailability(context)
        result.success(
            availability == ArCoreApk.Availability.SUPPORTED_INSTALLED ||
            availability == ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD ||
            availability == ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED
        )
    }

    private fun handleGetCapabilities(result: Result) {
        val availability = ArCoreApk.getInstance().checkAvailability(context)
        val arSupported =
            availability == ArCoreApk.Availability.SUPPORTED_INSTALLED ||
            availability == ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD ||
            availability == ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED

        var temporarySession: Session? = null
        val capabilitySession = arSession?.session ?: try {
            temporarySession = Session(context)
            temporarySession
        } catch (_: Exception) {
            null
        }

        val sceneDepthSupported =
            capabilitySession?.isDepthModeSupported(Config.DepthMode.AUTOMATIC) ?: false
        val geospatialSupported =
            capabilitySession?.isGeospatialModeSupported(Config.GeospatialMode.ENABLED) ?: false
        temporarySession?.close()

        result.success(mapOf(
            "isARSupported" to arSupported,
            "supportsWorldTracking" to arSupported,
            "supportsPlaneDetection" to arSupported,
            "supportsHitTesting" to arSupported,
            "supportsImageTracking" to arSupported,
            "supportsLightEstimation" to arSupported,
            "supportsSceneDepth" to sceneDepthSupported,
            "supportsHumanOcclusion" to false,
            "supportsBodyTracking" to false,
            "supportsGeospatial" to geospatialSupported,
            "supportsCloudAnchors" to arSupported,
            "supportsSnapshotCapture" to arSupported,
            "supportsRecordingEncode" to arSupported,
        ))
    }

    private fun handleRuntimeDiagnostics(result: Result) {
        result.success(
            arSession?.runtimeDiagnostics() ?: mapOf(
                "source" to "android",
                "backend" to "arcore",
                "sessionActive" to false,
                "sessionRunning" to false,
                "hasNativeSession" to false,
                "hasCameraFrame" to false,
                "anchorCount" to 0,
                "trackedAnchorCount" to 0,
                "nodeCount" to 0,
                "modelNodeCount" to 0,
                "planeCount" to 0,
                "trackedPlaneCount" to 0,
                "depthEnabled" to false,
                "cloudAnchorsEnabled" to false,
                "geospatialEnabled" to false,
            )
        )
    }

    private fun handleInitSession(call: MethodCall, result: Result) {
        val act = activity ?: return result.error("NO_ACTIVITY", "Activity not attached", null)
        val args = (call.arguments as? Map<*, *>)?.toMutableMap()
        val wantsGeospatial = args?.get("geospatialEnabled") == true
        if (context.checkSelfPermission(android.Manifest.permission.CAMERA) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestMissingRuntimePermissions(includeLocation = wantsGeospatial)
            Log.w(TAG, "initSession blocked: camera permission is not granted")
            return result.error(
                "CAMERA_PERMISSION_DENIED",
                "Camera permission is not granted",
                null
            )
        }
        try {
            if (args?.get("geospatialEnabled") == true && !hasLocationPermission()) {
                requestMissingRuntimePermissions(includeLocation = true)
                args["geospatialEnabled"] = false
                Log.i(TAG, "initSession: geospatial disabled because location permission is not granted")
            }
            Log.i(TAG, "initSession: starting ARCore session")
            ArCoreApk.getInstance().requestInstall(act, true)
            val session = arSession ?: ArCoreSession(context, act, flutterAssets)
            session.configure(args)
            session.setEventChannels(cameraEventChannel, planeEventChannel, anchorEventChannel, lightEventChannel)
            arSession = session
            session.requestStart()
            activePlatformView?.resumeRendering()
            activePlatformView?.resumeSessionWhenReady()
            Log.i(TAG, "initSession: ARCore session start requested")
            result.success(null)
        } catch (e: UnavailableUserDeclinedInstallationException) {
            Log.w(TAG, "initSession failed: user declined ARCore install", e)
            result.error("USER_DECLINED", "User declined ARCore install", e.message)
        } catch (e: UnavailableDeviceNotCompatibleException) {
            Log.w(TAG, "initSession failed: device is not ARCore compatible", e)
            result.error("NOT_SUPPORTED", "Device not compatible with ARCore", e.message)
        } catch (e: Exception) {
            Log.e(TAG, "initSession failed", e)
            result.error("INIT_FAILED", "Session init failed: ${e.message}", null)
        }
    }

    private fun requestMissingRuntimePermissions(includeLocation: Boolean) {
        val act = activity ?: return
        val permissions = mutableListOf<String>()
        if (context.checkSelfPermission(android.Manifest.permission.CAMERA) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            permissions.add(android.Manifest.permission.CAMERA)
        }
        if (includeLocation && !hasLocationPermission()) {
            permissions.add(android.Manifest.permission.ACCESS_FINE_LOCATION)
            permissions.add(android.Manifest.permission.ACCESS_COARSE_LOCATION)
        }
        if (permissions.isNotEmpty()) {
            Log.i(TAG, "Requesting runtime permissions: ${permissions.joinToString()}")
            act.requestPermissions(
                permissions.toTypedArray(),
                AR_RUNTIME_PERMISSION_REQUEST_CODE
            )
        }
    }

    private fun hasLocationPermission(): Boolean {
        val fine = context.checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        val coarse = context.checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    private fun handleHitTest(call: MethodCall, result: Result) {
        val args = call.arguments as Map<*, *>
        val x = (args["x"] as Number).toFloat()
        val y = (args["y"] as Number).toFloat()
        val hits = arSession?.hitTest(x, y) ?: emptyList<Map<String,Any>>()
        result.success(hits)
    }

    private fun handleAddAnchor(call: MethodCall, result: Result) {
        val hitMap = call.arguments as Map<*, *>
        try {
            val anchor = arSession?.addAnchorFromHit(hitMap)
            result.success(anchor)
        } catch (e: Exception) {
            result.error("ANCHOR_FAILED", e.message, null)
        }
    }

    private fun handleRemoveAnchor(call: MethodCall, result: Result) {
        val anchorId = call.arguments as String
        arSession?.removeAnchor(anchorId)
        result.success(null)
    }

    private fun handleAddNode(call: MethodCall, result: Result) {
        val args = call.arguments as Map<*, *>
        val nodeId = arSession?.addNode(args) ?: UUID.randomUUID().toString()
        result.success(nodeId)
    }

    private fun handleUpdateNode(call: MethodCall, result: Result) {
        val args = call.arguments as Map<*, *>
        arSession?.updateNode(args)
        result.success(null)
    }

    private fun handleRemoveNode(call: MethodCall, result: Result) {
        val nodeId = call.arguments as String
        arSession?.removeNode(nodeId)
        result.success(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
}

// ─── ARCore session wrapper ───────────────────────────────────────────────────

class ArCoreSession(
    private val context: Context,
    private val activity: Activity,
    private val flutterAssets: FlutterAssets?,
) {

    internal var session: Session? = null   // internal: GL renderer calls session.update()
    internal val sessionLock = Any()
    @Volatile internal var startRequested = false
    @Volatile internal var isRunning = false
    internal val anchors = ConcurrentHashMap<String, Anchor>()
    internal val anchorMetadata = ConcurrentHashMap<String, Map<String, Any?>>()
    internal val nodes   = ConcurrentHashMap<String, Map<*, *>>()
    @Volatile internal var viewportWidth = 1
    @Volatile internal var viewportHeight = 1

    @Volatile private var cameraEventSink: EventChannel.EventSink? = null
    @Volatile private var planeEventSink:  EventChannel.EventSink? = null
    @Volatile private var anchorEventSink: EventChannel.EventSink? = null
    @Volatile private var lightEventSink:  EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun configure(args: Map<*, *>?) {
        synchronized(sessionLock) {
            isRunning = false
            startRequested = false
            val s = session ?: Session(context).also { session = it }
            try {
                s.pause()
            } catch (_: Exception) {
                // Safe when the session has not been resumed yet.
            }
            clearSceneLocked()
            s.configure(buildConfig(s, args, context, flutterAssets))
        }
    }

    fun setViewportSize(width: Int, height: Int) {
        viewportWidth = width.coerceAtLeast(1)
        viewportHeight = height.coerceAtLeast(1)
    }

    companion object {
        fun buildConfig(session: Session, args: Map<*, *>?): Config {
            return buildConfig(session, args, null, null)
        }

        fun buildConfig(
            session: Session,
            args: Map<*, *>?,
            context: Context?,
            flutterAssets: FlutterAssets?,
        ): Config {
            val horizontalPlanes = boolArg(args, "detectHorizontalPlanes", true)
            val verticalPlanes = boolArg(args, "detectVerticalPlanes", false)
            val lightingEnabled = boolArg(args, "lightingEstimationEnabled", true)
            val cloudAnchorsEnabled = boolArg(args, "cloudAnchorsEnabled", false)
            val depthEnabled = boolArg(args, "depthEnabled", false)
            val allowExperimentalDepth = boolArg(args, "allowExperimentalDepth", false)
            val geospatialEnabled = boolArg(args, "geospatialEnabled", false)
            val bodyTrackingEnabled = boolArg(args, "bodyTrackingEnabled", false)
            if (bodyTrackingEnabled) {
                // ARCore Session Config has no native body skeleton tracking;
                // an ML Kit/MediaPipe bridge must supply skeleton anchors.
            }

            return Config(session).apply {
                buildAugmentedImageDatabase(session, args, context, flutterAssets)?.let {
                    augmentedImageDatabase = it
                }
                planeFindingMode = when {
                    horizontalPlanes && verticalPlanes ->
                        Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                    horizontalPlanes -> Config.PlaneFindingMode.HORIZONTAL
                    verticalPlanes -> Config.PlaneFindingMode.VERTICAL
                    else -> Config.PlaneFindingMode.DISABLED
                }
                lightEstimationMode = if (lightingEnabled) {
                    Config.LightEstimationMode.ENVIRONMENTAL_HDR
                } else {
                    Config.LightEstimationMode.DISABLED
                }
                cloudAnchorMode = if (cloudAnchorsEnabled) {
                    Config.CloudAnchorMode.ENABLED
                } else {
                    Config.CloudAnchorMode.DISABLED
                }
                depthMode =
                    if (depthEnabled &&
                        allowExperimentalDepth &&
                        session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)
                    ) {
                        Config.DepthMode.AUTOMATIC
                    } else {
                        Config.DepthMode.DISABLED
                    }
                geospatialMode =
                    if (geospatialEnabled &&
                        session.isGeospatialModeSupported(Config.GeospatialMode.ENABLED)
                    ) {
                        Config.GeospatialMode.ENABLED
                    } else {
                        Config.GeospatialMode.DISABLED
                    }
                updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
            }
        }

        private fun buildAugmentedImageDatabase(
            session: Session,
            args: Map<*, *>?,
            context: Context?,
            flutterAssets: FlutterAssets?,
        ): AugmentedImageDatabase? {
            val targets = args?.get("imageTargets") as? List<*> ?: return null
            if (targets.isEmpty() || context == null) return null

            val database = AugmentedImageDatabase(session)
            var added = false
            for (target in targets) {
                val map = target as? Map<*, *> ?: continue
                val name = map["name"] as? String ?: continue
                val assetPath = map["assetPath"] as? String ?: continue
                val physicalWidth = (map["physicalWidthMeters"] as? Number)?.toFloat()
                    ?: continue
                if (physicalWidth <= 0f) continue

                val assetKey = flutterAssets?.getAssetFilePathByName(assetPath) ?: assetPath
                context.assets.open(assetKey).use { input ->
                    val bitmap = BitmapFactory.decodeStream(input)
                        ?: throw IllegalArgumentException("Unable to decode image target asset: $assetPath")
                    database.addImage(name, bitmap, physicalWidth)
                    added = true
                }
            }
            return if (added) database else null
        }

        private fun boolArg(args: Map<*, *>?, key: String, defaultValue: Boolean): Boolean =
            args?.get(key) as? Boolean ?: defaultValue
    }

    fun setEventChannels(
        cam: EventChannel, plane: EventChannel,
        anchor: EventChannel, light: EventChannel
    ) {
        cam.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) { cameraEventSink = sink }
            override fun onCancel(args: Any?) { cameraEventSink = null }
        })
        plane.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) { planeEventSink = sink }
            override fun onCancel(args: Any?) { planeEventSink = null }
        })
        anchor.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) { anchorEventSink = sink }
            override fun onCancel(args: Any?) { anchorEventSink = null }
        })
        light.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) { lightEventSink = sink }
            override fun onCancel(args: Any?) { lightEventSink = null }
        })
    }

    private fun emitEvent(
        sinkProvider: () -> EventChannel.EventSink?,
        event: Any?,
    ) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            sinkProvider()?.success(event)
            return
        }
        mainHandler.post {
            sinkProvider()?.success(event)
        }
    }

    fun start() {
        requestStart()
        startIfRequested()
    }

    fun requestStart() {
        synchronized(sessionLock) {
            startRequested = true
        }
    }

    fun startIfRequested() {
        synchronized(sessionLock) {
            if (!startRequested) {
                isRunning = false
                return
            }
            val s = session
            if (s == null) {
                isRunning = false
                return
            }
            try {
                s.resume()
                isRunning = true
            } catch (e: Exception) {
                isRunning = false
                Log.w(TAG, "ARCore session resume failed", e)
            }
        }
    }

    fun pause() {
        synchronized(sessionLock) {
            startRequested = false
            isRunning = false
            latestFrame = null
            try {
                session?.pause()
            } catch (e: Exception) {
                Log.w(TAG, "ARCore session pause failed", e)
            }
        }
    }

    fun resume() {
        synchronized(sessionLock) {
            val currentSession = session
                ?: throw IllegalStateException("Session not initialised")
            startRequested = true
            try {
                currentSession.resume()
                isRunning = true
            } catch (e: Exception) {
                startRequested = false
                isRunning = false
                throw e
            }
        }
    }

    fun softDestroy() {
        synchronized(sessionLock) {
            startRequested = false
            isRunning = false
            latestFrame = null
            try {
                session?.pause()
            } catch (e: Exception) {
                Log.w(TAG, "ARCore session soft pause failed", e)
            }
            clearSceneLocked()
        }
    }

    fun close() {
        synchronized(sessionLock) {
            startRequested = false
            isRunning = false
            latestFrame = null
            try {
                session?.pause()
            } catch (e: Exception) {
                Log.w(TAG, "ARCore session pause before close failed", e)
            }
            clearSceneLocked()
            try {
                session?.close()
            } catch (e: Exception) {
                Log.w(TAG, "ARCore session close failed", e)
            } finally {
                session = null
            }
        }
    }

    fun runtimeDiagnostics(): Map<String, Any?> {
        return synchronized(sessionLock) {
            val s = session
            val planes = try {
                s?.getAllTrackables(Plane::class.java)?.toList() ?: emptyList()
            } catch (_: Exception) {
                emptyList<Plane>()
            }
            val config = try {
                s?.config
            } catch (_: Exception) {
                null
            }
            mapOf(
                "source" to "android",
                "backend" to "arcore",
                "sessionActive" to (s != null && isRunning),
                "sessionRunning" to isRunning,
                "startRequested" to startRequested,
                "hasNativeSession" to (s != null),
                "hasCameraFrame" to (latestFrame != null),
                "anchorCount" to anchors.size,
                "trackedAnchorCount" to anchors.values.count {
                    it.trackingState == TrackingState.TRACKING
                },
                "nodeCount" to nodes.size,
                "modelNodeCount" to nodes.values.count { isModelNodeMap(it) },
                "planeCount" to planes.size,
                "trackedPlaneCount" to planes.count {
                    it.trackingState == TrackingState.TRACKING
                },
                "viewportWidth" to viewportWidth,
                "viewportHeight" to viewportHeight,
                "depthEnabled" to (config?.depthMode == Config.DepthMode.AUTOMATIC),
                "cloudAnchorsEnabled" to
                    (config?.cloudAnchorMode == Config.CloudAnchorMode.ENABLED),
                "geospatialEnabled" to
                    (config?.geospatialMode == Config.GeospatialMode.ENABLED),
            )
        }
    }

    private fun clearSceneLocked() {
        for ((_, anchor) in anchors) {
            try {
                anchor.detach()
            } catch (_: Exception) {
            }
        }
        anchors.clear()
        anchorMetadata.clear()
        nodes.clear()
    }

    /** Called from GL thread each frame. */
    fun onFrame(frame: Frame) {
        latestFrame = frame
        val camera = frame.camera
        val projectionMatrix = FloatArray(16)
        camera.getProjectionMatrix(projectionMatrix, 0, 0.01f, 100f)

        // Camera update
        emitEvent({ cameraEventSink }, mapOf(
            "pose"             to camera.pose.toMap(),
            "projectionMatrix" to projectionMatrix.toList(),
            "viewMatrix"       to camera.viewMatrix.toList(),
            "trackingState"    to camera.trackingState.toEventName(),
            "intrinsics"       to camera.imageIntrinsics.run {
                listOf(focalLength[0], focalLength[1], principalPoint[0], principalPoint[1])
            },
            "imageResolution"  to camera.imageIntrinsics.imageDimensions.toList(),
        ))

        // Plane updates
        val planeList = session?.getAllTrackables(Plane::class.java)?.map { it.toMap() } ?: emptyList<Map<String,Any>>()
        if (planeList.isNotEmpty()) emitEvent({ planeEventSink }, planeList)

        // Light estimation
        frame.lightEstimate?.let { le ->
            emitEvent({ lightEventSink }, le.pixelIntensity.toDouble() * 1000.0)
        }

        // Anchor tracking state changes
        for ((id, anchor) in anchors) {
            val update = mutableMapOf<String, Any?>(
                "id"            to id,
                "pose"          to anchor.pose.toMap(),
                "trackingState" to anchor.trackingState.toEventName(),
            )
            anchorMetadata[id]?.let { update["metadata"] = it }
            emitEvent({ anchorEventSink }, update)
        }

        session?.getAllTrackables(AugmentedImage::class.java)?.forEach { image ->
            emitEvent({ anchorEventSink }, image.toAnchorMap())
        }
    }

    @Volatile internal var latestFrame: Frame? = null

    fun sampleDepth(normX: Float, normY: Float): Double? {
        val s = session ?: return null
        val frame = latestFrame ?: return null
        if (s.config.depthMode == Config.DepthMode.DISABLED) return null
        if (normX.isNaN() || normY.isNaN() ||
            normX < 0f || normX > 1f || normY < 0f || normY > 1f
        ) {
            return null
        }

        return try {
            val image = frame.acquireDepthImage16Bits()
            try {
                val plane = image.planes[0]
                val x = (normX * (image.width - 1)).toInt().coerceIn(0, image.width - 1)
                val y = (normY * (image.height - 1)).toInt().coerceIn(0, image.height - 1)
                val index = y * plane.rowStride + x * plane.pixelStride
                val buffer = plane.buffer.order(ByteOrder.LITTLE_ENDIAN)
                if (index + 1 >= buffer.capacity()) return null
                val depthMm = buffer.getShort(index).toInt() and 0xFFFF
                if (depthMm <= 0) null else depthMm / 1000.0
            } finally {
                image.close()
            }
        } catch (_: NotYetAvailableException) {
            null
        } catch (_: Exception) {
            null
        }
    }

    fun hitTest(normX: Float, normY: Float): List<Map<String, Any>> {
        val frame = latestFrame ?: return emptyList()
        return hitTestFromFrame(frame, normX, normY)
    }

    fun hitTestFromFrame(frame: Frame, normX: Float, normY: Float): List<Map<String, Any>> {
        val hitX = (normX.coerceIn(0f, 1f) * viewportWidth).coerceAtLeast(0f)
        val hitY = (normY.coerceIn(0f, 1f) * viewportHeight).coerceAtLeast(0f)
        return frame.hitTest(hitX, hitY).map { result ->
            val trackable = result.trackable
            val planeId = if (trackable is Plane) trackable.hashCode().toString() else null
            mapOf(
                "type"      to when (trackable) {
                    is Plane  -> "plane"
                    is Point  -> "featurePoint"
                    else      -> "estimatedHorizontalPlane"
                },
                "worldPose" to result.hitPose.toMap(),
                "distance"  to result.distance.toDouble(),
                "planeId"   to (planeId ?: ""),
                "anchorId"  to "",
            )
        }
    }

    fun addAnchorFromHit(hitMap: Map<*, *>): Map<String, Any> {
        return synchronized(sessionLock) {
            val s = session ?: throw IllegalStateException("Session not initialised")
            val poseMap = hitMap["worldPose"] as Map<*, *>
            val posMap  = poseMap["position"] as Map<*, *>
            val rotMap  = poseMap["rotation"] as Map<*, *>
            val translation = floatArrayOf(
                (posMap["x"] as Number).toFloat(),
                (posMap["y"] as Number).toFloat(),
                (posMap["z"] as Number).toFloat(),
            )
            val rotation = floatArrayOf(
                (rotMap["x"] as Number).toFloat(),
                (rotMap["y"] as Number).toFloat(),
                (rotMap["z"] as Number).toFloat(),
                (rotMap["w"] as Number).toFloat(),
            )
            val pose   = Pose(translation, rotation)
            val anchor = s.createAnchor(pose)
            val id     = UUID.randomUUID().toString()
            anchors[id] = anchor
            mapOf(
                "id"            to id,
                "pose"          to pose.toMap(),
                "trackingState" to anchor.trackingState.toEventName(),
            )
        }
    }

    fun removeAnchor(id: String) {
        synchronized(sessionLock) {
            anchors.remove(id)?.detach()
            anchorMetadata.remove(id)
        }
    }

    fun hostCloudAnchor(anchorId: String, ttlDays: Int, result: Result) {
        val s = session ?: throw IllegalStateException("Session not initialised")
        if (s.config.cloudAnchorMode != Config.CloudAnchorMode.ENABLED) {
            throw UnsupportedOperationException("ARCore Cloud Anchor mode is not enabled")
        }
        val anchor = anchors[anchorId]
            ?: throw IllegalArgumentException("Anchor not found: $anchorId")
        val clampedTtl = ttlDays.coerceIn(1, 365)

        s.hostCloudAnchorAsync(anchor, clampedTtl) { cloudId, state ->
            if (state == Anchor.CloudAnchorState.SUCCESS) {
                result.success(cloudId)
            } else {
                result.error(
                    "CLOUD_ANCHOR_FAILED",
                    "Cloud anchor hosting failed: ${state.name}",
                    state.name,
                )
            }
        }
    }

    fun resolveCloudAnchor(cloudId: String, result: Result) {
        val s = session ?: throw IllegalStateException("Session not initialised")
        if (s.config.cloudAnchorMode != Config.CloudAnchorMode.ENABLED) {
            throw UnsupportedOperationException("ARCore Cloud Anchor mode is not enabled")
        }

        s.resolveCloudAnchorAsync(cloudId) { anchor, state ->
            if (state == Anchor.CloudAnchorState.SUCCESS && anchor != null) {
                val id = UUID.randomUUID().toString()
                anchors[id] = anchor
                anchorMetadata[id] = mapOf(
                    "cloudAnchorId" to cloudId,
                    "nativeCloudAnchor" to true,
                )
                result.success(
                    mapOf(
                        "id" to id,
                        "pose" to anchor.pose.toMap(),
                        "trackingState" to anchor.trackingState.toEventName(),
                        "metadata" to anchorMetadata[id],
                    )
                )
            } else {
                result.error(
                    "CLOUD_ANCHOR_FAILED",
                    "Cloud anchor resolve failed: ${state.name}",
                    state.name,
                )
            }
        }
    }

    fun addAnchorAtPose(poseMap: Map<*, *>): Map<String, Any> {
        return synchronized(sessionLock) {
            val s = session ?: throw IllegalStateException("Session not initialised")
            val posMap = poseMap["position"] as Map<*, *>
            val rotMap = poseMap["rotation"] as Map<*, *>
            val translation = floatArrayOf(
                (posMap["x"] as Number).toFloat(), (posMap["y"] as Number).toFloat(),
                (posMap["z"] as Number).toFloat())
            val rotation = floatArrayOf(
                (rotMap["x"] as Number).toFloat(), (rotMap["y"] as Number).toFloat(),
                (rotMap["z"] as Number).toFloat(), (rotMap["w"] as Number).toFloat())
            val pose   = Pose(translation, rotation)
            val anchor = s.createAnchor(pose)
            val id     = UUID.randomUUID().toString()
            anchors[id] = anchor
            mapOf("id" to id, "pose" to pose.toMap(),
                         "trackingState" to anchor.trackingState.toEventName())
        }
    }

    fun addGeospatialAnchor(args: Map<*, *>): Map<String, Any> {
        return synchronized(sessionLock) {
            val s = session ?: throw IllegalStateException("Session not initialised")
            val anchorArgs = args["anchor"] as? Map<*, *>
                ?: throw IllegalArgumentException("anchor required")

            if (s.config.geospatialMode != Config.GeospatialMode.ENABLED) {
                throw UnsupportedOperationException("ARCore geospatial mode is not enabled")
            }

            val earth = s.earth
                ?: throw UnsupportedOperationException("ARCore Earth is not available")
            if (earth.trackingState != TrackingState.TRACKING) {
                throw UnsupportedOperationException("ARCore Earth is not tracking")
            }

            val latitude = doubleArg(anchorArgs, "latitude")
            val longitude = doubleArg(anchorArgs, "longitude")
            val altitude = doubleArg(anchorArgs, "altitudeMeters")
            val rotation = geospatialRotation(anchorArgs)
            val anchor = earth.createAnchor(
                latitude,
                longitude,
                altitude,
                rotation[0],
                rotation[1],
                rotation[2],
                rotation[3],
            )
            val id = UUID.randomUUID().toString()
            val metadata = geospatialMetadata(anchorArgs)
            anchors[id] = anchor
            anchorMetadata[id] = metadata

            mapOf(
                "id" to id,
                "pose" to anchor.pose.toMap(),
                "trackingState" to anchor.trackingState.toEventName(),
                "metadata" to metadata,
            )
        }
    }

    /**
     * Asks ARCore whether VPS corrections exist at a location. The result is
     * delivered asynchronously on an ARCore thread, so it is posted to the
     * main looper before it reaches Flutter.
     */
    fun checkVpsAvailability(latitude: Double, longitude: Double, result: Result) {
        val s = session ?: throw IllegalStateException("Session not initialised")
        if (s.config.geospatialMode != Config.GeospatialMode.ENABLED) {
            throw UnsupportedOperationException("ARCore geospatial mode is not enabled")
        }
        val mainHandler = Handler(Looper.getMainLooper())
        s.checkVpsAvailabilityAsync(latitude, longitude) { availability ->
            mainHandler.post { result.success(availability.name) }
        }
    }

    /**
     * Snapshot of the Earth service. The pose is only included while Earth is
     * tracking, because ARCore throws when the pose is read otherwise.
     */
    fun geospatialStatus(): Map<String, Any?> {
        return synchronized(sessionLock) {
            val s = session ?: throw IllegalStateException("Session not initialised")
            if (s.config.geospatialMode != Config.GeospatialMode.ENABLED) {
                return@synchronized mapOf(
                    "enabled" to false,
                    "tracking" to false,
                    "earthState" to null,
                    "pose" to null,
                )
            }
            val earth = s.earth
                ?: return@synchronized mapOf(
                    "enabled" to true,
                    "tracking" to false,
                    "earthState" to null,
                    "pose" to null,
                )
            val tracking = earth.trackingState == TrackingState.TRACKING
            val pose = if (tracking) {
                val p = earth.cameraGeospatialPose
                mapOf(
                    "latitude" to p.latitude,
                    "longitude" to p.longitude,
                    "altitudeMeters" to p.altitude,
                    "headingDegrees" to p.heading,
                    "horizontalAccuracyMeters" to p.horizontalAccuracy,
                    "verticalAccuracyMeters" to p.verticalAccuracy,
                    "headingAccuracyDegrees" to p.headingAccuracy,
                )
            } else {
                null
            }
            mapOf(
                "enabled" to true,
                "tracking" to tracking,
                "earthState" to earth.earthState.name,
                "pose" to pose,
            )
        }
    }

    private fun geospatialMetadata(args: Map<*, *>): Map<String, Any?> {
        val metadata = mutableMapOf<String, Any?>()
        (args["metadata"] as? Map<*, *>)?.forEach { (key, value) ->
            if (key is String) metadata[key] = value
        }
        metadata["geospatialAnchorId"] = args["id"] as? String ?: ""
        metadata["latitude"] = doubleArg(args, "latitude")
        metadata["longitude"] = doubleArg(args, "longitude")
        metadata["altitudeMeters"] = doubleArg(args, "altitudeMeters")
        metadata["headingDegrees"] = optionalDoubleArg(args, "headingDegrees")
        metadata["pitchDegrees"] = optionalDoubleArg(args, "pitchDegrees")
        metadata["rollDegrees"] = optionalDoubleArg(args, "rollDegrees")
        metadata["correctionEastMeters"] = optionalDoubleArg(args, "correctionEastMeters")
        metadata["correctionNorthMeters"] = optionalDoubleArg(args, "correctionNorthMeters")
        metadata["correctionUpMeters"] = optionalDoubleArg(args, "correctionUpMeters")
        metadata["nativeGeospatial"] = true
        return metadata
    }

    private fun geospatialRotation(args: Map<*, *>): FloatArray {
        val pitch = Math.toRadians(optionalDoubleArg(args, "pitchDegrees")).toFloat()
        val yaw = Math.toRadians(-optionalDoubleArg(args, "headingDegrees")).toFloat()
        val roll = Math.toRadians(optionalDoubleArg(args, "rollDegrees")).toFloat()
        return normalizeQuaternion(
            multiplyQuaternion(
                multiplyQuaternion(axisQuaternion(0, 1, 0, yaw), axisQuaternion(1, 0, 0, pitch)),
                axisQuaternion(0, 0, -1, roll),
            )
        )
    }

    private fun axisQuaternion(x: Int, y: Int, z: Int, angle: Float): FloatArray {
        val half = angle / 2f
        val s = sin(half)
        return floatArrayOf(x * s, y * s, z * s, cos(half))
    }

    private fun multiplyQuaternion(left: FloatArray, right: FloatArray): FloatArray {
        val lx = left[0]; val ly = left[1]; val lz = left[2]; val lw = left[3]
        val rx = right[0]; val ry = right[1]; val rz = right[2]; val rw = right[3]
        return floatArrayOf(
            lw * rx + lx * rw + ly * rz - lz * ry,
            lw * ry - lx * rz + ly * rw + lz * rx,
            lw * rz + lx * ry - ly * rx + lz * rw,
            lw * rw - lx * rx - ly * ry - lz * rz,
        )
    }

    private fun normalizeQuaternion(q: FloatArray): FloatArray {
        val length = kotlin.math.sqrt(
            q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3],
        )
        if (length <= 0f) return floatArrayOf(0f, 0f, 0f, 1f)
        return floatArrayOf(q[0] / length, q[1] / length, q[2] / length, q[3] / length)
    }

    private fun doubleArg(args: Map<*, *>, key: String): Double =
        (args[key] as? Number)?.toDouble()
            ?: throw IllegalArgumentException("$key required")

    private fun optionalDoubleArg(args: Map<*, *>, key: String): Double =
        (args[key] as? Number)?.toDouble() ?: 0.0

    fun addNode(args: Map<*, *>): String {
        val normalized = normalizeNodeArgs(args)
        val id = normalized["id"] as? String ?: UUID.randomUUID().toString()
        normalized["id"] = id
        nodes[id] = normalized
        return id
    }

    fun updateNode(args: Map<*, *>) {
        val id = args["id"] as? String ?: return
        // Merge incoming args into existing node map so callers can do partial updates
        val existing = nodes[id]
        if (existing != null) {
            val merged = HashMap<Any?, Any?>()
            merged.putAll(existing)
            merged.putAll(args.filterValues { it != null })
            nodes[id] = normalizeNodeArgs(merged)
        } else {
            nodes[id] = normalizeNodeArgs(args)
        }
    }

    fun removeNode(id: String) {
        nodes.remove(id)
    }

    private fun isModelNodeMap(node: Map<*, *>): Boolean {
        if (node["modelAsset"] is Map<*, *>) return true
        val modelPath = node["modelPath"] as? String
        if (!modelPath.isNullOrBlank()) return true
        return when ((node["contentType"] as? String)?.lowercase()) {
            "obj", "gltf", "glb", "usdz", "model" -> true
            else -> false
        }
    }

    private fun normalizeNodeArgs(args: Map<*, *>): MutableMap<String, Any?> {
        val normalized = mutableMapOf<String, Any?>()
        for ((key, value) in args) {
            if (key is String) normalized[key] = value
        }

        val modelAsset = normalized["modelAsset"] as? Map<*, *>
        val modelPath = stringValue(modelAsset, "path")
            ?: stringValue(normalized, "modelPath")
            ?: return normalized
        val source = stringValue(modelAsset, "source")
        val format = stringValue(modelAsset, "format") ?: inferContentTypeFromModelPath(modelPath)

        normalized["modelPath"] = modelPath
        normalized["modelAssetResolvedPath"] = resolveModelAssetPath(modelPath, source)
        normalized["contentType"] = when (val contentType = normalized["contentType"] as? String) {
            null, "primitive" -> format
            else -> contentType
        }
        normalized["modelFallbackShape"] =
            stringValue(normalized, "modelFallbackShape")
                ?: stringValue(normalized, "primitiveShape")
                ?: "cube"

        if (normalized["primitiveSize"] == null) {
            (modelAsset?.get("fallbackSizeMeters") as? Map<*, *>)?.let {
                normalized["primitiveSize"] = it.mapKeys { entry -> entry.key.toString() }
            }
        }

        return normalized
    }

    private fun resolveModelAssetPath(path: String, source: String?): String {
        return when (source) {
            "file", "network", "bundle" -> path
            else -> flutterAssets?.getAssetFilePathByName(path) ?: path
        }
    }

    private fun inferContentTypeFromModelPath(path: String): String {
        return when (path.substringBefore('?').substringAfterLast('.', "").lowercase()) {
            "glb" -> "glb"
            "gltf" -> "gltf"
            "obj" -> "obj"
            "usdz" -> "usdz"
            "scn" -> "scn"
            "reality" -> "reality"
            else -> "custom"
        }
    }

    private fun stringValue(map: Map<*, *>?, key: String): String? {
        val value = map?.get(key) as? String ?: return null
        return value.trim().takeIf { it.isNotEmpty() }
    }

    // Camera.viewMatrix extension
    private val Camera.viewMatrix: FloatArray get() {
        val m = FloatArray(16)
        getViewMatrix(m, 0)
        return m
    }

}

// ─── Extension helpers ────────────────────────────────────────────────────────

private fun Pose.toMap(): Map<String, Any> = mapOf(
    "position" to mapOf("x" to tx().toDouble(), "y" to ty().toDouble(), "z" to tz().toDouble()),
    "rotation" to mapOf("x" to qx().toDouble(), "y" to qy().toDouble(), "z" to qz().toDouble(), "w" to qw().toDouble()),
)

private fun Plane.toMap(): Map<String, Any> {
    val boundary = mutableListOf<Map<String, Double>>()
    val verts = FloatArray(polygon.remaining())
    polygon.get(verts)
    var i = 0
    while (i < verts.size) {
        boundary.add(mapOf("x" to verts[i].toDouble(), "y" to 0.0, "z" to verts[i + 1].toDouble()))
        i += 2
    }
    return mapOf(
        "id"               to hashCode().toString(),
        "alignment"        to if (type == Plane.Type.VERTICAL) "vertical" else "horizontal",
        "centerPose"       to centerPose.toMap(),
        "extentMeters"     to mapOf("x" to extentX.toDouble(), "y" to 0.0, "z" to extentZ.toDouble()),
        "boundaryVertices" to boundary,
        "trackingState"    to trackingState.toEventName(),
    )
}

private fun AugmentedImage.toAnchorMap(): Map<String, Any> = mapOf(
    "id"            to "image:$index",
    "pose"          to centerPose.toMap(),
    "trackingState" to if (trackingState == TrackingState.TRACKING) "tracking" else "stopped",
    "metadata"      to mapOf(
        "imageTargetName" to name,
        "estimatedPhysicalWidth" to extentX.toDouble(),
    ),
)

private fun TrackingState.toEventName() = when (this) {
    TrackingState.TRACKING -> "tracking"
    TrackingState.PAUSED   -> "paused"
    TrackingState.STOPPED  -> "stopped"
}

private fun FloatArray.toList() = map { it.toDouble() }
private fun IntArray.toList()   = map { it }

// ─── Platform View factory ────────────────────────────────────────────────────

class ARViewFactory(
    private val messenger: io.flutter.plugin.common.BinaryMessenger,
    private val sessionProvider: () -> ArCoreSession?,
    private val onViewCreated: (ARPlatformView) -> Unit,
    private val onViewReady: () -> Unit,
    private val onViewDisposed: (ARPlatformView) -> Unit,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val view = ARPlatformView(
            context = context,
            viewId = viewId,
            creationParams = args as? Map<*, *>,
            sessionProvider = sessionProvider,
            onReady = onViewReady,
            onDisposed = onViewDisposed,
        )
        onViewCreated(view)
        return view
    }
}

class ARPlatformView(
    context: Context,
    private val viewId: Int,
    private val creationParams: Map<*, *>?,
    private val sessionProvider: () -> ArCoreSession?,
    private val onReady: () -> Unit,
    private val onDisposed: (ARPlatformView) -> Unit,
) : PlatformView {

    private val glView = ARGLSurfaceViewCompat(context, sessionProvider, onReady)

    override fun getView(): View = glView
    override fun dispose() {
        onDisposed(this)
        glView.disposeSafely()
    }

    fun pauseRendering() {
        glView.pauseRendering()
    }

    fun resumeRendering() {
        glView.resumeRendering()
    }

    fun resumeSessionWhenReady() {
        glView.resumeSessionWhenReady()
    }

    fun captureSnapshot(handler: Handler, result: Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(null)
            return
        }
        val width = glView.width
        val height = glView.height
        val surface = glView.holder.surface
        if (!glView.isAttachedToWindow || width <= 0 || height <= 0 || !surface.isValid) {
            result.success(null)
            return
        }

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        try {
            PixelCopy.request(glView, bitmap, { copyResult ->
                try {
                    if (copyResult != PixelCopy.SUCCESS) {
                        Log.w(TAG, "PixelCopy snapshot failed with code $copyResult")
                        result.success(null)
                    } else {
                        val bytes = ByteArrayOutputStream().use { output ->
                            if (bitmap.compress(Bitmap.CompressFormat.JPEG, 92, output)) {
                                output.toByteArray()
                            } else {
                                null
                            }
                        }
                        result.success(bytes)
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "PixelCopy snapshot encoding failed", e)
                    result.success(null)
                } finally {
                    bitmap.recycle()
                }
            }, handler)
        } catch (e: Exception) {
            bitmap.recycle()
            Log.w(TAG, "PixelCopy snapshot request failed", e)
            result.success(null)
        }
    }
}

// ─── GL Surface View wired to ARCoreGLRenderer ───────────────────────────────

class ARGLSurfaceViewCompat(
    context: Context,
    private val sessionProvider: () -> ArCoreSession?,
    private val onReady: () -> Unit,
) : GLSurfaceView(context) {

    val arRenderer = com.arengine.ar_engine.gl.ARCoreGLRenderer(
        sessionProvider = sessionProvider,
        displayRotationProvider = {
            display?.rotation ?: android.view.Surface.ROTATION_0
        },
        modelInputStreamProvider = { nodeMap, path ->
            com.arengine.ar_engine.gl.openAndroidModelInputStream(context, nodeMap, path)
        },
    )
    @Volatile private var disposed = false

    init {
        setEGLContextClientVersion(3)
        setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        preserveEGLContextOnPause = false
        setRenderer(arRenderer)
        renderMode = RENDERMODE_CONTINUOUSLY
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        onReady()
    }

    override fun onPause() {
        pauseRendering()
        super.onPause()
    }

    override fun onResume() {
        if (disposed) {
            return
        }
        super.onResume()
        resumeRendering()
    }

    fun pauseRendering() {
        try {
            queueEvent { arRenderer.onHostPause() }
        } catch (_: Exception) {
            arRenderer.onHostPause()
        }
    }

    fun resumeRendering() {
        if (disposed) {
            return
        }
        try {
            queueEvent { arRenderer.onHostResume() }
        } catch (_: Exception) {
            arRenderer.onHostResume()
        }
    }

    fun resumeSessionWhenReady() {
        if (disposed) {
            return
        }
        try {
            queueEvent { arRenderer.resumeSessionWhenSurfaceReady() }
        } catch (_: Exception) {
            arRenderer.resumeSessionWhenSurfaceReady()
        }
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        try {
            queueEvent { arRenderer.onSurfaceDestroyed() }
        } catch (_: Exception) {
            arRenderer.onSurfaceDestroyed()
        }
        super.surfaceDestroyed(holder)
    }

    fun disposeSafely() {
        if (disposed) {
            return
        }
        disposed = true
        try {
            queueEvent {
                arRenderer.onHostPause()
                arRenderer.onSurfaceDestroyed()
                arRenderer.release()
            }
        } catch (_: Exception) {
            arRenderer.release()
        }
        try {
            onPause()
        } catch (_: Exception) {
            arRenderer.onHostPause()
        }
    }
}
