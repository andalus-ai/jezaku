package com.arengine.ar_engine.gl

import android.opengl.GLES30
import android.opengl.Matrix
import android.util.Log
import com.google.ar.core.*
import com.arengine.ar_engine.ArCoreSession
import java.io.File
import java.io.InputStream
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * Full ARCore render loop.
 * Called from [ARGLSurfaceView] on the GL thread.
 * Renders: camera background → plane overlays → PBR scene nodes → shadows.
 */
class ARCoreGLRenderer(
    private val sessionProvider: () -> ArCoreSession?,
    private val displayRotationProvider: () -> Int = { android.view.Surface.ROTATION_0 },
    private val modelInputStreamProvider: (Map<*, *>, String) -> InputStream? = { _, _ -> null },
) :
    android.opengl.GLSurfaceView.Renderer {
    private companion object {
        const val TAG = "ARCoreGLRenderer"
    }

    // Sub-renderers
    private val bgRenderer     = CameraBackgroundRenderer()
    private val pbrRenderer    = PBRObjectRenderer()
    private val planeRenderer  = PlaneRenderer()
    private val shadowRenderer = ShadowMapRenderer()

    // Camera background OES texture registered with ARCore session
    private var cameraOesTexture = 0
    private var cameraTextureSession: Session? = null
    private var updateFailureLogged = false
    @Volatile private var surfaceReady = false
    @Volatile private var renderingPaused = true

    private var viewportWidth  = 0
    private var viewportHeight = 0
    private val loggedPhotoFrameRenderKeys = mutableSetOf<String>()

    // Latest frame data (updated from onDrawFrame, consumed for hit-test)
    @Volatile var latestFrame: Frame? = null

    private data class NodeMaterial(
        val baseColor: FloatArray,
        val metallic: Float,
        val roughness: Float,
        val opacity: Float,
        val doubleSided: Boolean,
    )

    // ── GL lifecycle ──────────────────────────────────────────────────────────

    override fun onSurfaceCreated(gl: GL10, config: EGLConfig) {
        surfaceReady = true
        renderingPaused = false
        cameraTextureSession = null
        updateFailureLogged = false
        latestFrame = null
        GLES30.glClearColor(0f, 0f, 0f, 1f)
        GLES30.glEnable(GLES30.GL_DEPTH_TEST)
        GLES30.glEnable(GLES30.GL_CULL_FACE)

        // Generate camera background OES texture
        val texIds = IntArray(1)
        GLES30.glGenTextures(1, texIds, 0)
        cameraOesTexture = texIds[0]
        GLES30.glBindTexture(0x8D65 /*GL_TEXTURE_EXTERNAL_OES*/, cameraOesTexture)
        GLES30.glTexParameteri(0x8D65, GLES30.GL_TEXTURE_WRAP_S,   GLES30.GL_CLAMP_TO_EDGE)
        GLES30.glTexParameteri(0x8D65, GLES30.GL_TEXTURE_WRAP_T,   GLES30.GL_CLAMP_TO_EDGE)
        GLES30.glTexParameteri(0x8D65, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(0x8D65, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)

        sessionProvider()?.let { arSession ->
            synchronized(arSession.sessionLock) {
                if (attachCameraTextureIfNeeded(arSession.session)) {
                    arSession.startIfRequested()
                }
            }
        }

        bgRenderer.init()
        pbrRenderer.init()
        planeRenderer.init()
        shadowRenderer.init()

        ShaderUtil.checkGLError("ARCoreGLRenderer.onSurfaceCreated")
    }

    override fun onSurfaceChanged(gl: GL10, width: Int, height: Int) {
        if (width <= 0 || height <= 0) {
            viewportWidth = 0
            viewportHeight = 0
            return
        }
        GLES30.glViewport(0, 0, width, height)
        viewportWidth  = width
        viewportHeight = height
        // Tell ARCore the display rotation/size
        sessionProvider()?.let { arSession ->
            arSession.setViewportSize(width, height)
            synchronized(arSession.sessionLock) {
                arSession.session?.setDisplayGeometry(
                    displayRotationProvider(), width, height
                )
            }
        }
    }

    override fun onDrawFrame(gl: GL10) {
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT or GLES30.GL_DEPTH_BUFFER_BIT)

        val arSession = sessionProvider() ?: return
        synchronized(arSession.sessionLock) {
            if (!surfaceReady || renderingPaused || !arSession.isRunning) {
                return
            }
            val session = arSession.session ?: return
            attachCameraTextureIfNeeded(session)
            if (cameraOesTexture == 0 || cameraTextureSession !== session) {
                return
            }
            if (viewportWidth > 0 && viewportHeight > 0) {
                session.setDisplayGeometry(
                    displayRotationProvider(),
                    viewportWidth,
                    viewportHeight,
                )
            }

            // ── 1. Update ARCore, acquire latest frame ────────────────────────
            val frame: Frame = try {
                session.update()
            } catch (e: Exception) {
                if (!updateFailureLogged) {
                    Log.w(TAG, "ARCore frame update failed", e)
                    updateFailureLogged = true
                }
                return
            }
            updateFailureLogged = false
            latestFrame = frame
            bgRenderer.updateDisplayGeometry(frame)

            // Notify Dart side (camera / plane / anchor / light streams)
            arSession.onFrame(frame)

            val camera = frame.camera
            if (camera.trackingState != TrackingState.TRACKING) {
                // Still draw background even when not tracking
                bgRenderer.draw(cameraOesTexture)
                return
            }

            // ── 2. Build matrices ─────────────────────────────────────────────
            val projMatrix = FloatArray(16)
            val viewMatrix = FloatArray(16)
            camera.getProjectionMatrix(projMatrix, 0, 0.01f, 100f)
            camera.getViewMatrix(viewMatrix, 0)

            val viewProj = FloatArray(16)
            Matrix.multiplyMM(viewProj, 0, projMatrix, 0, viewMatrix, 0)

            // Camera world position extracted from inverse view matrix
            val camPos = floatArrayOf(
                -(viewMatrix[0]*viewMatrix[12] + viewMatrix[1]*viewMatrix[13] + viewMatrix[2]*viewMatrix[14]),
                -(viewMatrix[4]*viewMatrix[12] + viewMatrix[5]*viewMatrix[13] + viewMatrix[6]*viewMatrix[14]),
                -(viewMatrix[8]*viewMatrix[12] + viewMatrix[9]*viewMatrix[13] + viewMatrix[10]*viewMatrix[14]),
            )

            // Light direction from estimated HDR lighting (if available)
            val lightDir: FloatArray
            val lightIntensity: Float
            val le = frame.lightEstimate
            if (le != null && le.state == LightEstimate.State.VALID) {
                val ld = le.environmentalHdrMainLightDirection
                lightDir       = floatArrayOf(ld[0], ld[1], ld[2])
                lightIntensity = le.environmentalHdrMainLightIntensity.let {
                    (it[0] + it[1] + it[2]) / 3f
                }.coerceIn(0.2f, 4f)
            } else {
                lightDir       = floatArrayOf(0f, -1f, -0.5f)
                lightIntensity = 1.2f
            }

            // ── 3. Shadow pass ────────────────────────────────────────────────
            shadowRenderer.beginShadowPass(lightDir, floatArrayOf(camPos[0], 0f, camPos[2] - 1f))
            // Draw shadow-casting nodes into depth buffer
            renderNodesForShadow(arSession, shadowRenderer.lightSpaceMatrix)
            shadowRenderer.endShadowPass(viewportWidth, viewportHeight)

            // ── 4. Draw camera background ─────────────────────────────────────
            bgRenderer.draw(cameraOesTexture)

            // ── 5. Draw detected planes ───────────────────────────────────────
            for (plane in session.getAllTrackables(Plane::class.java)) {
                if (plane.trackingState != TrackingState.TRACKING) continue
                val modelMatrix = poseToModelMatrix(plane.centerPose,
                    plane.extentX, plane.extentZ)
                planeRenderer.draw(viewProj, modelMatrix)
            }

            // ── 6. Draw scene nodes (PBR) ─────────────────────────────────────
            renderNodes(arSession, viewProj, camPos, lightDir, lightIntensity)

            ShaderUtil.checkGLError("ARCoreGLRenderer.onDrawFrame")
        }
    }

    fun onHostPause() {
        renderingPaused = true
        latestFrame = null
    }

    fun onHostResume() {
        renderingPaused = false
        updateFailureLogged = false
    }

    fun resumeSessionWhenSurfaceReady() {
        val arSession = sessionProvider() ?: return
        synchronized(arSession.sessionLock) {
            if (!surfaceReady || cameraOesTexture == 0) {
                return
            }
            if (attachCameraTextureIfNeeded(arSession.session)) {
                arSession.startIfRequested()
            }
        }
    }

    fun onSurfaceDestroyed() {
        surfaceReady = false
        viewportWidth = 0
        viewportHeight = 0
        cameraOesTexture = 0
        cameraTextureSession = null
        latestFrame = null
        updateFailureLogged = false
        loggedPhotoFrameRenderKeys.clear()
    }

    // ── Scene rendering ───────────────────────────────────────────────────────

    private fun renderNodes(
        session: ArCoreSession,
        viewProj: FloatArray,
        camPos: FloatArray,
        lightDir: FloatArray,
        lightIntensity: Float,
    ) {
        for ((nodeId, nodeMap) in session.nodes) {
            if ((nodeMap["isVisible"] as? Boolean) == false) continue

            val anchorId = nodeMap["anchorId"] as? String
            val anchor   = if (anchorId != null) session.anchors[anchorId] else null

            val modelMatrix = if (anchor != null && anchor.trackingState == TrackingState.TRACKING) {
                val m = FloatArray(16)
                anchor.pose.toMatrix(m, 0)
                applyNodeTransform(m, nodeMap)
            } else {
                buildModelMatrixFromNode(nodeMap)
            }

            val shape     = fallbackPrimitiveShape(nodeMap)
            val matMap    = nodeMap["material"] as? Map<*, *>
            val doubleSided = (matMap?.get("doubleSided") as? Boolean) ?: shape == "plane"
            val baseColor = matMap?.let {
                val c = it["baseColor"] as? Map<*, *>
                floatArrayOf(
                    (c?.get("r") as? Number)?.toFloat() ?: 1f,
                    (c?.get("g") as? Number)?.toFloat() ?: 1f,
                    (c?.get("b") as? Number)?.toFloat() ?: 1f,
                )
            } ?: floatArrayOf(0.2f, 0.6f, 1f)
            val metallic  = (matMap?.get("metallic")  as? Number)?.toFloat() ?: 0.1f
            val roughness = (matMap?.get("roughness") as? Number)?.toFloat() ?: 0.6f
            val opacity   = (matMap?.get("opacity")   as? Number)?.toFloat() ?: 1f
            val metadata = nodeMap["metadata"] as? Map<*, *>
            val textureBytes = metadata?.get("photoTextureBytes") as? ByteArray
            val textureKey = (metadata?.get("photoTextureKey") as? String)
                ?: (metadata?.get("mediaId") as? String)
                ?: nodeId
            val textureInfo = if (textureBytes != null) {
                TextureCache.getOrCreate(textureKey, textureBytes)
            } else {
                null
            }
            val isPhotoFrame = metadata?.get("photoFrame") == true
            if (isPhotoFrame) {
                val baseModelMatrix = if (anchor != null && anchor.trackingState == TrackingState.TRACKING) {
                    val m = FloatArray(16)
                    anchor.pose.toMatrix(m, 0)
                    applyNodeTransform(m, nodeMap, includePrimitiveSize = false)
                } else {
                    buildModelMatrixFromNode(nodeMap, includePrimitiveSize = false)
                }
                drawHangingPhotoFrame(
                    nodeId = nodeId,
                    baseModelMatrix = baseModelMatrix,
                    viewProj = viewProj,
                    camPos = camPos,
                    lightDir = lightDir,
                    lightIntensity = lightIntensity,
                    nodeMap = nodeMap,
                    textureInfo = textureInfo,
                    baseColor = baseColor,
                    opacity = opacity,
                )
                continue
            }

            val mesh = ModelMeshCache.getOrNull(nodeMap, modelInputStreamProvider)
                ?: MeshCache.get(shape)
            pbrRenderer.drawMesh(
                mesh       = mesh,
                modelMatrix = modelMatrix,
                viewProjMatrix = viewProj,
                camPos     = camPos,
                baseColor  = baseColor,
                metallic   = metallic,
                roughness  = roughness,
                opacity    = opacity,
                doubleSided = doubleSided,
                baseColorTextureId = textureInfo?.id,
                baseColorUvTransform = textureInfo?.let {
                    coverUvTransform(nodeMap, it)
                } ?: floatArrayOf(1f, 1f, 0f, 0f),
                lightDir   = lightDir,
                lightInt   = lightIntensity,
            )
        }
    }

    private fun drawHangingPhotoFrame(
        nodeId: String,
        baseModelMatrix: FloatArray,
        viewProj: FloatArray,
        camPos: FloatArray,
        lightDir: FloatArray,
        lightIntensity: Float,
        nodeMap: Map<*, *>,
        textureInfo: GLTextureInfo?,
        baseColor: FloatArray,
        opacity: Float,
    ) {
        val metadata = nodeMap["metadata"] as? Map<*, *>
        val style = metadata?.get("photoFrameStyle") as? Map<*, *>
        val size = nodeMap["primitiveSize"] as? Map<*, *>
        val photoWidth = mapFloat(size, "x", 0.42f).coerceAtLeast(0.08f)
        val photoHeight = mapFloat(size, "z", 0.28f).coerceAtLeast(0.08f)
        val frameDepth = frameStyleFloat(
            style,
            metadata,
            styleKey = "depthMeters",
            metadataKey = "frameDepthMeters",
            defaultValue = 0.10f,
        ).coerceIn(0.025f, 0.24f)
        val frameBorder = frameStyleFloat(
            style,
            metadata,
            styleKey = "borderMeters",
            metadataKey = "frameBorderMeters",
            defaultValue = 0.072f,
        ).coerceIn(0.02f, 0.18f)
        val photoRecess = frameStyleFloat(
            style,
            metadata,
            styleKey = "photoRecessMeters",
            metadataKey = "photoRecessMeters",
            defaultValue = frameDepth * 0.46f,
        ).coerceIn(0.008f, frameDepth * 0.72f)
        val backingThickness = frameStyleFloat(
            style,
            metadata,
            styleKey = "backingThicknessMeters",
            metadataKey = "frameBackingThicknessMeters",
            defaultValue = frameDepth * 0.18f,
        ).coerceIn(0.004f, frameDepth * 0.36f)
        val topLipHeight = frameStyleFloat(
            style,
            metadata,
            styleKey = "topLipHeightMeters",
            metadataKey = "frameTopLipHeightMeters",
            defaultValue = 0.008f,
        ).coerceIn(0.002f, 0.04f)
        val outerWidth = photoWidth + frameBorder * 2f
        val outerHeight = photoHeight + frameBorder * 2f
        val planeMesh = MeshCache.get("plane")
        val cubeMesh = MeshCache.get("cube")
        val frameMesh = MeshCache.getPhotoFrameRing(
            outerWidth = outerWidth,
            outerHeight = outerHeight,
            photoWidth = photoWidth,
            photoHeight = photoHeight,
            depth = frameDepth,
            recess = photoRecess,
        )
        val renderLogKey = listOf(
            nodeId,
            (baseModelMatrix[12] * 100f).toInt(),
            (baseModelMatrix[13] * 100f).toInt(),
            (baseModelMatrix[14] * 100f).toInt(),
            (photoWidth * 1000f).toInt(),
            (photoHeight * 1000f).toInt(),
            (frameDepth * 1000f).toInt(),
            (frameBorder * 1000f).toInt(),
            (photoRecess * 1000f).toInt(),
            (backingThickness * 1000f).toInt(),
            (topLipHeight * 1000f).toInt(),
        ).joinToString(":")
        if (loggedPhotoFrameRenderKeys.add(renderLogKey)) {
            Log.i(
                TAG,
                "AR_HANGING_FRAME render node=$nodeId " +
                    "world=(${baseModelMatrix[12].format3()}," +
                    "${baseModelMatrix[13].format3()}," +
                    "${baseModelMatrix[14].format3()}) " +
                    "photo=${photoWidth.format3()}x${photoHeight.format3()}m " +
                    "outer=${outerWidth.format3()}x${outerHeight.format3()}m " +
                    "depth=${frameDepth.format3()}m " +
                    "border=${frameBorder.format3()}m " +
                    "recess=${photoRecess.format3()}m " +
                    "backing=${backingThickness.format3()}m " +
                    "topLip=${topLipHeight.format3()}m " +
                    "preset=${style?.get("preset") ?: metadata?.get("photoFramePreset") ?: "custom"} " +
                    "texture=${textureInfo?.width ?: 0}x${textureInfo?.height ?: 0}",
            )
        }

        val backingMaterial = frameMaterial(
            style = style,
            key = "backingMaterial",
            fallbackColor = floatArrayOf(0.035f, 0.032f, 0.028f),
            fallbackRoughness = 0.72f,
        )
        val frameMaterial = frameMaterial(
            style = style,
            key = "frameMaterial",
            fallbackColor = floatArrayOf(0.055f, 0.046f, 0.036f),
            fallbackRoughness = 0.55f,
            fallbackDoubleSided = true,
        )
        val highlightMaterial = frameMaterial(
            style = style,
            key = "highlightMaterial",
            fallbackColor = floatArrayOf(0.12f, 0.095f, 0.064f),
            fallbackRoughness = 0.48f,
        )

        pbrRenderer.drawMesh(
            mesh = cubeMesh,
            modelMatrix = localModelMatrix(
                baseModelMatrix,
                tx = 0f,
                ty = -frameDepth / 2f + backingThickness / 2f,
                tz = 0f,
                sx = outerWidth,
                sy = backingThickness,
                sz = outerHeight,
            ),
            viewProjMatrix = viewProj,
            camPos = camPos,
            baseColor = backingMaterial.baseColor,
            metallic = backingMaterial.metallic,
            roughness = backingMaterial.roughness,
            opacity = backingMaterial.opacity,
            doubleSided = backingMaterial.doubleSided,
            lightDir = lightDir,
            lightInt = lightIntensity,
        )

        pbrRenderer.drawMesh(
            mesh = frameMesh,
            modelMatrix = baseModelMatrix,
            viewProjMatrix = viewProj,
            camPos = camPos,
            baseColor = frameMaterial.baseColor,
            metallic = frameMaterial.metallic,
            roughness = frameMaterial.roughness,
            opacity = frameMaterial.opacity,
            doubleSided = frameMaterial.doubleSided,
            lightDir = lightDir,
            lightInt = lightIntensity,
        )

        pbrRenderer.drawMesh(
            mesh = cubeMesh,
            modelMatrix = localModelMatrix(
                baseModelMatrix,
                tx = 0f,
                ty = frameDepth / 2f + topLipHeight / 2f,
                tz = photoHeight / 2f + frameBorder * 0.78f,
                sx = outerWidth * 0.92f,
                sy = topLipHeight,
                sz = frameBorder * 0.18f,
            ),
            viewProjMatrix = viewProj,
            camPos = camPos,
            baseColor = highlightMaterial.baseColor,
            metallic = highlightMaterial.metallic,
            roughness = highlightMaterial.roughness,
            opacity = highlightMaterial.opacity,
            doubleSided = highlightMaterial.doubleSided,
            lightDir = lightDir,
            lightInt = lightIntensity,
        )

        pbrRenderer.drawMesh(
            mesh = planeMesh,
            modelMatrix = localModelMatrix(
                baseModelMatrix,
                tx = 0f,
                ty = frameDepth / 2f - photoRecess + 0.002f,
                tz = 0f,
                sx = photoWidth,
                sy = 1f,
                sz = photoHeight,
            ),
            viewProjMatrix = viewProj,
            camPos = camPos,
            baseColor = baseColor,
            metallic = 0f,
            roughness = 0.36f,
            opacity = opacity,
            doubleSided = true,
            baseColorTextureId = textureInfo?.id,
            baseColorUvTransform = textureInfo?.let {
                coverUvTransform(nodeMap, it)
            } ?: floatArrayOf(1f, 1f, 0f, 0f),
            unlit = textureInfo != null,
            frontOnly = true,
            lightDir = lightDir,
            lightInt = lightIntensity,
        )
    }

    private fun frameStyleFloat(
        style: Map<*, *>?,
        metadata: Map<*, *>?,
        styleKey: String,
        metadataKey: String,
        defaultValue: Float,
    ): Float {
        return mapFloat(style, styleKey, Float.NaN)
            .takeIf { it.isFinite() }
            ?: mapFloat(metadata, metadataKey, defaultValue)
    }

    private fun frameMaterial(
        style: Map<*, *>?,
        key: String,
        fallbackColor: FloatArray,
        fallbackRoughness: Float,
        fallbackMetallic: Float = 0f,
        fallbackOpacity: Float = 1f,
        fallbackDoubleSided: Boolean = false,
    ): NodeMaterial {
        val material = style?.get(key) as? Map<*, *>
        val color = material?.get("baseColor") as? Map<*, *>
        return NodeMaterial(
            baseColor = floatArrayOf(
                mapFloat(color, "r", fallbackColor[0]),
                mapFloat(color, "g", fallbackColor[1]),
                mapFloat(color, "b", fallbackColor[2]),
            ),
            metallic = mapFloat(material, "metallic", fallbackMetallic)
                .coerceIn(0f, 1f),
            roughness = mapFloat(material, "roughness", fallbackRoughness)
                .coerceIn(0f, 1f),
            opacity = mapFloat(material, "opacity", fallbackOpacity).coerceIn(0f, 1f),
            doubleSided = (material?.get("doubleSided") as? Boolean) ?: fallbackDoubleSided,
        )
    }

    private fun localModelMatrix(
        baseModelMatrix: FloatArray,
        tx: Float,
        ty: Float,
        tz: Float,
        sx: Float,
        sy: Float,
        sz: Float,
    ): FloatArray {
        val local = FloatArray(16)
        Matrix.setIdentityM(local, 0)
        Matrix.translateM(local, 0, tx, ty, tz)
        Matrix.scaleM(local, 0, sx, sy, sz)
        val result = FloatArray(16)
        Matrix.multiplyMM(result, 0, baseModelMatrix, 0, local, 0)
        return result
    }

    private fun coverUvTransform(nodeMap: Map<*, *>, texture: GLTextureInfo): FloatArray {
        val size = nodeMap["primitiveSize"] as? Map<*, *>
        val surfaceWidth = mapFloat(size, "x", 1f).coerceAtLeast(0.01f)
        val surfaceHeight = mapFloat(size, "z", 1f).coerceAtLeast(0.01f)
        val surfaceAspect = surfaceWidth / surfaceHeight
        val textureAspect = texture.width.toFloat() / texture.height.toFloat().coerceAtLeast(1f)
        if (textureAspect > surfaceAspect) {
            val scaleX = surfaceAspect / textureAspect
            return floatArrayOf(scaleX, 1f, (1f - scaleX) / 2f, 0f)
        }
        val scaleY = textureAspect / surfaceAspect
        return floatArrayOf(1f, scaleY, 0f, (1f - scaleY) / 2f)
    }

    private fun renderNodesForShadow(session: ArCoreSession, lightSpaceMVP: FloatArray) {
        // Simplified depth-only pass – bind depth shader and draw same meshes
        // (Full implementation would use a separate depth-only shader program)
        for ((_, nodeMap) in session.nodes) {
            val shape = fallbackPrimitiveShape(nodeMap)
            ModelMeshCache.getOrNull(nodeMap, modelInputStreamProvider)
                ?: MeshCache.get(shape) // ensure mesh is in cache
        }
    }

    private fun fallbackPrimitiveShape(nodeMap: Map<*, *>): String {
        val requestedShape = nodeMap["primitiveShape"] as? String
        if (!isModelNode(nodeMap)) return requestedShape ?: "cube"
        // Model assets render with primitive fallback until Android mesh loading is available.
        return (nodeMap["modelFallbackShape"] as? String)
            ?: requestedShape
            ?: "cube"
    }

    private fun isModelNode(nodeMap: Map<*, *>): Boolean {
        val contentType = nodeMap["contentType"] as? String
        if (contentType != null && contentType != "primitive") return true
        if (nodeMap["modelAsset"] is Map<*, *>) return true
        return (nodeMap["modelPath"] as? String)?.trim()?.isNotEmpty() == true
    }

    // ── Matrix helpers ────────────────────────────────────────────────────────

    private fun poseToModelMatrix(pose: Pose, scaleX: Float = 1f, scaleZ: Float = 1f): FloatArray {
        val m = FloatArray(16)
        pose.toMatrix(m, 0)
        // Apply plane extent scale
        m[0] *= scaleX; m[1] *= scaleX; m[2] *= scaleX
        m[8] *= scaleZ; m[9] *= scaleZ; m[10] *= scaleZ
        return m
    }

    private fun applyNodeTransform(
        anchorMatrix: FloatArray,
        node: Map<*, *>,
        includePrimitiveSize: Boolean = true,
    ): FloatArray {
        val pos = node["position"] as? Map<*, *>
        val rot = node["rotation"] as? Map<*, *>
        val scale = nodeScale(node, includePrimitiveSize = includePrimitiveSize)

        val localModel = FloatArray(16)
        Matrix.setIdentityM(localModel, 0)

        val tx = (pos?.get("x") as? Number)?.toFloat() ?: 0f
        val ty = (pos?.get("y") as? Number)?.toFloat() ?: 0f
        val tz = (pos?.get("z") as? Number)?.toFloat() ?: 0f
        Matrix.translateM(localModel, 0, tx, ty, tz)
        applyQuaternionRotation(localModel, rot)
        Matrix.scaleM(localModel, 0, scale[0], scale[1], scale[2])

        val result = FloatArray(16)
        Matrix.multiplyMM(result, 0, anchorMatrix, 0, localModel, 0)
        return result
    }

    private fun buildModelMatrixFromNode(
        node: Map<*, *>,
        includePrimitiveSize: Boolean = true,
    ): FloatArray {
        val pos = node["position"] as? Map<*, *>
        val rot = node["rotation"] as? Map<*, *>
        val scale = nodeScale(node, includePrimitiveSize = includePrimitiveSize)

        val m = FloatArray(16)
        Matrix.setIdentityM(m, 0)

        val tx = (pos?.get("x") as? Number)?.toFloat() ?: 0f
        val ty = (pos?.get("y") as? Number)?.toFloat() ?: 0f
        val tz = (pos?.get("z") as? Number)?.toFloat() ?: 0f
        Matrix.translateM(m, 0, tx, ty, tz)
        applyQuaternionRotation(m, rot)
        Matrix.scaleM(m, 0, scale[0], scale[1], scale[2])
        return m
    }

    private fun nodeScale(
        node: Map<*, *>,
        includePrimitiveSize: Boolean = true,
    ): FloatArray {
        val scl = node["scale"] as? Map<*, *>
        val size = node["primitiveSize"] as? Map<*, *>
        if (!includePrimitiveSize) {
            return floatArrayOf(
                mapFloat(scl, "x", 1f),
                mapFloat(scl, "y", 1f),
                mapFloat(scl, "z", 1f),
            )
        }
        return floatArrayOf(
            mapFloat(scl, "x", 1f) * mapFloat(size, "x", 1f),
            mapFloat(scl, "y", 1f) * mapFloat(size, "y", 1f),
            mapFloat(scl, "z", 1f) * mapFloat(size, "z", 1f),
        )
    }

    private fun mapFloat(map: Map<*, *>?, key: String, defaultValue: Float): Float {
        return (map?.get(key) as? Number)?.toFloat() ?: defaultValue
    }

    private fun Float.format3(): String {
        return String.format(java.util.Locale.US, "%.3f", this)
    }

    private fun applyQuaternionRotation(matrix: FloatArray, rot: Map<*, *>?) {
        val qx = (rot?.get("x") as? Number)?.toFloat() ?: 0f
        val qy = (rot?.get("y") as? Number)?.toFloat() ?: 0f
        val qz = (rot?.get("z") as? Number)?.toFloat() ?: 0f
        val qw = (rot?.get("w") as? Number)?.toFloat() ?: 1f
        val rotM = FloatArray(16)
        Matrix.setIdentityM(rotM, 0)
        val norm = Math.sqrt((qx*qx + qy*qy + qz*qz + qw*qw).toDouble()).toFloat()
        if (norm <= 0f || norm.isNaN()) {
            return
        }
        val nx = qx/norm; val ny = qy/norm; val nz = qz/norm; val nw = qw/norm
        rotM[ 0] = 1-2*(ny*ny+nz*nz); rotM[ 4] = 2*(nx*ny-nw*nz); rotM[ 8] = 2*(nx*nz+nw*ny)
        rotM[ 1] = 2*(nx*ny+nw*nz);   rotM[ 5] = 1-2*(nx*nx+nz*nz); rotM[ 9] = 2*(ny*nz-nw*nx)
        rotM[ 2] = 2*(nx*nz-nw*ny);   rotM[ 6] = 2*(ny*nz+nw*nx); rotM[10] = 1-2*(nx*nx+ny*ny)
        rotM[15] = 1f

        val result = FloatArray(16)
        Matrix.multiplyMM(result, 0, matrix, 0, rotM, 0)
        System.arraycopy(result, 0, matrix, 0, 16)
    }

    private fun attachCameraTextureIfNeeded(session: Session?): Boolean {
        if (session == null ||
            cameraOesTexture == 0
        ) {
            return false
        }
        if (cameraTextureSession === session) {
            return true
        }
        try {
            session.setCameraTextureName(cameraOesTexture)
            cameraTextureSession = session
            Log.i(TAG, "Attached ARCore camera texture $cameraOesTexture")
            return true
        } catch (e: Exception) {
            cameraTextureSession = null
            if (!updateFailureLogged) {
                Log.w(TAG, "Unable to attach ARCore camera texture", e)
                updateFailureLogged = true
            }
            return false
        }
    }

    fun release() {
        onHostPause()
        onSurfaceDestroyed()
        bgRenderer.release()
        pbrRenderer.release()
        planeRenderer.release()
        shadowRenderer.release()
        ModelMeshCache.releaseAll()
        MeshCache.releaseAll()
        TextureCache.releaseAll()
    }
}

