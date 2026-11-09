package com.arengine.ar_engine.gl

import android.util.Log
import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader
import kotlin.math.sqrt

private const val MODEL_MESH_TAG = "ModelMeshCache"

object ModelMeshCache {
    private val cache = mutableMapOf<String, GPUMesh>()
    private val failedKeys = mutableSetOf<String>()

    fun getOrNull(
        nodeMap: Map<*, *>,
        openInputStream: (Map<*, *>, String) -> InputStream?,
    ): GPUMesh? {
        val format = modelFormat(nodeMap) ?: return null
        if (format != "obj") return null

        val path = stringValue(nodeMap, "modelAssetResolvedPath")
            ?: stringValue(nodeMap, "modelPath")
            ?: return null
        val centerOrigin = modelAsset(nodeMap)?.get("centerOrigin") as? Boolean ?: true
        val key = "obj:$centerOrigin:$path"

        cache[key]?.let { return it }
        if (failedKeys.contains(key)) return null

        return try {
            val mesh = openInputStream(nodeMap, path)?.use {
                ObjMeshParser.parse(it, centerOrigin = centerOrigin)
            }
            if (mesh == null) {
                failedKeys += key
                null
            } else {
                cache[key] = mesh
                mesh
            }
        } catch (e: Exception) {
            failedKeys += key
            Log.w(MODEL_MESH_TAG, "Unable to load OBJ model: $path", e)
            null
        }
    }

    fun releaseAll() {
        cache.values.forEach { it.release() }
        cache.clear()
        failedKeys.clear()
    }

    private fun modelFormat(nodeMap: Map<*, *>): String? {
        val asset = modelAsset(nodeMap)
        val explicitFormat = stringValue(asset, "format")
        if (explicitFormat != null && explicitFormat != "custom") {
            return explicitFormat
        }

        val inferredFormat = inferFormat(
            stringValue(asset, "path")
                ?: stringValue(nodeMap, "modelPath")
                ?: stringValue(nodeMap, "modelAssetResolvedPath"),
        )
        if (inferredFormat != null) return inferredFormat

        return stringValue(nodeMap, "contentType")?.takeIf { it != "primitive" }
    }

    private fun modelAsset(nodeMap: Map<*, *>): Map<*, *>? =
        nodeMap["modelAsset"] as? Map<*, *>

    private fun inferFormat(path: String?): String? {
        if (path == null) return null
        return path.substringBefore('?').substringAfterLast('.', "").lowercase()
            .takeIf { it.isNotEmpty() }
    }

    private fun stringValue(map: Map<*, *>?, key: String): String? {
        val value = map?.get(key) as? String ?: return null
        return value.trim().takeIf { it.isNotEmpty() }
    }
}

private object ObjMeshParser {
    fun parse(inputStream: InputStream, centerOrigin: Boolean): GPUMesh {
        val positions = mutableListOf<FloatArray>()
        val texCoords = mutableListOf<FloatArray>()
        val normals = mutableListOf<FloatArray>()
        val vertices = mutableListOf<Float>()

        BufferedReader(InputStreamReader(inputStream)).useLines { lines ->
            lines.forEach { rawLine ->
                val line = rawLine.substringBefore('#').trim()
                if (line.isEmpty()) return@forEach
                val parts = line.split(Regex("\\s+"))
                when (parts.firstOrNull()) {
                    "v" -> readPosition(parts)?.let { positions += it }
                    "vt" -> readTexCoord(parts)?.let { texCoords += it }
                    "vn" -> readNormal(parts)?.let { normals += it }
                    "f" -> appendFace(parts.drop(1), positions, texCoords, normals, vertices)
                }
            }
        }

        require(vertices.isNotEmpty()) { "OBJ did not contain renderable faces." }
        if (centerOrigin) centerVertices(vertices)
        return GPUMesh.upload(vertices.toFloatArray())
    }

    private fun appendFace(
        tokens: List<String>,
        positions: List<FloatArray>,
        texCoords: List<FloatArray>,
        normals: List<FloatArray>,
        vertices: MutableList<Float>,
    ) {
        val face = tokens.mapNotNull { parseFaceVertex(it, positions, texCoords, normals) }
        if (face.size < 3) return

        for (i in 1 until face.lastIndex) {
            appendTriangle(face[0], face[i], face[i + 1], vertices)
        }
    }

    private fun appendTriangle(
        a: ObjFaceVertex,
        b: ObjFaceVertex,
        c: ObjFaceVertex,
        vertices: MutableList<Float>,
    ) {
        val faceNormal = computeFaceNormal(a.position, b.position, c.position)
        appendVertex(a, faceNormal, vertices)
        appendVertex(b, faceNormal, vertices)
        appendVertex(c, faceNormal, vertices)
    }

