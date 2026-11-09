import Metal
import MetalKit
import ARKit
import ModelIO
import simd
import Flutter

// ─── Vertex descriptor ────────────────────────────────────────────────────────

struct ARVertex {
    var position: SIMD3<Float>
    var normal:   SIMD3<Float>
    var texCoord: SIMD2<Float>
}

// ─── Uniform structs (must match Metal shaders exactly) ──────────────────────

struct PBRUniforms {
    var mvpMatrix:      float4x4
    var modelMatrix:    float4x4
    var normalMatrix:   float3x3
    var baseColor:      SIMD3<Float>
    var metallic:       Float
    var roughness:      Float
    var ao:             Float
    var cameraPosition: SIMD3<Float>
    var lightDirection: SIMD3<Float>
    var lightColor:     SIMD3<Float>
    var lightIntensity: Float
    var opacity:        Float
    var baseColorUvTransform: SIMD4<Float>
    var useBaseColorTexture:  Float
    var unlit:                Float
}

struct PlaneUniforms {
    var vpMatrix:    float4x4
    var modelMatrix: float4x4
    var color:       SIMD4<Float>
}

struct MetalNodeMaterial {
    var baseColor: SIMD3<Float>
    var metallic:  Float
    var roughness: Float
    var opacity:   Float
}

// ─── Metal shader source ──────────────────────────────────────────────────────

let PBRShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position  [[attribute(0)]];
    float3 normal    [[attribute(1)]];
    float2 texCoord  [[attribute(2)]];
};

struct VertexOut {
    float4 position  [[position]];
    float3 worldPos;
    float3 normal;
    float2 texCoord;
};

struct PBRUniforms {
    float4x4 mvpMatrix;
    float4x4 modelMatrix;
    float3x3 normalMatrix;
    float3   baseColor;
    float    metallic;
    float    roughness;
    float    ao;
    float3   cameraPosition;
    float3   lightDirection;
    float3   lightColor;
    float    lightIntensity;
    float    opacity;
    float4   baseColorUvTransform;
    float    useBaseColorTexture;
    float    unlit;
};

// ─── GGX PBR functions ───────────────────────────────────────────────────────

float D_GGX(float NdotH, float roughness) {
    float a  = roughness * roughness;
    float a2 = a * a;
    float d  = NdotH * NdotH * (a2 - 1.0) + 1.0;
    return a2 / (M_PI_F * d * d);
}

float G_SmithGGX(float NdotV, float NdotL, float roughness) {
    float r  = roughness + 1.0;
    float k  = (r * r) / 8.0;
    float gv = NdotV / (NdotV * (1.0 - k) + k);
    float gl = NdotL / (NdotL * (1.0 - k) + k);
    return gv * gl;
}