internal fun openAndroidModelInputStream(
    context: android.content.Context,
    nodeMap: Map<*, *>,
    path: String,
): InputStream? {
    val modelAsset = nodeMap["modelAsset"] as? Map<*, *>
    val source = modelAsset?.get("source") as? String
    return try {
        when (source) {
            "file" -> File(path.removePrefix("file://")).inputStream()
            "network" -> null
            else -> context.assets.open(path)
        }
    } catch (_: Exception) {
        null
    }
}

/** GL surface view wired to [ARCoreGLRenderer]. */
class ARGLSurfaceView(
    context: android.content.Context,
    sessionProvider: () -> ArCoreSession?,
) : android.opengl.GLSurfaceView(context) {

    val arRenderer = ARCoreGLRenderer(
        sessionProvider = sessionProvider,
        displayRotationProvider = {
            display?.rotation ?: android.view.Surface.ROTATION_0
        },
        modelInputStreamProvider = { nodeMap, path ->
            openAndroidModelInputStream(context, nodeMap, path)
        },
    )

    init {
        setEGLContextClientVersion(3)
        setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        preserveEGLContextOnPause = false
        setRenderer(arRenderer)
        renderMode = RENDERMODE_CONTINUOUSLY
    }

    override fun onPause() {
        try {
            queueEvent { arRenderer.onHostPause() }
        } catch (_: Exception) {
            arRenderer.onHostPause()
        }
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        try {
            queueEvent { arRenderer.onHostResume() }
        } catch (_: Exception) {
            arRenderer.onHostResume()
        }
    }

    override fun surfaceDestroyed(holder: android.view.SurfaceHolder) {
        try {
            queueEvent { arRenderer.onSurfaceDestroyed() }
        } catch (_: Exception) {
            arRenderer.onSurfaceDestroyed()
        }
        super.surfaceDestroyed(holder)
    }
}
