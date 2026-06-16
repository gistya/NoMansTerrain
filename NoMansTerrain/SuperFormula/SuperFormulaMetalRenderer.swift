import Metal
import MetalKit
import simd

@MainActor
final class SuperFormulaMetalRenderer: NSObject, MTKViewDelegate {
    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float3 position [[attribute(0)]];
        float3 normal [[attribute(1)]];
    };

    struct VertexOut {
        float4 position [[position]];
        float3 worldNormal;
        float3 worldPosition;
    };

    struct Uniforms {
        float4x4 modelViewProjection;
        float4x4 modelMatrix;
        float3 lightDirection;
        float3 cameraPosition;
        float3 baseColor;
        float3 accentColor;
    };

    vertex VertexOut superFormulaVertex(
        VertexIn in [[stage_in]],
        constant Uniforms& uniforms [[buffer(1)]]
    ) {
        VertexOut out;
        float4 worldPosition = uniforms.modelMatrix * float4(in.position, 1.0);
        out.position = uniforms.modelViewProjection * float4(in.position, 1.0);
        out.worldPosition = worldPosition.xyz;
        out.worldNormal = normalize((uniforms.modelMatrix * float4(in.normal, 0.0)).xyz);
        return out;
    }

    fragment float4 superFormulaFragment(
        VertexOut in [[stage_in]],
        constant Uniforms& uniforms [[buffer(1)]]
    ) {
        float3 normal = normalize(in.worldNormal);
        float3 viewDirection = normalize(uniforms.cameraPosition - in.worldPosition);
        float3 lightDirection = normalize(uniforms.lightDirection);

        float diffuse = clamp(dot(normal, lightDirection), 0.0, 1.0);
        float3 halfVector = normalize(lightDirection + viewDirection);
        float specular = pow(clamp(dot(normal, halfVector), 0.0, 1.0), 48.0);

        float fresnel = pow(1.0 - clamp(dot(normal, viewDirection), 0.0, 1.0), 3.0);
        float3 color = uniforms.baseColor * (0.18 + diffuse * 0.72);
        color += uniforms.accentColor * specular * 0.45;
        color += uniforms.accentColor * fresnel * 0.25;

        return float4(color, 1.0);
    }
    """
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState

    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    private var indexCount = 0

    var cameraAzimuth: Float = 0.6
    var cameraElevation: Float = 0.35
    var cameraDistance: Float = 3.2

    override init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            fatalError("Metal is not available on this device.")
        }

        self.device = device
        self.commandQueue = commandQueue

        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: Self.shaderSource, options: nil)
        } catch {
            fatalError("Failed to compile SuperFormula Metal shaders: \(error)")
        }

        guard let vertexFunction = library.makeFunction(name: "superFormulaVertex"),
              let fragmentFunction = library.makeFunction(name: "superFormulaFragment") else {
            fatalError("Failed to load SuperFormula Metal shader functions.")
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<SuperFormulaVertex>.stride
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create Metal pipeline: \(error)")
        }

        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            fatalError("Failed to create depth state.")
        }
        self.depthState = depthState

        super.init()
    }

    func updateMesh(_ mesh: SuperFormulaMesh) {
        vertexBuffer = device.makeBuffer(
            bytes: mesh.vertices,
            length: MemoryLayout<SuperFormulaVertex>.stride * mesh.vertices.count,
            options: .storageModeShared
        )
        indexBuffer = device.makeBuffer(
            bytes: mesh.indices,
            length: MemoryLayout<UInt32>.stride * mesh.indices.count,
            options: .storageModeShared
        )
        indexCount = mesh.indices.count
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let passDescriptor = view.currentRenderPassDescriptor,
              let vertexBuffer,
              let indexBuffer,
              indexCount > 0,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1)
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.depthAttachment.clearDepth = 1
        passDescriptor.depthAttachment.loadAction = .clear

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            return
        }

        let aspect = Float(max(view.drawableSize.width, 1) / max(view.drawableSize.height, 1))
        let projection = matrix_perspective_right_hand(fovyRadians: 45 * .pi / 180, aspect: aspect, nearZ: 0.1, farZ: 100)
        let viewMatrix = matrix_look_at_right_hand(
            eye: cameraEyePosition(),
            target: SIMD3<Float>(0, 0, 0),
            up: SIMD3<Float>(0, 1, 0)
        )
        let modelMatrix = matrix_identity_float4x4
        let mvp = projection * viewMatrix * modelMatrix

        var uniforms = SuperFormulaUniforms(
            modelViewProjection: mvp,
            modelMatrix: modelMatrix,
            lightDirection: simd_normalize(SIMD3<Float>(-0.35, 0.85, 0.4)),
            cameraPosition: cameraEyePosition(),
            baseColor: SIMD3<Float>(0.18, 0.62, 0.95),
            accentColor: SIMD3<Float>(0.85, 0.95, 1.0)
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthState)
        encoder.setCullMode(.back)
        encoder.setFrontFacing(.counterClockwise)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<SuperFormulaUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SuperFormulaUniforms>.stride, index: 1)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint32,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func cameraEyePosition() -> SIMD3<Float> {
        let x = cameraDistance * cos(cameraElevation) * sin(cameraAzimuth)
        let y = cameraDistance * sin(cameraElevation)
        let z = cameraDistance * cos(cameraElevation) * cos(cameraAzimuth)
        return SIMD3<Float>(x, y, z)
    }
}

private struct SuperFormulaUniforms {
    var modelViewProjection: simd_float4x4
    var modelMatrix: simd_float4x4
    var lightDirection: SIMD3<Float>
    var cameraPosition: SIMD3<Float>
    var baseColor: SIMD3<Float>
    var accentColor: SIMD3<Float>
}

private func matrix_perspective_right_hand(fovyRadians: Float, aspect: Float, nearZ: Float, farZ: Float) -> simd_float4x4 {
    let ys = 1 / tanf(fovyRadians * 0.5)
    let xs = ys / aspect
    let zs = farZ / (nearZ - farZ)
    return simd_float4x4(columns: (
        SIMD4<Float>(xs, 0, 0, 0),
        SIMD4<Float>(0, ys, 0, 0),
        SIMD4<Float>(0, 0, zs, -1),
        SIMD4<Float>(0, 0, zs * nearZ, 0)
    ))
}

private func matrix_look_at_right_hand(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
    let forward = simd_normalize(target - eye)
    let right = simd_normalize(simd_cross(forward, up))
    let trueUp = simd_cross(right, forward)
    return simd_float4x4(columns: (
        SIMD4<Float>(right.x, trueUp.x, -forward.x, 0),
        SIMD4<Float>(right.y, trueUp.y, -forward.y, 0),
        SIMD4<Float>(right.z, trueUp.z, -forward.z, 0),
        SIMD4<Float>(-simd_dot(right, eye), -simd_dot(trueUp, eye), simd_dot(forward, eye), 1)
    ))
}