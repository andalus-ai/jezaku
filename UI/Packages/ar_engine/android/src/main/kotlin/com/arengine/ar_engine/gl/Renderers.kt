package com.arengine.ar_engine.gl

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.content.Context
import android.graphics.Matrix as GraphicsMatrix
import android.media.ExifInterface
import android.opengl.GLES30
import android.opengl.GLUtils
import android.opengl.Matrix
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Frame
import java.io.ByteArrayInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

// ─── Shader compiler ─────────────────────────────────────────────────────────

object ShaderUtil {
    fun compileShader(type: Int, src: String): Int {
        val shader = GLES30.glCreateShader(type)
        check(shader != 0) { "glCreateShader failed" }
        GLES30.glShaderSource(shader, src)
        GLES30.glCompileShader(shader)
        val status = IntArray(1)
        GLES30.glGetShaderiv(shader, GLES30.GL_COMPILE_STATUS, status, 0)
        if (status[0] == GLES30.GL_FALSE) {
            val log = GLES30.glGetShaderInfoLog(shader)
            GLES30.glDeleteShader(shader)
            error("Shader compile error: $log\n--- Source ---\n$src")
        }
        return shader
    }

    fun linkProgram(vertSrc: String, fragSrc: String): Int {
        val vert = compileShader(GLES30.GL_VERTEX_SHADER,   vertSrc)
        val frag = compileShader(GLES30.GL_FRAGMENT_SHADER, fragSrc)
        val prog = GLES30.glCreateProgram()
        check(prog != 0) { "glCreateProgram failed" }
        GLES30.glAttachShader(prog, vert)
        GLES30.glAttachShader(prog, frag)
        GLES30.glLinkProgram(prog)
        val status = IntArray(1)
        GLES30.glGetProgramiv(prog, GLES30.GL_LINK_STATUS, status, 0)
        if (status[0] == GLES30.GL_FALSE) {
            val log = GLES30.glGetProgramInfoLog(prog)
            GLES30.glDeleteProgram(prog)
            error("Program link error: $log")
        }
        GLES30.glDeleteShader(vert)
        GLES30.glDeleteShader(frag)
        return prog
    }

    fun checkGLError(tag: String) {
        var err = GLES30.glGetError()
        while (err != GLES30.GL_NO_ERROR) {
            android.util.Log.e("AREngine/$tag", "GL error 0x${err.toString(16)}")
            err = GLES30.glGetError()
        }
    }
}

// ─── Camera background renderer ───────────────────────────────────────────────
// Draws the ARCore camera texture as a full-screen quad using OES_EGL_image_external.

object CameraBackgroundShaders {
    val VERT = """
        #version 300 es
        in vec4 a_Position;
        in vec2 a_TexCoord;
        out vec2 v_TexCoord;
        void main() {
            gl_Position = a_Position;
            v_TexCoord  = a_TexCoord;
        }
    """.trimIndent()

    val FRAG = """
        #version 300 es
        #extension GL_OES_EGL_image_external_essl3 : require
        precision mediump float;
        uniform samplerExternalOES u_Texture;
        in  vec2 v_TexCoord;
        out vec4 o_FragColor;
        void main() {
            o_FragColor = texture(u_Texture, v_TexCoord);
        }
    """.trimIndent()
}

class CameraBackgroundRenderer {
    private var program        = 0
    private var positionAttrib = 0
    private var texCoordAttrib = 0
    private var textureUniform = 0
    private var quadVAO        = 0
    private var quadVBO        = 0

    private val quadVerts = floatArrayOf(
        // x,    y,    s,    t
        -1f,  1f,  0f,  0f,
        -1f, -1f,  0f,  1f,
         1f, -1f,  1f,  1f,
        -1f,  1f,  0f,  0f,
         1f, -1f,  1f,  1f,
         1f,  1f,  1f,  0f,
    )
    private val ndcCoords = floatArrayOf(
        -1f,  1f,
        -1f, -1f,
         1f, -1f,
        -1f,  1f,
         1f, -1f,
         1f,  1f,
    )
    private val ndcBuffer: FloatBuffer = ByteBuffer
        .allocateDirect(ndcCoords.size * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
        .apply { put(ndcCoords).position(0) }
    private val transformedTexCoordBuffer: FloatBuffer = ByteBuffer
        .allocateDirect(ndcCoords.size * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()

    fun init() {
        program        = ShaderUtil.linkProgram(CameraBackgroundShaders.VERT, CameraBackgroundShaders.FRAG)
        positionAttrib = GLES30.glGetAttribLocation(program, "a_Position")
        texCoordAttrib = GLES30.glGetAttribLocation(program, "a_TexCoord")
        textureUniform = GLES30.glGetUniformLocation(program, "u_Texture")

        val vaos = IntArray(1); GLES30.glGenVertexArrays(1, vaos, 0); quadVAO = vaos[0]
        val vbos = IntArray(1); GLES30.glGenBuffers(1, vbos, 0);      quadVBO = vbos[0]

        GLES30.glBindVertexArray(quadVAO)
        GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, quadVBO)

        val buf = ByteBuffer.allocateDirect(quadVerts.size * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer()
        buf.put(quadVerts).position(0)
        GLES30.glBufferData(GLES30.GL_ARRAY_BUFFER, quadVerts.size * 4, buf, GLES30.GL_DYNAMIC_DRAW)

        val stride = 4 * 4 // 4 floats * 4 bytes
        GLES30.glEnableVertexAttribArray(positionAttrib)
        GLES30.glVertexAttribPointer(positionAttrib, 2, GLES30.GL_FLOAT, false, stride, 0)
        GLES30.glEnableVertexAttribArray(texCoordAttrib)
        GLES30.glVertexAttribPointer(texCoordAttrib, 2, GLES30.GL_FLOAT, false, stride, 2 * 4)

        GLES30.glBindVertexArray(0)
        ShaderUtil.checkGLError("CameraBackgroundRenderer.init")
    }

    fun updateDisplayGeometry(frame: Frame) {
        if (quadVBO == 0) return

        ndcBuffer.position(0)
        transformedTexCoordBuffer.position(0)
        frame.transformCoordinates2d(
            Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES,
            ndcBuffer,
            Coordinates2d.TEXTURE_NORMALIZED,
            transformedTexCoordBuffer,
        )
        transformedTexCoordBuffer.position(0)
        for (index in 0 until 6) {
            quadVerts[index * 4 + 2] = transformedTexCoordBuffer.get(index * 2)
            quadVerts[index * 4 + 3] = transformedTexCoordBuffer.get(index * 2 + 1)
        }

        val buf = ByteBuffer.allocateDirect(quadVerts.size * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer()
        buf.put(quadVerts).position(0)
        GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, quadVBO)
        GLES30.glBufferSubData(GLES30.GL_ARRAY_BUFFER, 0, quadVerts.size * 4, buf)
        GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, 0)
    }

    /** [oesTextureId] is the texture name set via Session.setCameraTextureName(). */
    fun draw(oesTextureId: Int) {
        GLES30.glDisable(GLES30.GL_DEPTH_TEST)
        GLES30.glDepthMask(false)

        GLES30.glUseProgram(program)
        GLES30.glActiveTexture(GLES30.GL_TEXTURE0)
        GLES30.glBindTexture(0x8D65 /*GL_TEXTURE_EXTERNAL_OES*/, oesTextureId)
        GLES30.glUniform1i(textureUniform, 0)

        GLES30.glBindVertexArray(quadVAO)
        GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, 6)
        GLES30.glBindVertexArray(0)

        GLES30.glDepthMask(true)
        GLES30.glEnable(GLES30.GL_DEPTH_TEST)
        ShaderUtil.checkGLError("CameraBackgroundRenderer.draw")
    }