float3 F_Schlick(float cosTheta, float3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// ─── Vertex shader ────────────────────────────────────────────────────────────

vertex VertexOut pbr_vertex(VertexIn in [[stage_in]],
                             constant PBRUniforms& u [[buffer(1)]]) {
    VertexOut out;
    float4 worldPos = u.modelMatrix * float4(in.position, 1.0);
    out.position    = u.mvpMatrix   * float4(in.position, 1.0);
    out.worldPos    = worldPos.xyz;
    out.normal      = normalize(u.normalMatrix * in.normal);
    out.texCoord    = in.texCoord;
    return out;
}

// ─── Fragment shader (GGX PBR) ────────────────────────────────────────────────

fragment float4 pbr_fragment(VertexOut in [[stage_in]],
                              constant PBRUniforms& u [[buffer(1)]],
                              texture2d<float> baseColorTexture [[texture(0)]],
                              sampler baseColorSampler [[sampler(0)]]) {
    float2 uv = in.texCoord * u.baseColorUvTransform.xy + u.baseColorUvTransform.zw;
    float4 textureColor = float4(1.0);
    if (u.useBaseColorTexture > 0.5) {
        textureColor = baseColorTexture.sample(baseColorSampler, uv);
    }
    float opacity = u.opacity * textureColor.a;
    if (opacity <= 0.01) {
        discard_fragment();
    }

    float3 baseColor = saturate(u.baseColor * textureColor.rgb);
    if (u.unlit > 0.5) {
        return float4(baseColor, opacity);
    }

    float3 N   = normalize(in.normal);
    float3 V   = normalize(u.cameraPosition - in.worldPos);
    float3 L   = normalize(-u.lightDirection);
    float3 H   = normalize(V + L);

    float NdotL = max(dot(N, L), 0.0);
    float NdotV = max(dot(N, V), 0.001);
    float NdotH = max(dot(N, H), 0.0);
    float HdotV = max(dot(H, V), 0.0);

    float3 F0 = mix(float3(0.04), baseColor, u.metallic);

    float D  = D_GGX(NdotH, u.roughness);
    float G  = G_SmithGGX(NdotV, NdotL, u.roughness);
    float3 F = F_Schlick(HdotV, F0);

    float3 specular = (D * G * F) / max(4.0 * NdotV * NdotL, 0.001);
    float3 kd       = (1.0 - F) * (1.0 - u.metallic);
    float3 diffuse  = kd * baseColor / M_PI_F;

    float3 radiance = u.lightColor * u.lightIntensity;
    float3 Lo       = (diffuse + specular) * radiance * NdotL;

    float3 ambient  = float3(0.03) * baseColor * u.ao;
    float3 color    = ambient + Lo;

    // ACES tone-mapping
    color = (color * (2.51 * color + 0.03)) / (color * (2.43 * color + 0.59) + 0.14);
    color = saturate(color);

    return float4(color, opacity);
}

// ─── Plane shaders ────────────────────────────────────────────────────────────

struct PlaneUniforms {
    float4x4 vpMatrix;
    float4x4 modelMatrix;
    float4   color;
};

vertex VertexOut plane_vertex(VertexIn in [[stage_in]],
                               constant PlaneUniforms& u [[buffer(1)]]) {
    VertexOut out;
    out.position = u.vpMatrix * u.modelMatrix * float4(in.position, 1.0);
    out.worldPos = in.position;
    out.texCoord = in.texCoord;
    out.normal   = in.normal;
    return out;
}

fragment float4 plane_fragment(VertexOut in [[stage_in]],
                                constant PlaneUniforms& u [[buffer(1)]]) {
    float2 grid = abs(fract(in.texCoord * 10.0) - 0.5);
    float line  = min(grid.x, grid.y);
    float alpha = (1.0 - smoothstep(0.0, 0.05, line)) * 0.5 + 0.1;
    float dist  = length(in.texCoord - float2(0.5));
    float fade  = 1.0 - smoothstep(0.35, 0.5, dist);
    return float4(u.color.rgb, alpha * fade * u.color.a);
}
"""

// ─── Metal AR renderer ────────────────────────────────────────────────────────

class MetalARRenderer: NSObject {
    private let device:        MTLDevice
    private let commandQueue:  MTLCommandQueue
    private let textureLoader: MTKTextureLoader
    private var pbrPipeline:   MTLRenderPipelineState?
    private var planePipeline: MTLRenderPipelineState?
    private var depthState:    MTLDepthStencilState?
    private var textureSampler: MTLSamplerState?
    private var whiteTexture:   MTLTexture?
    private var photoTextureCache = [String: MTLTexture]()

    // Mesh buffers
    private var cubeMesh:     MTKMesh?
    private var sphereMesh:   MTKMesh?
    private var cylinderMesh: MTKMesh?
    private var planeMesh:    MTKMesh?

    private let allocator: MTKMeshBufferAllocator

    init?(device: MTLDevice) {
        guard let queue = device.makeCommandQueue() else { return nil }
        self.device       = device
        self.commandQueue = queue
        self.allocator    = MTKMeshBufferAllocator(device: device)
        self.textureLoader = MTKTextureLoader(device: device)
        super.init()
        buildPipelines()
        buildMeshes()
        whiteTexture = Self.makeWhiteTexture(device: device)
    }

    // ── Pipeline setup ────────────────────────────────────────────────────────

    private func buildPipelines() {
        guard let lib = try? device.makeLibrary(source: PBRShaderSource, options: nil) else {
            print("[AREngine] Failed to compile Metal shaders")
            return
        }

        let vertDesc = buildVertexDescriptor()

        // PBR pipeline
        let pbrDesc = MTLRenderPipelineDescriptor()
        pbrDesc.vertexFunction                  = lib.makeFunction(name: "pbr_vertex")
        pbrDesc.fragmentFunction                = lib.makeFunction(name: "pbr_fragment")
        pbrDesc.vertexDescriptor                = vertDesc
        pbrDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        pbrDesc.colorAttachments[0].isBlendingEnabled             = true
        pbrDesc.colorAttachments[0].sourceRGBBlendFactor          = .sourceAlpha
        pbrDesc.colorAttachments[0].destinationRGBBlendFactor     = .oneMinusSourceAlpha
        pbrDesc.depthAttachmentPixelFormat      = .depth32Float
        pbrPipeline = try? device.makeRenderPipelineState(descriptor: pbrDesc)

        // Plane pipeline (same vertex, different fragment)
        let planeDesc = MTLRenderPipelineDescriptor()
        planeDesc.vertexFunction                  = lib.makeFunction(name: "plane_vertex")
        planeDesc.fragmentFunction                = lib.makeFunction(name: "plane_fragment")
        planeDesc.vertexDescriptor                = vertDesc
        planeDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        planeDesc.colorAttachments[0].isBlendingEnabled         = true
        planeDesc.colorAttachments[0].sourceRGBBlendFactor      = .sourceAlpha
        planeDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        planeDesc.depthAttachmentPixelFormat      = .depth32Float
        planePipeline = try? device.makeRenderPipelineState(descriptor: planeDesc)

        // Depth state
        let dsDesc = MTLDepthStencilDescriptor()
        dsDesc.depthCompareFunction = .less
        dsDesc.isDepthWriteEnabled  = true
        depthState = device.makeDepthStencilState(descriptor: dsDesc)

        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        samplerDesc.mipFilter = .linear
        samplerDesc.sAddressMode = .clampToEdge
        samplerDesc.tAddressMode = .clampToEdge
        textureSampler = device.makeSamplerState(descriptor: samplerDesc)
    }

    private func buildVertexDescriptor() -> MTLVertexDescriptor {
        let desc = MTLVertexDescriptor()
        // position
        desc.attributes[0].format      = .float3
        desc.attributes[0].offset      = 0
        desc.attributes[0].bufferIndex = 0
        // normal
        desc.attributes[1].format      = .float3
        desc.attributes[1].offset      = MemoryLayout<SIMD3<Float>>.stride
        desc.attributes[1].bufferIndex = 0
        // texCoord
        desc.attributes[2].format      = .float2
        desc.attributes[2].offset      = MemoryLayout<SIMD3<Float>>.stride * 2
        desc.attributes[2].bufferIndex = 0

        desc.layouts[0].stride         = MemoryLayout<ARVertex>.stride
        return desc
    }

    // ── Mesh construction (ModelIO → MetalKit) ────────────────────────────────

    private func buildMeshes() {
        let extent = vector_float3(0.1, 0.1, 0.1)
        let cubeSegments = vector_uint3(1, 1, 1)
        let roundSegments = vector_uint2(32, 32)
        let cylinderSegments = vector_uint2(32, 1)
        let planeExtent = vector_float3(1, 0, 1)
        let planeSegments = vector_uint2(1, 1)

        cubeMesh     = try? MTKMesh(mesh: MDLMesh(boxWithExtent: extent,
            segments: cubeSegments, inwardNormals: false, geometryType: .triangles,
            allocator: allocator), device: device)

        sphereMesh   = try? MTKMesh(mesh: MDLMesh(sphereWithExtent: extent,
            segments: roundSegments, inwardNormals: false, geometryType: .triangles,
            allocator: allocator), device: device)

        cylinderMesh = try? MTKMesh(mesh: MDLMesh(cylinderWithExtent: extent,
            segments: cylinderSegments, inwardNormals: false, topCap: true,
            bottomCap: true,
            geometryType: .triangles, allocator: allocator), device: device)

        planeMesh    = try? MTKMesh(mesh: MDLMesh(planeWithExtent: planeExtent,
            segments: planeSegments, geometryType: .triangles,
            allocator: allocator), device: device)
    }

    // ── Draw call ─────────────────────────────────────────────────────────────

    func draw(
        frame: ARFrame,
        nodes: [[String: Any]],
        renderEncoder: MTLRenderCommandEncoder
    ) {
        guard let pbrPipeline, let planePipeline, let depthState else { return }

        let camera     = frame.camera
        let projMatrix = camera.projectionMatrix(for: .landscapeRight,
            viewportSize: CGSize(width: 1, height: 1), zNear: 0.001, zFar: 100)
        let viewMatrix = camera.viewMatrix(for: .landscapeRight)
        let vpMatrix   = projMatrix * viewMatrix

        // Camera world position
        let inv  = viewMatrix.inverse
        let camPos = SIMD3<Float>(inv.columns.3.x, inv.columns.3.y, inv.columns.3.z)

        // Light from ARKit estimation
        var lightDir  = SIMD3<Float>(0, -1, -0.5)
        var lightInt: Float = 1.2
        if let le = frame.lightEstimate as? ARDirectionalLightEstimate {
            let ld = le.primaryLightDirection
            lightDir = SIMD3<Float>(ld.x, ld.y, ld.z)
            lightInt = Float(le.primaryLightIntensity / 1000.0)
        }

        // ── Planes ─────────────────────────────────────────────────────────────
        renderEncoder.setRenderPipelineState(planePipeline)
        renderEncoder.setDepthStencilState(depthState)
        for anchor in frame.anchors {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }
            let modelMatrix = simd_float4x4(planeAnchor.transform)
            let planeSize = planeExtentMeters(for: planeAnchor)
            let scale = SIMD3<Float>(planeSize.width, 1, planeSize.height)
            var scaledModel = modelMatrix
            scaledModel.columns.0 *= scale.x
            scaledModel.columns.2 *= scale.z

            var uniforms = PlaneUniforms(
                vpMatrix:    matrix_float4x4(vpMatrix),
                modelMatrix: scaledModel,
                color:       SIMD4<Float>(0, 0.85, 1, 0.6)
            )
            renderEncoder.setVertexBytes(&uniforms,
                length: MemoryLayout<PlaneUniforms>.stride, index: 1)
            renderEncoder.setFragmentBytes(&uniforms,
                length: MemoryLayout<PlaneUniforms>.stride, index: 1)

            if let pm = planeMesh {
                renderEncoder.setVertexBuffer(pm.vertexBuffers[0].buffer, offset: 0, index: 0)
                for submesh in pm.submeshes {
                    renderEncoder.drawIndexedPrimitives(
                        type: submesh.primitiveType,
                        indexCount: submesh.indexCount,
                        indexType: submesh.indexType,
                        indexBuffer: submesh.indexBuffer.buffer,
                        indexBufferOffset: submesh.indexBuffer.offset)
                }
            }
        }

        // ── Scene nodes ────────────────────────────────────────────────────────
        renderEncoder.setRenderPipelineState(pbrPipeline)
        let anchorTransforms = Dictionary(
            uniqueKeysWithValues: frame.anchors.map {
                ($0.identifier.uuidString, simd_float4x4($0.transform))
            }
        )
        for nodeMap in nodes {
            if (nodeMap["isVisible"] as? Bool) == false { continue }

            if isHangingPhotoFrame(nodeMap) {
                drawHangingPhotoFrame(
                    nodeMap: nodeMap,
                    anchorTransforms: anchorTransforms,
                    renderEncoder: renderEncoder,
                    vpMatrix: matrix_float4x4(vpMatrix),
                    camPos: camPos,
                    lightDir: lightDir,
                    lightInt: lightInt
                )
                continue
            }

            let shape = nodeMap["primitiveShape"] as? String ?? "cube"
            guard let mesh = mesh(for: shape) else { continue }
            let modelMatrix = buildModelMatrix(
                from: nodeMap,
                anchorTransforms: anchorTransforms,
                shape: shape
            )
            drawMesh(
                mesh: mesh,
                modelMatrix: modelMatrix,
                renderEncoder: renderEncoder,
                vpMatrix: matrix_float4x4(vpMatrix),
                camPos: camPos,
                material: material(
                    from: nodeMap["material"] as? [String: Any],
                    fallbackColor: SIMD3<Float>(0.2, 0.6, 1.0),
                    fallbackMetallic: 0.1,
                    fallbackRoughness: 0.6
                ),
                lightDir: lightDir,
                lightInt: lightInt
            )
        }
    }

    private func drawMesh(
        mesh: MTKMesh,
        modelMatrix: float4x4,
        renderEncoder: MTLRenderCommandEncoder,
        vpMatrix: matrix_float4x4,
        camPos: SIMD3<Float>,
        material: MetalNodeMaterial,
        baseColorTexture: MTLTexture? = nil,
        baseColorUvTransform: SIMD4<Float> = SIMD4<Float>(1, 1, 0, 0),
        unlit: Bool = false,
        lightDir: SIMD3<Float>,
        lightInt: Float
    ) {
        let mvp = vpMatrix * modelMatrix
        let m33 = float3x3(
            modelMatrix.columns.0.xyz,
            modelMatrix.columns.1.xyz,
            modelMatrix.columns.2.xyz
        )
        let normalMatrix = m33.inverse.transpose

        var uniforms = PBRUniforms(
            mvpMatrix:      mvp,
            modelMatrix:    modelMatrix,
            normalMatrix:   normalMatrix,
            baseColor:      material.baseColor,
            metallic:       material.metallic,
            roughness:      material.roughness,
            ao:             1.0,
            cameraPosition: camPos,
            lightDirection: lightDir,
            lightColor:     SIMD3<Float>(1, 1, 0.98),
            lightIntensity: lightInt,
            opacity:        material.opacity,
            baseColorUvTransform: baseColorUvTransform,
            useBaseColorTexture: baseColorTexture == nil ? 0 : 1,
            unlit: unlit ? 1 : 0
        )
        renderEncoder.setVertexBytes(&uniforms,
            length: MemoryLayout<PBRUniforms>.stride, index: 1)
        renderEncoder.setFragmentBytes(&uniforms,
            length: MemoryLayout<PBRUniforms>.stride, index: 1)
        renderEncoder.setFragmentTexture(baseColorTexture ?? whiteTexture, index: 0)
        if let textureSampler {
            renderEncoder.setFragmentSamplerState(textureSampler, index: 0)
        }

        renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        for submesh in mesh.submeshes {
            renderEncoder.drawIndexedPrimitives(
                type: submesh.primitiveType,
                indexCount: submesh.indexCount,
                indexType: submesh.indexType,
                indexBuffer: submesh.indexBuffer.buffer,
                indexBufferOffset: submesh.indexBuffer.offset)
        }
    }

    private func drawHangingPhotoFrame(
        nodeMap: [String: Any],
        anchorTransforms: [String: simd_float4x4],
        renderEncoder: MTLRenderCommandEncoder,
        vpMatrix: matrix_float4x4,
        camPos: SIMD3<Float>,
        lightDir: SIMD3<Float>,
        lightInt: Float
    ) {
        guard let cubeMesh, let planeMesh else { return }
        let metadata = nodeMap["metadata"] as? [String: Any] ?? [:]
        let style = metadata["photoFrameStyle"] as? [String: Any]
        let size = nodeMap["primitiveSize"] as? [String: Any]
        let photoWidth = max(floatArg(size, "x", 0.42), 0.08)
        let photoHeight = max(floatArg(size, "z", 0.28), 0.08)
        let frameDepth = frameStyleFloat(
            style,
            metadata,
            styleKey: "depthMeters",
            metadataKey: "frameDepthMeters",
            defaultValue: 0.10
        ).clamped(min: 0.025, max: 0.24)
        let frameBorder = frameStyleFloat(
            style,
            metadata,
            styleKey: "borderMeters",
            metadataKey: "frameBorderMeters",
            defaultValue: 0.072
        ).clamped(min: 0.02, max: 0.18)
        let photoRecess = frameStyleFloat(
            style,
            metadata,
            styleKey: "photoRecessMeters",
            metadataKey: "photoRecessMeters",
            defaultValue: frameDepth * 0.46
        ).clamped(min: 0.008, max: frameDepth * 0.72)
        let backingThickness = frameStyleFloat(
            style,
            metadata,
            styleKey: "backingThicknessMeters",
            metadataKey: "frameBackingThicknessMeters",
            defaultValue: frameDepth * 0.18
        ).clamped(min: 0.004, max: frameDepth * 0.36)
        let topLipHeight = frameStyleFloat(
            style,
            metadata,
            styleKey: "topLipHeightMeters",
            metadataKey: "frameTopLipHeightMeters",
            defaultValue: 0.008
        ).clamped(min: 0.002, max: 0.04)
        let outerWidth = photoWidth + frameBorder * 2
        let outerHeight = photoHeight + frameBorder * 2
        let baseModelMatrix = buildModelMatrix(
            from: nodeMap,
            anchorTransforms: anchorTransforms,
            shape: "plane",
            includePrimitiveSize: false
        )

        let backingMaterial = frameStyleMaterial(
            style,
            key: "backingMaterial",
            fallbackColor: SIMD3<Float>(0.035, 0.032, 0.028),
            fallbackRoughness: 0.72
        )
        let railMaterial = frameStyleMaterial(
            style,
            key: "frameMaterial",
            fallbackColor: SIMD3<Float>(0.055, 0.046, 0.036),
            fallbackRoughness: 0.55
        )
        let highlightMaterial = frameStyleMaterial(
            style,
            key: "highlightMaterial",
            fallbackColor: SIMD3<Float>(0.12, 0.095, 0.064),
            fallbackRoughness: 0.48
        )

        drawBox(
            mesh: cubeMesh,
            baseModelMatrix: baseModelMatrix,
            offset: SIMD3<Float>(0, -frameDepth / 2 + backingThickness / 2, 0),
            size: SIMD3<Float>(outerWidth, backingThickness, outerHeight),
            renderEncoder: renderEncoder,
            vpMatrix: vpMatrix,
            camPos: camPos,
            material: backingMaterial,
            lightDir: lightDir,
            lightInt: lightInt
        )
        drawBox(
            mesh: cubeMesh,
            baseModelMatrix: baseModelMatrix,
            offset: SIMD3<Float>(0, 0, photoHeight / 2 + frameBorder / 2),
            size: SIMD3<Float>(outerWidth, frameDepth, frameBorder),
            renderEncoder: renderEncoder,
            vpMatrix: vpMatrix,
            camPos: camPos,
            material: railMaterial,
            lightDir: lightDir,
            lightInt: lightInt
        )
        drawBox(
            mesh: cubeMesh,
            baseModelMatrix: baseModelMatrix,
            offset: SIMD3<Float>(0, 0, -photoHeight / 2 - frameBorder / 2),
            size: SIMD3<Float>(outerWidth, frameDepth, frameBorder),
            renderEncoder: renderEncoder,
            vpMatrix: vpMatrix,
            camPos: camPos,
            material: railMaterial,
            lightDir: lightDir,
            lightInt: lightInt
        )
        drawBox(
            mesh: cubeMesh,
            baseModelMatrix: baseModelMatrix,
            offset: SIMD3<Float>(-photoWidth / 2 - frameBorder / 2, 0, 0),
            size: SIMD3<Float>(frameBorder, frameDepth, photoHeight),
            renderEncoder: renderEncoder,
            vpMatrix: vpMatrix,
            camPos: camPos,
            material: railMaterial,
            lightDir: lightDir,
            lightInt: lightInt
        )
        drawBox(
            mesh: cubeMesh,
            baseModelMatrix: baseModelMatrix,
            offset: SIMD3<Float>(photoWidth / 2 + frameBorder / 2, 0, 0),
            size: SIMD3<Float>(frameBorder, frameDepth, photoHeight),
            renderEncoder: renderEncoder,
            vpMatrix: vpMatrix,
            camPos: camPos,
            material: railMaterial,
            lightDir: lightDir,
            lightInt: lightInt
        )
        drawBox(
            mesh: cubeMesh,
            baseModelMatrix: baseModelMatrix,
            offset: SIMD3<Float>(
                0,
                frameDepth / 2 + topLipHeight / 2,
                photoHeight / 2 + frameBorder * 0.78
            ),
            size: SIMD3<Float>(outerWidth * 0.92, topLipHeight, frameBorder * 0.18),
            renderEncoder: renderEncoder,
            vpMatrix: vpMatrix,
            camPos: camPos,
            material: highlightMaterial,
            lightDir: lightDir,
            lightInt: lightInt
        )

        let nodeId = nodeMap["id"] as? String ?? "photo"
        let photoTexture = photoTexture(from: metadata, nodeId: nodeId)
        let photoUvTransform = photoTexture.map {
            coverUvTransform(
                surfaceWidth: photoWidth,
                surfaceHeight: photoHeight,
                texture: $0
            )
        } ?? SIMD4<Float>(1, 1, 0, 0)
        let photoModelMatrix = localModelMatrix(
            base: baseModelMatrix,
            offset: SIMD3<Float>(0, frameDepth / 2 - photoRecess + 0.002, 0),
            size: SIMD3<Float>(photoWidth, 1, photoHeight),
            meshBaseExtent: SIMD3<Float>(1, 1, 1)
        )
        drawMesh(
            mesh: planeMesh,
            modelMatrix: photoModelMatrix,
            renderEncoder: renderEncoder,
            vpMatrix: vpMatrix,
            camPos: camPos,
            material: material(
                from: nodeMap["material"] as? [String: Any],
                fallbackColor: SIMD3<Float>(1, 1, 1),
                fallbackMetallic: 0,
                fallbackRoughness: 0.36
            ),
            baseColorTexture: photoTexture,
            baseColorUvTransform: photoUvTransform,
            unlit: photoTexture != nil,
            lightDir: lightDir,
            lightInt: lightInt
        )
    }

    private func drawBox(
        mesh: MTKMesh,
        baseModelMatrix: float4x4,
        offset: SIMD3<Float>,
        size: SIMD3<Float>,
        renderEncoder: MTLRenderCommandEncoder,
        vpMatrix: matrix_float4x4,
        camPos: SIMD3<Float>,
        material: MetalNodeMaterial,
        lightDir: SIMD3<Float>,
        lightInt: Float
    ) {
        drawMesh(
            mesh: mesh,
            modelMatrix: localModelMatrix(
                base: baseModelMatrix,
                offset: offset,
                size: size,
                meshBaseExtent: SIMD3<Float>(0.1, 0.1, 0.1)
            ),
            renderEncoder: renderEncoder,
            vpMatrix: vpMatrix,
            camPos: camPos,
            material: material,
            lightDir: lightDir,
            lightInt: lightInt
        )
    }

    private func photoTexture(from metadata: [String: Any], nodeId: String) -> MTLTexture? {
        guard let data = photoTextureData(from: metadata), !data.isEmpty else {
            return nil
        }
        let baseKey = (metadata["photoTextureKey"] as? String)
            ?? (metadata["mediaId"] as? String)
            ?? nodeId
        let cacheKey = "\(baseKey):\(data.count):\(data.hashValue)"
        if let texture = photoTextureCache[cacheKey] {
            return texture
        }

        let texture = try? textureLoader.newTexture(
            data: data,
            options: [
                MTKTextureLoader.Option.SRGB: true,
                MTKTextureLoader.Option.generateMipmaps: true,
            ]
        )
        guard let texture else { return nil }
        if photoTextureCache.count > 32,
           let staleKey = photoTextureCache.keys.first {
            photoTextureCache.removeValue(forKey: staleKey)
        }
        photoTextureCache[cacheKey] = texture
        return texture
    }

    private func photoTextureData(from metadata: [String: Any]) -> Data? {
        let value = metadata["photoTextureBytes"]
        if let typedData = value as? FlutterStandardTypedData {
            return typedData.data
        }
        if let data = value as? Data {
            return data
        }
        if let bytes = value as? [UInt8] {
            return Data(bytes)
        }
        if let bytes = value as? [NSNumber] {
            return Data(bytes.map { UInt8(clamping: $0.intValue) })
        }
        return nil
    }

    private func coverUvTransform(
        surfaceWidth: Float,
        surfaceHeight: Float,
        texture: MTLTexture
    ) -> SIMD4<Float> {
        let surfaceAspect = max(surfaceWidth, 0.01) / max(surfaceHeight, 0.01)
        let textureAspect = Float(texture.width) / max(Float(texture.height), 1)
        if textureAspect > surfaceAspect {
            let scaleX = surfaceAspect / textureAspect
            return SIMD4<Float>(scaleX, 1, (1 - scaleX) / 2, 0)
        }
        let scaleY = textureAspect / surfaceAspect
        return SIMD4<Float>(1, scaleY, 0, (1 - scaleY) / 2)
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

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static func makeWhiteTexture(device: MTLDevice) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        var pixel: UInt32 = 0xffffffff
        texture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: &pixel,
            bytesPerRow: 4
        )
        return texture
    }

    private func mesh(for shape: String) -> MTKMesh? {
        switch shape {
        case "sphere":   return sphereMesh
        case "cylinder": return cylinderMesh
        case "plane":    return planeMesh
        default:         return cubeMesh
        }
    }

    private func isHangingPhotoFrame(_ node: [String: Any]) -> Bool {
        guard let metadata = node["metadata"] as? [String: Any],
              (metadata["photoFrame"] as? Bool) == true else {
            return false
        }
        let kind = metadata["photoFrameKind"] as? String
        return kind == nil || kind == "hanging_3d_photo_frame"
    }

    private func buildModelMatrix(
        from node: [String: Any],
        anchorTransforms: [String: simd_float4x4],
        shape: String,
        includePrimitiveSize: Bool = true
    ) -> float4x4 {
        let pos = node["position"] as? [String: Any]
        let rot = node["rotation"] as? [String: Any]
        let scl = node["scale"]    as? [String: Any]

        let tx = floatArg(pos, "x", 0)
        let ty = floatArg(pos, "y", 0)
        let tz = floatArg(pos, "z", 0)

        var scale = SIMD3<Float>(
            floatArg(scl, "x", 1),
            floatArg(scl, "y", 1),
            floatArg(scl, "z", 1)
        )
        if includePrimitiveSize {
            let primitiveScale = primitiveSizeScale(for: node, shape: shape)
            scale.x *= primitiveScale.x
            scale.y *= primitiveScale.y
            scale.z *= primitiveScale.z
        }

        let qx = floatArg(rot, "x", 0)
        let qy = floatArg(rot, "y", 0)
        let qz = floatArg(rot, "z", 0)
        let qw = floatArg(rot, "w", 1)

        let q   = simd_quatf(ix: qx, iy: qy, iz: qz, r: qw)
        var m   = float4x4(q)
        m.columns.3 = SIMD4<Float>(tx, ty, tz, 1)

        let scaleM = float4x4(diagonal: SIMD4<Float>(scale.x, scale.y, scale.z, 1))
        let localModel = m * scaleM
        guard let anchorId = node["anchorId"] as? String,
              let anchorTransform = anchorTransforms[anchorId] else {
            return localModel
        }
        return float4x4(anchorTransform) * localModel
    }

    private func primitiveSizeScale(for node: [String: Any], shape: String) -> SIMD3<Float> {
        guard let primitiveSize = node["primitiveSize"] as? [String: Any] else {
            return SIMD3<Float>(1, 1, 1)
        }
        let baseExtent = meshBaseExtent(for: shape)
        return SIMD3<Float>(
            positiveScale(floatArg(primitiveSize, "x", baseExtent.x) / baseExtent.x),
            positiveScale(floatArg(primitiveSize, "y", baseExtent.y) / baseExtent.y),
            positiveScale(floatArg(primitiveSize, "z", baseExtent.z) / baseExtent.z)
        )
    }

    private func meshBaseExtent(for shape: String) -> SIMD3<Float> {
        switch shape {
        case "plane": return SIMD3<Float>(1, 1, 1)
        default:      return SIMD3<Float>(0.1, 0.1, 0.1)
        }
    }

    private func localModelMatrix(
        base: float4x4,
        offset: SIMD3<Float>,
        size: SIMD3<Float>,
        meshBaseExtent: SIMD3<Float>
    ) -> float4x4 {
        var translation = matrix_identity_float4x4
        translation.columns.3 = SIMD4<Float>(offset.x, offset.y, offset.z, 1)
        let scale = float4x4(diagonal: SIMD4<Float>(
            positiveScale(size.x / meshBaseExtent.x),
            positiveScale(size.y / meshBaseExtent.y),
            positiveScale(size.z / meshBaseExtent.z),
            1
        ))
        return base * translation * scale
    }

    private func frameStyleFloat(
        _ style: [String: Any]?,
        _ metadata: [String: Any],
        styleKey: String,
        metadataKey: String,
        defaultValue: Float
    ) -> Float {
        if let value = floatArg(style, styleKey) {
            return value
        }
        return floatArg(metadata, metadataKey, defaultValue)
    }

    private func frameStyleMaterial(
        _ style: [String: Any]?,
        key: String,
        fallbackColor: SIMD3<Float>,
        fallbackRoughness: Float
    ) -> MetalNodeMaterial {
        return material(
            from: style?[key] as? [String: Any],
            fallbackColor: fallbackColor,
            fallbackMetallic: 0,
            fallbackRoughness: fallbackRoughness
        )
    }

    private func material(
        from matMap: [String: Any]?,
        fallbackColor: SIMD3<Float>,
        fallbackMetallic: Float,
        fallbackRoughness: Float
    ) -> MetalNodeMaterial {
        let color = matMap?["baseColor"] as? [String: Any]
        return MetalNodeMaterial(
            baseColor: SIMD3<Float>(
                floatArg(color, "r", fallbackColor.x),
                floatArg(color, "g", fallbackColor.y),
                floatArg(color, "b", fallbackColor.z)
            ),
            metallic: floatArg(matMap, "metallic", fallbackMetallic)
                .clamped(min: 0, max: 1),
            roughness: floatArg(matMap, "roughness", fallbackRoughness)
                .clamped(min: 0, max: 1),
            opacity: floatArg(matMap, "opacity", 1)
                .clamped(min: 0, max: 1)
        )
    }

    private func floatArg(_ map: [String: Any]?, _ key: String) -> Float? {
        guard let value = map?[key] else { return nil }
        if let value = value as? Float { return value.isFinite ? value : nil }
        if let value = value as? Double {
            let result = Float(value)
            return result.isFinite ? result : nil
        }
        if let value = value as? NSNumber {
            let result = Float(value.doubleValue)
            return result.isFinite ? result : nil
        }
        return nil
    }

    private func floatArg(_ map: [String: Any]?, _ key: String, _ defaultValue: Float) -> Float {
        return floatArg(map, key) ?? defaultValue
    }

    private func positiveScale(_ value: Float) -> Float {
        return value.isFinite && value > 0 ? value : 0.0001
    }
}

// SIMD matrix helpers
extension float4x4 {
    init(_ m: simd_float4x4) { self = m }
}

extension SIMD4 {
    var xyz: SIMD3<Scalar> { SIMD3(x, y, z) }
}

extension Float {
    func clamped(min minValue: Float, max maxValue: Float) -> Float {
        return Swift.min(Swift.max(self, minValue), maxValue)
    }
}
