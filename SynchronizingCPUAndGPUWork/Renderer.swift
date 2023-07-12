//
//  Renderer.swift
//  CustomMetalView
//
//  Created by Simon Anderson on 8/01/21.
//

import Foundation
import MetalKit
import SwiftUI
import simd

/// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs match
/// Metal API buffer set calls.
//enum AAPLVertexInputIndex : Int
//{
//    case AAPLVertexInputIndexVertices = 0
//    case AAPLVertexInputIndexViewportSize = 1
//}
//
//struct AAPLVertex {
//    var position:simd_float2
//    var color: simd_float4
//}

// Helper function when using C enums with Swift
extension AAPLVertexInputIndex {
    var index: Int {
      return Int(rawValue)
    }
}

struct AAPLTriangle {
    var position: simd_float2 = [0,0]
    var color: simd_float4 = [0,0,0,0]
    
    static func vertices() -> Array<AAPLVertex> {
        let TriangleSize:Float = 64
        let triangleVertices:[AAPLVertex] =
        [
            // Pixel Positions,                          RGBA colors.
            AAPLVertex(position: [ -0.5*TriangleSize, -0.5*TriangleSize ], color: [ 1, 1, 1, 1 ] ),
            AAPLVertex(position: [  0.0*TriangleSize, +0.5*TriangleSize ], color: [ 1, 1, 1, 1 ] ),
            AAPLVertex(position: [ +0.5*TriangleSize, -0.5*TriangleSize ], color: [ 1, 1, 1, 1 ] )
        ]
        return triangleVertices
    }
    
    static func vertexCount() -> Int {
        return 3
    }
}

/// The maximum number of frames in flight.
let MaxFramesInFlight: Int = 3

/// The number of triangles in the scene, determined to fit the screen.
let NumTriangles:Int = 3_000_000


class Renderer : NSObject, MTKViewDelegate {
    
    /// A semaphore used to ensure that buffers read by the GPU are not simultaneously written by the CPU.
    var _inFlightSemaphore: DispatchSemaphore
    
    /// A series of buffers containing dynamically-updated vertices.
//    var _vertexBuffers: Array<MTLBuffer>
    var _vertexBuffers: [MTLBuffer?] = [MTLBuffer?](repeating: nil, count: MaxFramesInFlight)
    
    /// The index of the Metal buffer in _vertexBuffers to write to for the current frame.
    var _currentBuffer: Int = 0
    
    /// View that will be displaying what is rendered
    var parent: MetalView
    
    /// property that access the view. This view is the MTKView wraooed in the SwiftMTKView
    var view: MTKView!
    
    var device: MTLDevice!
    
    /// The command queue used to pass commands to the device
    var commandQueue: MTLCommandQueue!
    
    /// Holds all the compiled metal files
    var metalLibrary: MTLLibrary!
    
    /// The render pipeline generated from the vertex and fragment shader in the .metal shader file
    var _pipelineState : MTLRenderPipelineState!
    
    /// The current size of the view, used as an input to the vertex shader
    /// Initialises the variable, as it will have its values populated on init
    var viewportSize: simd_float2 = simd_float2()
    
    var _triangles:Array<AAPLTriangle> = []
    
    var _totalVertexCount:Int = 0
    
    var _wavePosition:Float = 0
    
    /// SwiftMTKView is the wrapper to allow the MTKView to work in SwiftUI
    init(_ parent: MetalView, mtkView:MTKView)
    {
        // Ask for the default Metal device
        if let defaultDevice = MTLCreateSystemDefaultDevice() { device = defaultDevice }
        else { print("Metal is not supported") }
        
        // Sets the SwiftMTKView as the parent
        self.parent = parent
        self.view = mtkView
        view.device = device
        view.sampleCount = 1
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0.35, 0.35, 0.35, 1)
        
        
        _inFlightSemaphore = DispatchSemaphore(value: MaxFramesInFlight)
        
        /// Compiles all .metal files together into one
        metalLibrary = device.makeDefaultLibrary()

        // Loads the vertex shader.
        let vertexFunction = metalLibrary!.makeFunction(name: "vertexShader")

        // Loads the fragment shader.
        let fragmentFunction = metalLibrary!.makeFunction(name: "fragmentShader")
        