    fun release() {
        if (program != 0) { GLES30.glDeleteProgram(program); program = 0 }
        if (quadVAO != 0) { GLES30.glDeleteVertexArrays(1, intArrayOf(quadVAO), 0); quadVAO = 0 }
        if (quadVBO != 0) { GLES30.glDeleteBuffers(1, intArrayOf(quadVBO), 0);      quadVBO = 0 }
    }
}

// ─── PBR object renderer ──────────────────────────────────────────────────────

object PBRShaders {
    val VERT = """
        #version 300 es
        uniform mat4 u_MVP;
        uniform mat4 u_Model;
        uniform mat3 u_NormalMatrix;
        layout(location = 0) in vec4 a_Position;
        layout(location = 1) in vec3 a_Normal;
        layout(location = 2) in vec2 a_TexCoord;
        out vec3 v_WorldPos;
        out vec3 v_Normal;
        out vec2 v_TexCoord;
        void main() {
            vec4 worldPos = u_Model * a_Position;
            v_WorldPos  = worldPos.xyz;
            v_Normal    = normalize(u_NormalMatrix * a_Normal);
            v_TexCoord  = a_TexCoord;
            gl_Position = u_MVP * a_Position;
        }
    """.trimIndent()

    val FRAG = """
        #version 300 es
        precision highp float;
        const float PI = 3.14159265359;

        uniform vec3  u_BaseColor;
        uniform float u_Metallic;
        uniform float u_Roughness;
        uniform float u_AmbientOcclusion;
        uniform vec3  u_CameraPos;
        uniform vec3  u_LightDir;
        uniform vec3  u_LightColor;
        uniform float u_LightIntensity;
        uniform float u_Opacity;
        uniform bool  u_UseBaseColorTexture;
        uniform bool  u_Unlit;
        uniform bool  u_FrontOnly;
        uniform sampler2D u_BaseColorTexture;
        uniform vec4  u_BaseColorUvTransform;

        in vec3 v_WorldPos;
        in vec3 v_Normal;
        in vec2 v_TexCoord;
        out vec4 o_FragColor;

        // GGX Normal Distribution
        float D_GGX(float NdotH, float roughness) {
            float a   = roughness * roughness;
            float a2  = a * a;
            float d   = NdotH * NdotH * (a2 - 1.0) + 1.0;
            return a2 / (PI * d * d);
        }

        // Smith-GGX Geometry
        float G_SmithGGX(float NdotV, float NdotL, float roughness) {
            float r  = roughness + 1.0;
            float k  = (r * r) / 8.0;
            float gv = NdotV / (NdotV * (1.0 - k) + k);
            float gl = NdotL / (NdotL * (1.0 - k) + k);
            return gv * gl;
        }

        // Fresnel-Schlick
        vec3 F_Schlick(float cosTheta, vec3 F0) {
            return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
        }

        void main() {
            vec2 baseColorUv = v_TexCoord * u_BaseColorUvTransform.xy + u_BaseColorUvTransform.zw;
            vec4 textureColor = u_UseBaseColorTexture
                ? texture(u_BaseColorTexture, baseColorUv)
                : vec4(1.0);
            float opacity = u_Opacity * textureColor.a;
            if (opacity <= 0.01) {
                discard;
            }
            vec3 baseColor = clamp(u_BaseColor * textureColor.rgb, 0.0, 1.0);
            vec3  N   = normalize(v_Normal);
            vec3  V   = normalize(u_CameraPos - v_WorldPos);
            if (u_FrontOnly && dot(N, V) <= 0.02) {
                discard;
            }
            if (u_Unlit) {
                o_FragColor = vec4(baseColor, opacity);
                return;
            }
            vec3  L   = normalize(-u_LightDir);
            vec3  H   = normalize(V + L);

            float NdotL = max(dot(N, L), 0.0);
            float NdotV = max(dot(N, V), 0.001);
            float NdotH = max(dot(N, H), 0.0);
            float HdotV = max(dot(H, V), 0.0);

            vec3 F0 = mix(vec3(0.04), baseColor, u_Metallic);

            float D = D_GGX(NdotH, u_Roughness);
            float G = G_SmithGGX(NdotV, NdotL, u_Roughness);
            vec3  F = F_Schlick(HdotV, F0);

            vec3 specular = (D * G * F) / max(4.0 * NdotV * NdotL, 0.001);
            vec3 kd       = (1.0 - F) * (1.0 - u_Metallic);
            vec3 diffuse  = kd * baseColor / PI;

            vec3 radiance = u_LightColor * u_LightIntensity;
            vec3 Lo       = (diffuse + specular) * radiance * NdotL;

            // Ambient IBL approximation
            vec3 ambient  = vec3(0.03) * baseColor * u_AmbientOcclusion;
            vec3 color    = ambient + Lo;

            // Tone-mapping (ACES filmic)
            color = (color * (2.51 * color + 0.03)) / (color * (2.43 * color + 0.59) + 0.14);
            color = clamp(color, 0.0, 1.0);

            o_FragColor = vec4(color, opacity);
        }
    """.trimIndent()
}

