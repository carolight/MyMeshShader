//
//  Renderer.swift
//  MyMeshShader
//
//  Created by Caroline Begbie on 24/3/2023.
//

import MetalKit

class Renderer: NSObject {
  let device: MTLDevice
  let commandQueue: MTLCommandQueue
  let pipelineState: MTLRenderPipelineState
  let meshPipelineState: MTLRenderPipelineState

  let sphereMesh: MTKMesh
  let depthStencilState: MTLDepthStencilState

  let meshVertexCount: Int

  var primitiveType: MTLPrimitiveType = .triangle

  let fov: Float = 65
  var projectionMatrix = matrix_identity_float4x4
  var viewMatrix = matrix_identity_float4x4
  var modelMatrix = matrix_identity_float4x4

  init(metalView: MTKView) {
    guard let device = MTLCreateSystemDefaultDevice() else {
      fatalError("GPU is not supported")
    }
    guard let commandQueue = device.makeCommandQueue() else {
      fatalError("Command Queue not created")
    }
    self.device = device
    self.commandQueue = commandQueue

    // create mesh
    let allocator = MTKMeshBufferAllocator(device: device)
    let mdlMesh = MDLMesh(
      sphereWithExtent: [1.2, 1.2, 1.2],
      segments: [60, 60],
      inwardNormals: false,
      geometryType: .triangles,
      allocator: allocator)

    guard let mesh = try? MTKMesh(mesh: mdlMesh, device: device) else {
      fatalError("Mesh not created")
    }
    self.sphereMesh = mesh
    self.meshVertexCount = mesh.vertexCount

    print("Sphere Vertex Count: ", meshVertexCount)

    guard let library = device.makeDefaultLibrary() else {
      fatalError("Library not created")
    }
    let vertexFunction = library.makeFunction(name: "vertexMain")
    let fragmentFunction = library.makeFunction(name: "fragmentColor")

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction

    pipelineDescriptor.vertexDescriptor =
      MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

    let pipelineState: MTLRenderPipelineState
    do {
      pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
      self.pipelineState = pipelineState
    } catch {
      fatalError("Mesh pipeline state not created \(error.localizedDescription)")
    }

    // MARK: - Mesh PSO

    let meshDescriptor = MTLMeshRenderPipelineDescriptor()
    let objectFunction = library.makeFunction(name: "objectMain")
    meshDescriptor.objectFunction = objectFunction
    meshDescriptor.meshFunction = library.makeFunction(name: "meshMain")
    meshDescriptor.fragmentFunction = library.makeFunction(name: "fragmentMesh")

    meshDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    meshDescriptor.depthAttachmentPixelFormat = .depth32Float

    /* - doesn't seem to be necessary
    meshDescriptor.payloadMemoryLength = MemoryLayout<VertexAttribute>.stride * mesh.vertexCount
    meshDescriptor.maxTotalThreadsPerObjectThreadgroup = 1 // one triangle per vertex
    meshDescriptor.maxTotalThreadsPerMeshThreadgroup = 3 // one triangle
     */

    let meshPSO: MTLRenderPipelineState
    do {
      (meshPSO, _) = try device.makeRenderPipelineState(descriptor: meshDescriptor, options: [])
    } catch {
      fatalError("Mesh pipeline state not created \(error.localizedDescription)")
    }
    self.meshPipelineState = meshPSO

/*
    // - Apple
    // Object Shader Limits
    // 16kb payload size limit
    // Mesh grid size limit is 1024 threadgroups

    // Mesh Shader Limits
    // 256 vertices
    // 512 primitives
    // total size limit of mesh is 16kb
*/

    let depthDescriptor = MTLDepthStencilDescriptor()
    depthDescriptor.depthCompareFunction = .less
    depthDescriptor.isDepthWriteEnabled = true
    guard let depthStencilState = device.makeDepthStencilState(descriptor: depthDescriptor) else {
      fatalError("Depth stencil state not created")
    }
    self.depthStencilState = depthStencilState
    super.init()
    metalView.delegate = self
    metalView.device = device
    metalView.depthStencilPixelFormat = .depth32Float
    metalView.clearColor = MTLClearColor(red: 0.93, green: 0.97,
                                         blue: 1.0, alpha: 1)
    mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)
  }

  func setPrimitiveType(_ primitiveType: Options) {
    switch primitiveType {
    case .line:
      self.primitiveType = .line
    case .triangle:
      self.primitiveType = .triangle
    }
  }
}