        // Create a reusable pipeline state object.
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "MyPipeline"
        pipelineStateDescriptor.vertexFunction = vertexFunction
        pipelineStateDescriptor.fragmentFunction = fragmentFunction
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        
        pipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            try  _pipelineState = device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        }
        catch {
            print("Failed to create pipeline state")
        }
        
        // Create the command queue
        commandQueue = device.makeCommandQueue()!
        
        // Could use drawable size instead of setting the viewSize manually
        viewportSize.x = Float(view.frame.size.width)
        viewportSize.y = Float(view.frame.size.height)
        
        super.init()
        
        // Sets the drawing delegate of the view.
        view.delegate = self
        
        // Generate the triangles rendered by the app.
        self.generateTriangles()
        
        // Calculate vertex data and allocate vertex buffers.
        _totalVertexCount = _triangles.count * AAPLTriangle.vertexCount()
        
        let triangleVertexBufferSize: Int = _totalVertexCount * MemoryLayout<AAPLTriangle>.stride
        
        for bufferIndex in 0..<MaxFramesInFlight {
            _vertexBuffers[bufferIndex] = device.makeBuffer(length: triangleVertexBufferSize, options: .storageModeShared)!
            _vertexBuffers[bufferIndex]!.label = "Vertex Buffer \(bufferIndex)"
        }
    }

    /// Generates an array of triangles, initializing each and inserting it into `_triangles`.
    func generateTriangles() {
        // Array of colors.
        let Colors: Array<simd_float4> = [
            [ 1.0, 0.0, 0.0, 1.0 ],  // Red
            [ 0.0, 1.0, 0.0, 1.0 ],  // Green
            [ 0.0, 0.0, 1.0, 1.0 ],  // Blue
            [ 1.0, 0.0, 1.0, 1.0 ],  // Magenta
            [ 0.0, 1.0, 1.0, 1.0 ],  // Cyan
            [ 1.0, 1.0, 0.0, 1.0 ],  // Yellow
        ]

        let NumColors: Int = Colors.count

        // Horizontal spacing between each triangle.
        let horizontalSpacing: Float = 16

        // Create the array of triangles
        var triangles:Array<AAPLTriangle> = Array(repeating: AAPLTriangle(),
                                                  count: NumTriangles)
        
        // Initialize each triangle.
        for t in 0..<NumTriangles {
            var trianglePosition: simd_float2 = triangles[t].position

            // Determine the starting position of the triangle in a horizontal line.
            trianglePosition.x = ((-Float(NumTriangles) / 2.0) + Float(t)) * horizontalSpacing
            trianglePosition.y = 0.0;
            
            // Updates the triangle
            triangles[t].position = trianglePosition
            triangles[t].color = Colors[t % NumColors]
        }
        _triangles = triangles;
    }
    
    func updateState() {
        // Simplified wave properties.
        let waveMagnitude:Float = 128.0  // Vertical displacement.
        let waveSpeed:Float     = 0.05   // Displacement change from the previous frame.

        // Increment wave position from the previous frame
        _wavePosition += waveSpeed;

        // Vertex data for a single default triangle.
        let triangleVertices = AAPLTriangle.vertices()
        let triangleVertexCount:Int = AAPLTriangle.vertexCount()

        // Vertex data for the current triangles.
        let currentTriangleVertices = _vertexBuffers[_currentBuffer]!.contents().assumingMemoryBound(to: AAPLVertex.self)
        
        // Update each triangle.
        for triangle in 0..<_triangles.count
        {
            var trianglePosition = _triangles[triangle].position

            // Displace the y-position of the triangle using a sine wave.
            trianglePosition.y = (sin(trianglePosition.x/waveMagnitude + _wavePosition) * waveMagnitude);

            // Update the position of the triangle.
            _triangles[triangle].position = trianglePosition;

            // Update the vertices of the current vertex buffer with the triangle's new position.
            for vertex in 0..<triangleVertexCount {
                let currentVertex:Int = vertex + (triangle * triangleVertexCount);
                currentTriangleVertices[currentVertex].position = triangleVertices[vertex].position + _triangles[triangle].position;
                currentTriangleVertices[currentVertex].color = _triangles[triangle].color;
            }
        }
    }
    
    // [Built in]
    // Updates the view's contents upon receiving a change in layout, resolution, or size
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Regenerate the triangles.
        self.generateTriangles()
        
        // Save the size of the drawable as you'll pass these
        // values to the vertex shader when you render.
        viewportSize.x = Float(size.width)
        viewportSize.y = Float(size.height)
    }
    
    // [Built in]
    func draw(in view: MTKView) {
        
        // Wait to ensure only `MaxFramesInFlight` number of frames are getting processed
        // by any stage in the Metal pipeline (CPU, GPU, Metal, Drivers, etc.).
        _ = _inFlightSemaphore.wait(timeout: .distantFuture)
        
        // Iterate through the Metal buffers, and cycle back to the first when you've written to the last.
        _currentBuffer = (_currentBuffer + 1) % MaxFramesInFlight

        // Update buffer data.
        updateState()
        
        // Create a new command buffer for each rendering pass to the current drawable.
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Command Buffer failed to initialise"); return
        }
        commandBuffer.label = "MyCommand"
        
        // Obtain a renderPassDescriptor generated from the view's drawable textures.
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        
        // Create a render command encoder.
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderEncoder.label = "MyRenderEncoder"
        
        // Set render command encoder state.
        renderEncoder.setRenderPipelineState(_pipelineState)
        
        // Set the current vertex buffer.
        renderEncoder.setVertexBuffer(_vertexBuffers[_currentBuffer],
                                      offset: 0, index: AAPLVertexInputIndexVertices.index)
        
        // Set the render region
        renderEncoder.setViewport(MTLViewport(originX: 0.0,
                                              originY: 0.0,
                                              width: Double(viewportSize.x),
                                              height: Double(viewportSize.y),
                                              znear: 0.0,
                                              zfar: 1.0))
        
        // Set the viewport size.
        renderEncoder.setVertexBytes(&viewportSize,
                                     length: MemoryLayout<simd_float2>.stride,
                                     index: AAPLVertexInputIndexViewportSize.index)

        // Draw the triangle vertices.
        renderEncoder.drawPrimitives(type: .triangle,
                                     vertexStart: 0,
                                     vertexCount: _totalVertexCount)
        
        
        renderEncoder.endEncoding()
        
        // Schedules a present once the framebuffer is complete using the current drawable.
        commandBuffer.present(view.currentDrawable!)
        
        // Add a completion handler that signals `_inFlightSemaphore` when Metal and the GPU have fully
        // finished processing the commands that were encoded for this frame.
        // This completion indicates that the dynamic buffers that were written-to in this frame, are no
        // longer needed by Metal and the GPU; therefore, the CPU can overwrite the buffer contents
        // without corrupting any rendering operations.
        let blockSemaphore = _inFlightSemaphore;
        
        commandBuffer.addCompletedHandler { _ in
            blockSemaphore.signal()
         }

        // Finalize CPU work and submit the command buffer to the GPU.
        commandBuffer.commit()
    }
}