class PBRObjectRenderer {
    private var program       = 0
    private var mvpUniform    = 0
    private var modelUniform  = 0
    private var normalMatUnif = 0
    private var baseColorUnif = 0
    private var metallicUnif  = 0
    private var roughnessUnif = 0
    private var aoUnif        = 0
    private var camPosUnif    = 0
    private var lightDirUnif  = 0
    private var lightColUnif  = 0
    private var lightIntUnif  = 0
    private var opacityUnif   = 0
    private var useTexUnif    = 0
    private var unlitUnif     = 0
    private var frontOnlyUnif = 0
    private var texUnif       = 0
    private var uvXformUnif   = 0

    fun init() {
        program       = ShaderUtil.linkProgram(PBRShaders.VERT, PBRShaders.FRAG)
        mvpUniform    = GLES30.glGetUniformLocation(program, "u_MVP")
        modelUniform  = GLES30.glGetUniformLocation(program, "u_Model")
        normalMatUnif = GLES30.glGetUniformLocation(program, "u_NormalMatrix")
        baseColorUnif = GLES30.glGetUniformLocation(program, "u_BaseColor")
        metallicUnif  = GLES30.glGetUniformLocation(program, "u_Metallic")
        roughnessUnif = GLES30.glGetUniformLocation(program, "u_Roughness")
        aoUnif        = GLES30.glGetUniformLocation(program, "u_AmbientOcclusion")
        camPosUnif    = GLES30.glGetUniformLocation(program, "u_CameraPos")
        lightDirUnif  = GLES30.glGetUniformLocation(program, "u_LightDir")
        lightColUnif  = GLES30.glGetUniformLocation(program, "u_LightColor")
        lightIntUnif  = GLES30.glGetUniformLocation(program, "u_LightIntensity")
        opacityUnif   = GLES30.glGetUniformLocation(program, "u_Opacity")
        useTexUnif    = GLES30.glGetUniformLocation(program, "u_UseBaseColorTexture")
        unlitUnif     = GLES30.glGetUniformLocation(program, "u_Unlit")
        frontOnlyUnif = GLES30.glGetUniformLocation(program, "u_FrontOnly")
        texUnif       = GLES30.glGetUniformLocation(program, "u_BaseColorTexture")
        uvXformUnif   = GLES30.glGetUniformLocation(program, "u_BaseColorUvTransform")
        ShaderUtil.checkGLError("PBRObjectRenderer.init")
    }

    fun drawMesh(
        mesh: GPUMesh,
        modelMatrix: FloatArray,     // 16 floats col-major
        viewProjMatrix: FloatArray,  // 16 floats col-major
        camPos: FloatArray,          // 3 floats
        baseColor: FloatArray,       // 3 floats RGB
        metallic: Float,
        roughness: Float,
        opacity: Float = 1f,
        doubleSided: Boolean = false,
        baseColorTextureId: Int? = null,
        baseColorUvTransform: FloatArray = floatArrayOf(1f, 1f, 0f, 0f),
        unlit: Boolean = false,
        frontOnly: Boolean = false,
        lightDir: FloatArray  = floatArrayOf(0f, -1f, -0.5f),
        lightCol: FloatArray  = floatArrayOf(1f,  1f,  0.98f),
        lightInt: Float       = 1.2f,
    ) {
        GLES30.glEnable(GLES30.GL_DEPTH_TEST)
        GLES30.glDepthFunc(GLES30.GL_LESS)
        val cullWasEnabled = GLES30.glIsEnabled(GLES30.GL_CULL_FACE)
        if (doubleSided) {
            GLES30.glDisable(GLES30.GL_CULL_FACE)
        }

        if (opacity < 1f) {
            GLES30.glEnable(GLES30.GL_BLEND)
            GLES30.glBlendFunc(GLES30.GL_SRC_ALPHA, GLES30.GL_ONE_MINUS_SRC_ALPHA)
        }

        GLES30.glUseProgram(program)

        // MVP = viewProj * model
        val mvp = FloatArray(16)
        Matrix.multiplyMM(mvp, 0, viewProjMatrix, 0, modelMatrix, 0)
        GLES30.glUniformMatrix4fv(mvpUniform,   1, false, mvp,        0)
        GLES30.glUniformMatrix4fv(modelUniform, 1, false, modelMatrix,0)

        // Normal matrix = transpose(inverse(upper-left 3x3 of model))
        val nm = normalMatrix3x3(modelMatrix)
        GLES30.glUniformMatrix3fv(normalMatUnif, 1, false, nm, 0)

        GLES30.glUniform3fv(baseColorUnif, 1, baseColor, 0)
        GLES30.glUniform1f(metallicUnif, metallic)
        GLES30.glUniform1f(roughnessUnif, roughness)
        GLES30.glUniform1f(aoUnif, 1f)
        GLES30.glUniform3fv(camPosUnif,  1, camPos,   0)
        GLES30.glUniform3fv(lightDirUnif,1, lightDir, 0)
        GLES30.glUniform3fv(lightColUnif,1, lightCol, 0)
        GLES30.glUniform1f(lightIntUnif, lightInt)
        GLES30.glUniform1f(opacityUnif,  opacity)
        GLES30.glUniform1i(unlitUnif, if (unlit) 1 else 0)
        GLES30.glUniform1i(frontOnlyUnif, if (frontOnly) 1 else 0)
        if (baseColorTextureId != null && baseColorTextureId != 0) {
            GLES30.glActiveTexture(GLES30.GL_TEXTURE1)
            GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, baseColorTextureId)
            GLES30.glUniform1i(texUnif, 1)
            GLES30.glUniform1i(useTexUnif, 1)
        } else {
            GLES30.glUniform1i(useTexUnif, 0)
        }
        GLES30.glUniform4fv(uvXformUnif, 1, baseColorUvTransform, 0)