    private fun appendVertex(
        vertex: ObjFaceVertex,
        faceNormal: FloatArray,
        vertices: MutableList<Float>,
    ) {
        val normal = vertex.normal ?: faceNormal
        val texCoord = vertex.texCoord ?: floatArrayOf(0f, 0f)
        vertices += vertex.position[0]
        vertices += vertex.position[1]
        vertices += vertex.position[2]
        vertices += normal[0]
        vertices += normal[1]
        vertices += normal[2]
        vertices += texCoord[0]
        vertices += texCoord[1]
    }

    private fun parseFaceVertex(
        token: String,
        positions: List<FloatArray>,
        texCoords: List<FloatArray>,
        normals: List<FloatArray>,
    ): ObjFaceVertex? {
        val parts = token.split('/')
        val position = positions.getOrNull(resolveObjIndex(parts.getOrNull(0), positions.size))
            ?: return null
        val texCoord = texCoords.getOrNull(resolveObjIndex(parts.getOrNull(1), texCoords.size))
        val normal = normals.getOrNull(resolveObjIndex(parts.getOrNull(2), normals.size))
        return ObjFaceVertex(position, texCoord, normal)
    }

    private fun resolveObjIndex(raw: String?, size: Int): Int {
        if (raw.isNullOrEmpty() || size <= 0) return -1
        val index = raw.toIntOrNull() ?: return -1
        return if (index > 0) index - 1 else size + index
    }

    private fun readPosition(parts: List<String>): FloatArray? {
        if (parts.size < 4) return null
        return floatArrayOf(
            parts[1].toFloatOrNull() ?: return null,
            parts[2].toFloatOrNull() ?: return null,
            parts[3].toFloatOrNull() ?: return null,
        )
    }

    private fun readTexCoord(parts: List<String>): FloatArray? {
        if (parts.size < 3) return null
        return floatArrayOf(
            parts[1].toFloatOrNull() ?: return null,
            parts[2].toFloatOrNull() ?: return null,
        )
    }

    private fun readNormal(parts: List<String>): FloatArray? {
        if (parts.size < 4) return null
        return normalize(
            floatArrayOf(
                parts[1].toFloatOrNull() ?: return null,
                parts[2].toFloatOrNull() ?: return null,
                parts[3].toFloatOrNull() ?: return null,
            ),
        )
    }

    private fun computeFaceNormal(a: FloatArray, b: FloatArray, c: FloatArray): FloatArray {
        val ux = b[0] - a[0]
        val uy = b[1] - a[1]
        val uz = b[2] - a[2]
        val vx = c[0] - a[0]
        val vy = c[1] - a[1]
        val vz = c[2] - a[2]
        return normalize(
            floatArrayOf(
                uy * vz - uz * vy,
                uz * vx - ux * vz,
                ux * vy - uy * vx,
            ),
        )
    }

    private fun normalize(vector: FloatArray): FloatArray {
        val length = sqrt(
            (vector[0] * vector[0] + vector[1] * vector[1] + vector[2] * vector[2]).toDouble(),
        ).toFloat()
        if (length <= 0f) return floatArrayOf(0f, 1f, 0f)
        return floatArrayOf(vector[0] / length, vector[1] / length, vector[2] / length)
    }

    private fun centerVertices(vertices: MutableList<Float>) {
        var minX = Float.POSITIVE_INFINITY
        var minY = Float.POSITIVE_INFINITY
        var minZ = Float.POSITIVE_INFINITY
        var maxX = Float.NEGATIVE_INFINITY
        var maxY = Float.NEGATIVE_INFINITY
        var maxZ = Float.NEGATIVE_INFINITY

        var i = 0
        while (i < vertices.size) {
            val x = vertices[i]
            val y = vertices[i + 1]
            val z = vertices[i + 2]
            minX = minOf(minX, x)
            minY = minOf(minY, y)
            minZ = minOf(minZ, z)
            maxX = maxOf(maxX, x)
            maxY = maxOf(maxY, y)
            maxZ = maxOf(maxZ, z)
            i += 8
        }

        val centerX = (minX + maxX) * 0.5f
        val centerY = (minY + maxY) * 0.5f
        val centerZ = (minZ + maxZ) * 0.5f
        i = 0
        while (i < vertices.size) {
            vertices[i] -= centerX
            vertices[i + 1] -= centerY
            vertices[i + 2] -= centerZ
            i += 8
        }
    }
}

private data class ObjFaceVertex(
    val position: FloatArray,
    val texCoord: FloatArray?,
    val normal: FloatArray?,
)