extension Renderer: MTKViewDelegate {
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    projectionMatrix = float4x4(
      projectionFov: fov.degreesToRadians,
      near: 0.1,
      far: 100,
      aspect: Float(size.width) / Float(size.height),
      lhs: false)
    viewMatrix = float4x4(translation: [0, 0, -2.8])
    modelMatrix = matrix_identity_float4x4
  }

  func draw(in view: MTKView) {
    guard let commandBuffer = commandQueue.makeCommandBuffer(),
          let renderPassDescriptor = view.currentRenderPassDescriptor,
          let drawable = view.currentDrawable,
          let renderEncoder =
            commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
      return
    }
    renderEncoder.setRenderPipelineState(pipelineState)
    renderEncoder.setDepthStencilState(depthStencilState)

    renderEncoder.setCullMode(.back)

    var matrix = projectionMatrix * viewMatrix * modelMatrix
    renderEncoder.setVertexBytes(&matrix, length: MemoryLayout<float4x4>.stride, index: 1)
    renderEncoder.setVertexBuffer(
      sphereMesh.vertexBuffers[0].buffer,
      offset: 0, index: 0)
    guard let submesh = sphereMesh.submeshes.first else { return }
    var color = float3(0, 1, 0)
    renderEncoder.setFragmentBytes(&color, length: MemoryLayout<float3>.stride, index: 1)
    renderEncoder.drawIndexedPrimitives(
      type: primitiveType,
      indexCount: submesh.indexCount,
      indexType: submesh.indexType,
      indexBuffer: submesh.indexBuffer.buffer,
      indexBufferOffset: 0)

    // render the points
    color = float3(1, 0, 0)
    renderEncoder.setFragmentBytes(&color, length: MemoryLayout<float3>.stride, index: 1)
    renderEncoder.drawIndexedPrimitives(
      type: .point,
      indexCount: submesh.indexCount,
      indexType: submesh.indexType,
      indexBuffer: submesh.indexBuffer.buffer,
      indexBufferOffset: 0)

    renderEncoder.endEncoding()

    renderPassDescriptor.colorAttachments[0].loadAction = .load
    
    // For rendering mesh objects without sphere
    // renderPassDescriptor.colorAttachments[0].loadAction = .clear

    // MARK: - Mesh Encoder
    let meshEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
    meshEncoder.setRenderPipelineState(meshPipelineState)
    meshEncoder.setDepthStencilState(depthStencilState)

    meshEncoder.setObjectBuffer(sphereMesh.vertexBuffers[0].buffer, offset: 0, index: 0)
    meshEncoder.setObjectBytes(&matrix, length: MemoryLayout<float4x4>.stride, index: 1)

    color = float3(0, 0, 1)
    meshEncoder.setFragmentBytes(&color, length: MemoryLayout<float3>.stride, index: 1)
    meshEncoder.setMeshBytes(&matrix, length: MemoryLayout<float4x4>.stride, index: 1)

    let threadgroupsPerGrid = MTLSize(width: meshVertexCount, height: 1, depth: 1) // number of mesh instances ie no of vertices

    let threadsPerObjectThreadgroup = MTLSize(width: 1, height: 1, depth: 1) // one triangle per object vertex
    let threadsPerMeshThreadgroup = MTLSize(width: 3, height: 1, depth: 1) // three vertices per triangle

    if primitiveType == .line {
      meshEncoder.setTriangleFillMode(.lines)
    } else {
      meshEncoder.setTriangleFillMode(.fill)
    }
    meshEncoder.setFrontFacing(.clockwise)
    meshEncoder.setCullMode(.back)
    meshEncoder.drawMeshThreadgroups(
      threadgroupsPerGrid,
      threadsPerObjectThreadgroup: threadsPerObjectThreadgroup,
      threadsPerMeshThreadgroup: threadsPerMeshThreadgroup)

    meshEncoder.endEncoding()

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}