        GLES30.glBindVertexArray(mesh.vao)
        if (mesh.indexCount > 0) {
            GLES30.glDrawElements(GLES30.GL_TRIANGLES, mesh.indexCount,
                GLES30.GL_UNSIGNED_INT, 0)
        } else {
            GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, mesh.vertexCount)
        }
        GLES30.glBindVertexArray(0)
        if (baseColorTextureId != null && baseColorTextureId != 0) {
            GLES30.glActiveTexture(GLES30.GL_TEXTURE1)
            GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, 0)
        }

        if (opacity < 1f) GLES30.glDisable(GLES30.GL_BLEND)
        if (doubleSided && cullWasEnabled) {
            GLES30.glEnable(GLES30.GL_CULL_FACE)
        }
        ShaderUtil.checkGLError("PBRObjectRenderer.draw")
    }

    fun release() {
        if (program != 0) { GLES30.glDeleteProgram(program); program = 0 }
    }

    // Compute the 3×3 normal matrix from a 4×4 model matrix (column-major).
    private fun normalMatrix3x3(m: FloatArray): FloatArray {
        // Extract upper-left 3x3, invert, transpose
        val a00=m[0]; val a01=m[4]; val a02=m[8]
        val a10=m[1]; val a11=m[5]; val a12=m[9]
        val a20=m[2]; val a21=m[6]; val a22=m[10]
        val det = a00*(a11*a22-a12*a21) - a01*(a10*a22-a12*a20) + a02*(a10*a21-a11*a20)
        val inv = if (det.isNaN() || det == 0f) 1f else 1f / det
        return floatArrayOf(
            (a11*a22-a12*a21)*inv, (a02*a21-a01*a22)*inv, (a01*a12-a02*a11)*inv,
            (a12*a20-a10*a22)*inv, (a00*a22-a02*a20)*inv, (a02*a10-a00*a12)*inv,
            (a10*a21-a11*a20)*inv, (a01*a20-a00*a21)*inv, (a00*a11-a01*a10)*inv,
        )
    }
}

data class GLTextureInfo(
    val id: Int,
    val width: Int,
    val height: Int,
)

object TextureCache {
    private val textures = mutableMapOf<String, GLTextureInfo>()

    fun getOrCreate(key: String, bytes: ByteArray): GLTextureInfo? {
        textures[key]?.let { return it }
        if (bytes.isEmpty()) return null

        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
        val bitmap = applyExifOrientation(decoded, bytes)
        try {
            val textureIds = IntArray(1)
            GLES30.glGenTextures(1, textureIds, 0)
            val textureId = textureIds[0]
            GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textureId)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)
            GLUtils.texImage2D(GLES30.GL_TEXTURE_2D, 0, bitmap, 0)
            GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, 0)
            ShaderUtil.checkGLError("TextureCache.getOrCreate")

            val info = GLTextureInfo(textureId, bitmap.width, bitmap.height)
            textures[key] = info
            return info
        } finally {
            bitmap.recycle()
        }
    }

    private fun applyExifOrientation(source: Bitmap, bytes: ByteArray): Bitmap {
        val orientation = try {
            ByteArrayInputStream(bytes).use { input ->
                ExifInterface(input).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )
            }
        } catch (_: Exception) {
            ExifInterface.ORIENTATION_NORMAL
        }

        val matrix = GraphicsMatrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> {
                matrix.postRotate(180f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.postRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.postRotate(270f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            else -> return source
        }

        val oriented = Bitmap.createBitmap(
            source,
            0,
            0,
            source.width,
            source.height,
            matrix,
            true,
        )
        if (oriented !== source) {
            source.recycle()
        }
        return oriented
    }

    fun releaseAll() {
        for (texture in textures.values) {
            if (texture.id != 0) {
                GLES30.glDeleteTextures(1, intArrayOf(texture.id), 0)
            }
        }
        textures.clear()
    }
}

// ─── Plane renderer ───────────────────────────────────────────────────────────

object PlaneShaders {
    val VERT = """
        #version 300 es
        uniform mat4 u_VP;
        uniform mat4 u_Model;
        layout(location = 0) in vec4 a_Position;
        layout(location = 2) in vec2 a_TexCoord;
        out vec2 v_TexCoord;
        out float v_Alpha;
        void main() {
            v_TexCoord  = a_TexCoord;
            // Fade edges
            float dist = length(a_TexCoord - vec2(0.5));
            v_Alpha = 1.0 - smoothstep(0.35, 0.5, dist);
            gl_Position = u_VP * u_Model * a_Position;
        }
    """.trimIndent()

    val FRAG = """
        #version 300 es
        precision mediump float;
        uniform vec4 u_Color;
        in vec2  v_TexCoord;
        in float v_Alpha;
        out vec4 o_FragColor;
        void main() {
            // Grid lines
            vec2 grid = abs(fract(v_TexCoord * 10.0) - 0.5);
            float line = min(grid.x, grid.y);
            float alpha = (1.0 - smoothstep(0.0, 0.05, line)) * 0.5 + 0.1;
            o_FragColor = vec4(u_Color.rgb, alpha * v_Alpha * u_Color.a);
        }
    """.trimIndent()
}

class PlaneRenderer {
    private var program    = 0
    private var vpUniform  = 0
    private var mdlUniform = 0
    private var colUniform = 0

    // Filled quad mesh uploaded once
    private var planeMesh: GPUMesh? = null

    fun init() {
        program    = ShaderUtil.linkProgram(PlaneShaders.VERT, PlaneShaders.FRAG)
        vpUniform  = GLES30.glGetUniformLocation(program, "u_VP")
        mdlUniform = GLES30.glGetUniformLocation(program, "u_Model")
        colUniform = GLES30.glGetUniformLocation(program, "u_Color")
        planeMesh  = GPUMesh.createQuad(1f, 1f)
        ShaderUtil.checkGLError("PlaneRenderer.init")
    }

    fun draw(
        viewProjMatrix: FloatArray,
        modelMatrix: FloatArray,
        r: Float = 0f, g: Float = 0.85f, b: Float = 1f, a: Float = 0.6f,
    ) {
        val mesh = planeMesh ?: return
        GLES30.glEnable(GLES30.GL_BLEND)
        GLES30.glBlendFunc(GLES30.GL_SRC_ALPHA, GLES30.GL_ONE_MINUS_SRC_ALPHA)
        GLES30.glDisable(GLES30.GL_CULL_FACE)
        GLES30.glDepthMask(false)

        GLES30.glUseProgram(program)
        GLES30.glUniformMatrix4fv(vpUniform,  1, false, viewProjMatrix, 0)
        GLES30.glUniformMatrix4fv(mdlUniform, 1, false, modelMatrix,    0)
        GLES30.glUniform4f(colUniform, r, g, b, a)

        GLES30.glBindVertexArray(mesh.vao)
        GLES30.glDrawElements(GLES30.GL_TRIANGLES, mesh.indexCount, GLES30.GL_UNSIGNED_INT, 0)
        GLES30.glBindVertexArray(0)

        GLES30.glDepthMask(true)
        GLES30.glEnable(GLES30.GL_CULL_FACE)
        GLES30.glDisable(GLES30.GL_BLEND)
    }

    fun release() {
        if (program != 0) { GLES30.glDeleteProgram(program); program = 0 }
        planeMesh?.release(); planeMesh = null
    }
}

// ─── Shadow map renderer ──────────────────────────────────────────────────────

class ShadowMapRenderer(private val size: Int = 1024) {
    var fbo         = 0; private set
    var depthTex    = 0; private set
    var lightSpaceMatrix = FloatArray(16); private set

    fun init() {
        val fbos = IntArray(1); GLES30.glGenFramebuffers(1, fbos, 0); fbo = fbos[0]
        val texs = IntArray(1); GLES30.glGenTextures(1, texs, 0);     depthTex = texs[0]

        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, depthTex)
        GLES30.glTexImage2D(GLES30.GL_TEXTURE_2D, 0, GLES30.GL_DEPTH_COMPONENT32F,
            size, size, 0, GLES30.GL_DEPTH_COMPONENT, GLES30.GL_FLOAT, null)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_NEAREST)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_NEAREST)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)

        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, fbo)
        GLES30.glFramebufferTexture2D(GLES30.GL_FRAMEBUFFER, GLES30.GL_DEPTH_ATTACHMENT,
            GLES30.GL_TEXTURE_2D, depthTex, 0)
        GLES30.glDrawBuffers(1, intArrayOf(GLES30.GL_NONE), 0)
        GLES30.glReadBuffer(GLES30.GL_NONE)
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0)
        ShaderUtil.checkGLError("ShadowMapRenderer.init")
    }

    fun beginShadowPass(lightDirWorld: FloatArray, sceneCentre: FloatArray) {
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, fbo)
        GLES30.glViewport(0, 0, size, size)
        GLES30.glClear(GLES30.GL_DEPTH_BUFFER_BIT)

        // Orthographic projection from light's perspective
        val lightView  = FloatArray(16)
        val lightProj  = FloatArray(16)
        val eye = floatArrayOf(
            sceneCentre[0] - lightDirWorld[0] * 5f,
            sceneCentre[1] - lightDirWorld[1] * 5f,
            sceneCentre[2] - lightDirWorld[2] * 5f,
        )
        Matrix.setLookAtM(lightView, 0,
            eye[0], eye[1], eye[2],
            sceneCentre[0], sceneCentre[1], sceneCentre[2],
            0f, 1f, 0f)
        Matrix.orthoM(lightProj, 0, -3f, 3f, -3f, 3f, 0.1f, 50f)
        Matrix.multiplyMM(lightSpaceMatrix, 0, lightProj, 0, lightView, 0)
    }

    fun endShadowPass(viewportW: Int, viewportH: Int) {
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0)
        GLES30.glViewport(0, 0, viewportW, viewportH)
    }

    fun release() {
        if (fbo      != 0) { GLES30.glDeleteFramebuffers(1, intArrayOf(fbo), 0);      fbo = 0 }
        if (depthTex != 0) { GLES30.glDeleteTextures(1, intArrayOf(depthTex), 0);     depthTex = 0 }
    }
}

// ─── GPU mesh ─────────────────────────────────────────────────────────────────

/** Holds a VAO + VBO + optional EBO for a single mesh. */
class GPUMesh(val vao: Int, val vbo: Int, val ebo: Int,
               val vertexCount: Int, val indexCount: Int) {

    companion object {
        /** Interleaved layout: [px py pz nx ny nz s t] */
        fun upload(vertices: FloatArray, indices: IntArray? = null): GPUMesh {
            val vaos = IntArray(1); GLES30.glGenVertexArrays(1, vaos, 0)
            val vbos = IntArray(1); GLES30.glGenBuffers(1, vbos, 0)
            var ebo  = 0

            GLES30.glBindVertexArray(vaos[0])
            GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, vbos[0])

            val buf = ByteBuffer.allocateDirect(vertices.size * 4)
                .order(ByteOrder.nativeOrder()).asFloatBuffer()
            buf.put(vertices).position(0)
            GLES30.glBufferData(GLES30.GL_ARRAY_BUFFER, vertices.size * 4, buf, GLES30.GL_STATIC_DRAW)

            val stride = 8 * 4
            // position (location 0)
            GLES30.glEnableVertexAttribArray(0)
            GLES30.glVertexAttribPointer(0, 3, GLES30.GL_FLOAT, false, stride, 0)
            // normal (location 1)
            GLES30.glEnableVertexAttribArray(1)
            GLES30.glVertexAttribPointer(1, 3, GLES30.GL_FLOAT, false, stride, 3 * 4)
            // uv (location 2)
            GLES30.glEnableVertexAttribArray(2)
            GLES30.glVertexAttribPointer(2, 2, GLES30.GL_FLOAT, false, stride, 6 * 4)

            var indexCount = 0
            if (indices != null) {
                val ebos = IntArray(1); GLES30.glGenBuffers(1, ebos, 0); ebo = ebos[0]
                val ibuf = ByteBuffer.allocateDirect(indices.size * 4)
                    .order(ByteOrder.nativeOrder()).asIntBuffer()
                ibuf.put(indices).position(0)
                GLES30.glBindBuffer(GLES30.GL_ELEMENT_ARRAY_BUFFER, ebo)
                GLES30.glBufferData(GLES30.GL_ELEMENT_ARRAY_BUFFER,
                    indices.size * 4, ibuf, GLES30.GL_STATIC_DRAW)
                indexCount = indices.size
            }

            GLES30.glBindVertexArray(0)
            ShaderUtil.checkGLError("GPUMesh.upload")
            return GPUMesh(vaos[0], vbos[0], ebo,
                vertices.size / 8, indexCount)
        }

        /** Unit cube centred at origin. */
        fun createCube(): GPUMesh {
            // 24 vertices (4 per face × 6 faces), interleaved [pos, normal, uv]
            val v = mutableListOf<Float>()
            data class Face(val n: FloatArray, val verts: Array<FloatArray>)
            val faces = listOf(
                Face(floatArrayOf( 0f, 0f, 1f), arrayOf(
                    floatArrayOf(-0.5f,-0.5f, 0.5f), floatArrayOf( 0.5f,-0.5f, 0.5f),
                    floatArrayOf( 0.5f, 0.5f, 0.5f), floatArrayOf(-0.5f, 0.5f, 0.5f))),
                Face(floatArrayOf( 0f, 0f,-1f), arrayOf(
                    floatArrayOf( 0.5f,-0.5f,-0.5f), floatArrayOf(-0.5f,-0.5f,-0.5f),
                    floatArrayOf(-0.5f, 0.5f,-0.5f), floatArrayOf( 0.5f, 0.5f,-0.5f))),
                Face(floatArrayOf( 0f, 1f, 0f), arrayOf(
                    floatArrayOf(-0.5f, 0.5f,-0.5f), floatArrayOf(-0.5f, 0.5f, 0.5f),
                    floatArrayOf( 0.5f, 0.5f, 0.5f), floatArrayOf( 0.5f, 0.5f,-0.5f))),
                Face(floatArrayOf( 0f,-1f, 0f), arrayOf(
                    floatArrayOf(-0.5f,-0.5f,-0.5f), floatArrayOf( 0.5f,-0.5f,-0.5f),
                    floatArrayOf( 0.5f,-0.5f, 0.5f), floatArrayOf(-0.5f,-0.5f, 0.5f))),
                Face(floatArrayOf( 1f, 0f, 0f), arrayOf(
                    floatArrayOf( 0.5f,-0.5f, 0.5f), floatArrayOf( 0.5f,-0.5f,-0.5f),
                    floatArrayOf( 0.5f, 0.5f,-0.5f), floatArrayOf( 0.5f, 0.5f, 0.5f))),
                Face(floatArrayOf(-1f, 0f, 0f), arrayOf(
                    floatArrayOf(-0.5f,-0.5f,-0.5f), floatArrayOf(-0.5f,-0.5f, 0.5f),
                    floatArrayOf(-0.5f, 0.5f, 0.5f), floatArrayOf(-0.5f, 0.5f,-0.5f))),
            )
            val uvs = arrayOf(floatArrayOf(0f,0f), floatArrayOf(1f,0f),
                              floatArrayOf(1f,1f), floatArrayOf(0f,1f))
            val indices = mutableListOf<Int>()
            faces.forEachIndexed { fi, face ->
                val base = fi * 4
                face.verts.forEachIndexed { vi, vert ->
                    v.addAll(vert.toList())
                    v.addAll(face.n.toList())
                    v.addAll(uvs[vi].toList())
                }
                indices.addAll(listOf(base,base+1,base+2, base,base+2,base+3))
            }
            return upload(v.toFloatArray(), indices.toIntArray())
        }

        /** UV sphere with [stacks] latitude rings and [slices] longitude segments. */
        fun createSphere(radius: Float = 0.5f, stacks: Int = 16, slices: Int = 32): GPUMesh {
            val verts = mutableListOf<Float>()
            val indices = mutableListOf<Int>()
            for (s in 0..stacks) {
                val phi = Math.PI * s / stacks
                for (sl in 0..slices) {
                    val theta = 2 * Math.PI * sl / slices
                    val x = (Math.sin(phi) * Math.cos(theta)).toFloat()
                    val y = Math.cos(phi).toFloat()
                    val z = (Math.sin(phi) * Math.sin(theta)).toFloat()
                    verts.addAll(listOf(x*radius, y*radius, z*radius, x, y, z,
                        sl.toFloat()/slices, s.toFloat()/stacks))
                }
            }
            for (s in 0 until stacks) {
                for (sl in 0 until slices) {
                    val a = s * (slices+1) + sl
                    val b = a + slices + 1
                    indices.addAll(listOf(a,b,a+1, b,b+1,a+1))
                }
            }
            return upload(verts.toFloatArray(), indices.toIntArray())
        }

        /** Flat quad in the XZ plane (for planes). */
        fun createQuad(w: Float = 1f, h: Float = 1f): GPUMesh {
            val hw = w/2; val hh = h/2
            val verts = floatArrayOf(
                -hw, 0f, -hh,  0f,1f,0f,  0f,0f,
                 hw, 0f, -hh,  0f,1f,0f,  1f,0f,
                 hw, 0f,  hh,  0f,1f,0f,  1f,1f,
                -hw, 0f,  hh,  0f,1f,0f,  0f,1f,
            )
            return upload(verts, intArrayOf(0,1,2, 0,2,3))
        }

        /**
         * A physical photo-frame ring in local space:
         * X = width, Z = height, Y = front/back depth.
         *
         * The front opening is wider than the photo so the face slopes inward,
         * creating a visible recessed lip instead of a flat painted rectangle.
         */
        fun createPhotoFrameRing(
            outerWidth: Float,
            outerHeight: Float,
            photoWidth: Float,
            photoHeight: Float,
            depth: Float,
            recess: Float,
        ): GPUMesh {
            val verts = mutableListOf<Float>()
            val ow = outerWidth.coerceAtLeast(0.12f)
            val oh = outerHeight.coerceAtLeast(0.12f)
            val pw = photoWidth.coerceIn(0.04f, ow - 0.02f)
            val ph = photoHeight.coerceIn(0.04f, oh - 0.02f)
            val borderX = ((ow - pw) / 2f).coerceAtLeast(0.01f)
            val borderZ = ((oh - ph) / 2f).coerceAtLeast(0.01f)
            val bevelX = (borderX * 0.48f).coerceIn(0.012f, 0.045f)
            val bevelZ = (borderZ * 0.48f).coerceIn(0.012f, 0.045f)
            val frontInnerWidth = (pw + bevelX * 2f).coerceAtMost(ow - 0.012f)
            val frontInnerHeight = (ph + bevelZ * 2f).coerceAtMost(oh - 0.012f)
            val yFront = depth / 2f
            val yBack = -depth / 2f
            val yPhoto = (yFront - recess).coerceIn(yBack + 0.006f, yFront - 0.006f)

            fun addVertex(p: FloatArray, n: FloatArray, u: Float, v: Float) {
                verts.addAll(listOf(p[0], p[1], p[2], n[0], n[1], n[2], u, v))
            }

            fun addQuad(
                p0: FloatArray,
                p1: FloatArray,
                p2: FloatArray,
                p3: FloatArray,
                n: FloatArray,
            ) {
                addVertex(p0, n, 0f, 0f)
                addVertex(p1, n, 1f, 0f)
                addVertex(p2, n, 1f, 1f)
                addVertex(p0, n, 0f, 0f)
                addVertex(p2, n, 1f, 1f)
                addVertex(p3, n, 0f, 1f)
            }

            fun rectRing(
                y: Float,
                innerWidth: Float,
                innerHeight: Float,
                normal: FloatArray,
            ) {
                val x0 = -ow / 2f; val x1 = ow / 2f
                val z0 = -oh / 2f; val z1 = oh / 2f
                val ix0 = -innerWidth / 2f; val ix1 = innerWidth / 2f
                val iz0 = -innerHeight / 2f; val iz1 = innerHeight / 2f
                addQuad(floatArrayOf(x0,y,iz1), floatArrayOf(x1,y,iz1), floatArrayOf(x1,y,z1), floatArrayOf(x0,y,z1), normal)
                addQuad(floatArrayOf(x0,y,z0), floatArrayOf(x1,y,z0), floatArrayOf(x1,y,iz0), floatArrayOf(x0,y,iz0), normal)
                addQuad(floatArrayOf(x0,y,iz0), floatArrayOf(ix0,y,iz0), floatArrayOf(ix0,y,iz1), floatArrayOf(x0,y,iz1), normal)
                addQuad(floatArrayOf(ix1,y,iz0), floatArrayOf(x1,y,iz0), floatArrayOf(x1,y,iz1), floatArrayOf(ix1,y,iz1), normal)
            }

            rectRing(yFront, frontInnerWidth, frontInnerHeight, floatArrayOf(0f, 1f, 0f))
            rectRing(yBack, pw, ph, floatArrayOf(0f, -1f, 0f))

            val x0 = -ow / 2f; val x1 = ow / 2f
            val z0 = -oh / 2f; val z1 = oh / 2f
            addQuad(floatArrayOf(x0,yBack,z1), floatArrayOf(x1,yBack,z1), floatArrayOf(x1,yFront,z1), floatArrayOf(x0,yFront,z1), floatArrayOf(0f,0f,1f))
            addQuad(floatArrayOf(x1,yBack,z0), floatArrayOf(x0,yBack,z0), floatArrayOf(x0,yFront,z0), floatArrayOf(x1,yFront,z0), floatArrayOf(0f,0f,-1f))
            addQuad(floatArrayOf(x0,yBack,z0), floatArrayOf(x0,yBack,z1), floatArrayOf(x0,yFront,z1), floatArrayOf(x0,yFront,z0), floatArrayOf(-1f,0f,0f))
            addQuad(floatArrayOf(x1,yBack,z1), floatArrayOf(x1,yBack,z0), floatArrayOf(x1,yFront,z0), floatArrayOf(x1,yFront,z1), floatArrayOf(1f,0f,0f))

            val fx0 = -frontInnerWidth / 2f; val fx1 = frontInnerWidth / 2f
            val fz0 = -frontInnerHeight / 2f; val fz1 = frontInnerHeight / 2f
            val px0 = -pw / 2f; val px1 = pw / 2f
            val pz0 = -ph / 2f; val pz1 = ph / 2f
            addQuad(floatArrayOf(fx0,yFront,fz1), floatArrayOf(fx1,yFront,fz1), floatArrayOf(px1,yPhoto,pz1), floatArrayOf(px0,yPhoto,pz1), floatArrayOf(0f,0.58f,-0.82f))
            addQuad(floatArrayOf(fx1,yFront,fz0), floatArrayOf(fx0,yFront,fz0), floatArrayOf(px0,yPhoto,pz0), floatArrayOf(px1,yPhoto,pz0), floatArrayOf(0f,0.58f,0.82f))
            addQuad(floatArrayOf(fx0,yFront,fz0), floatArrayOf(fx0,yFront,fz1), floatArrayOf(px0,yPhoto,pz1), floatArrayOf(px0,yPhoto,pz0), floatArrayOf(0.82f,0.58f,0f))
            addQuad(floatArrayOf(fx1,yFront,fz1), floatArrayOf(fx1,yFront,fz0), floatArrayOf(px1,yPhoto,pz0), floatArrayOf(px1,yPhoto,pz1), floatArrayOf(-0.82f,0.58f,0f))

            return upload(verts.toFloatArray())
        }

        /** Cylinder along Y axis. */
        fun createCylinder(radius: Float=0.5f, height: Float=1f, segs: Int=32): GPUMesh {
            val verts = mutableListOf<Float>()
            val indices = mutableListOf<Int>()
            val h2 = height / 2
            for (i in 0..segs) {
                val theta = 2 * Math.PI * i / segs
                val x = Math.cos(theta).toFloat() * radius
                val z = Math.sin(theta).toFloat() * radius
                val u = i.toFloat() / segs
                // top ring
                verts.addAll(listOf(x, h2, z, x/radius, 0f, z/radius, u, 0f))
                // bottom ring
                verts.addAll(listOf(x,-h2, z, x/radius, 0f, z/radius, u, 1f))
            }
            for (i in 0 until segs) {
                val a = i*2; val b = a+1; val c = a+2; val d = a+3
                indices.addAll(listOf(a,b,c, b,d,c))
            }
            return upload(verts.toFloatArray(), indices.toIntArray())
        }
    }

    fun release() {
        if (vao != 0) GLES30.glDeleteVertexArrays(1, intArrayOf(vao), 0)
        if (vbo != 0) GLES30.glDeleteBuffers(1, intArrayOf(vbo), 0)
        if (ebo != 0) GLES30.glDeleteBuffers(1, intArrayOf(ebo), 0)
    }
}

// ─── Mesh cache ───────────────────────────────────────────────────────────────

object MeshCache {
    private val cache = mutableMapOf<String, GPUMesh>()

    fun get(shape: String): GPUMesh = cache.getOrPut(shape) {
        when (shape) {
            "sphere"   -> GPUMesh.createSphere()
            "cylinder" -> GPUMesh.createCylinder()
            "plane"    -> GPUMesh.createQuad()
            else       -> GPUMesh.createCube()
        }
    }

    fun getPhotoFrameRing(
        outerWidth: Float,
        outerHeight: Float,
        photoWidth: Float,
        photoHeight: Float,
        depth: Float,
        recess: Float,
    ): GPUMesh {
        val key = listOf(
            "photo_frame_ring",
            (outerWidth * 1000f).toInt(),
            (outerHeight * 1000f).toInt(),
            (photoWidth * 1000f).toInt(),
            (photoHeight * 1000f).toInt(),
            (depth * 1000f).toInt(),
            (recess * 1000f).toInt(),
        ).joinToString(":")
        return cache.getOrPut(key) {
            GPUMesh.createPhotoFrameRing(
                outerWidth = outerWidth,
                outerHeight = outerHeight,
                photoWidth = photoWidth,
                photoHeight = photoHeight,
                depth = depth,
                recess = recess,
            )
        }
    }

    fun releaseAll() { cache.values.forEach { it.release() }; cache.clear() }
}
