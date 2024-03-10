//
//  SimRenderer.swift
//  ALVRClient
//
//

import CompositorServices
import Metal
import MetalKit
import simd
import Spatial
import ARKit
import VideoToolbox
import ObjectiveC

extension Renderer {
    
    func startSimRenderLoop() {
        Task {
            let foveationVars = FoveationVars(
                enabled: false,
                targetEyeWidth: 0,
                targetEyeHeight: 0,
                optimizedEyeWidth: 0,
                optimizedEyeHeight: 0,
                eyeWidthRatio: 0,
                eyeHeightRatio: 0,
                centerSizeX: 0,
                centerSizeY: 0,
                centerShiftX: 0,
                centerShiftY: 0,
                edgeRatioX: 0,
                edgeRatioY: 0
            )
            videoFramePipelineState_YpCbCrBiPlanar = try! Renderer.buildRenderPipelineForVideoFrameWithDevice(
                                device: device,
                                layerRenderer: layerRenderer,
                                mtlVertexDescriptor: mtlVertexDescriptor,
                                foveationVars: foveationVars,
                                variantName: "YpCbCrBiPlanar"
            )
          
            let renderThread = Thread {
                self.renderSimLoop()
            }
            renderThread.name = "Render Thread"
            renderThread.start()
        }
    }
    
    func renderLobby(drawable: LayerRenderer.Drawable, commandBuffer: MTLCommandBuffer) {
        self.updateDynamicBufferState()
        
        self.updateGameState(drawable: drawable)

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.colorTextures[0]
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        renderPassDescriptor.depthAttachment.texture = drawable.depthTextures[0]
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .store
        renderPassDescriptor.depthAttachment.clearDepth = 0.0
        renderPassDescriptor.rasterizationRateMap = drawable.rasterizationRateMaps.first
        if layerRenderer.configuration.layout == .layered {
            renderPassDescriptor.renderTargetArrayLength = drawable.views.count
        }
        
        /// Final pass rendering code here
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            fatalError("Failed to create render encoder")
        }
    
        renderEncoder.label = "Primary Render Encoder"
        
        renderEncoder.pushDebugGroup("Draw Box")
        
        renderEncoder.setCullMode(.back)
        
        renderEncoder.setFrontFacing(.counterClockwise)
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        renderEncoder.setDepthStencilState(depthStateGreater)
        
        renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)

        let viewports = drawable.views.map { $0.textureMap.viewport }
        
        renderEncoder.setViewports(viewports)
        
        if drawable.views.count > 1 {
            var viewMappings = (0..<drawable.views.count).map {
                MTLVertexAmplificationViewMapping(viewportArrayIndexOffset: UInt32($0),
                                                  renderTargetArrayIndexOffset: UInt32($0))
            }
            renderEncoder.setVertexAmplificationCount(viewports.count, viewMappings: &viewMappings)
        }

        
        ///Actually different code
        for (index, element) in mesh.vertexDescriptor.layouts.enumerated() {
            guard let layout = element as? MDLVertexBufferLayout else {
                return
            }
            
            if layout.stride != 0 {
                let buffer = mesh.vertexBuffers[index]
                renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
            }
        }
        
        renderEncoder.setFragmentTexture(colorMap, index: TextureIndex.color.rawValue)
        
        for submesh in mesh.submeshes {
            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
            
        }
        
        renderEncoder.popDebugGroup()
        
        renderEncoder.endEncoding()
    }
    
    private func updateGameState(drawable: LayerRenderer.Drawable) {
        /// Update any game state before rendering
        guard world.worldTracking.state == .running else { return }
        //let anchorDistance = WorldTracker.shared.deviceDistanceFromAnchor()
        Task {
            //await WorldTracker.shared.processWorldTrackingUpdates()
        }
        let worldAnchorDistance = world.anchorDistanceFromOrigin(anchor: world.worldOriginAnchor)
        let device = world.getDevice()
        let distanceFromCenter = world.deviceDistanceFromCenter(anchor: device!)
        //EventHandler.shared.updateAnchorDistance(anchorDistance)
        EventHandler.shared.updateWorldAnchorDistance(worldAnchorDistance)
        EventHandler.shared.updateDistanceFromCenter(distanceFromCenter)
        let rotationAxis = SIMD3<Float>(1, 1, 0)
        let modelRotationMatrix = matrix4x4_rotation(radians: rotation, axis: rotationAxis)
        let modelTranslationMatrix = matrix4x4_translation(0.0, 0.0, -8.0)
        let modelMatrix = modelTranslationMatrix * modelRotationMatrix
        
        let simdDeviceAnchor = device?.originFromAnchorTransform ?? matrix_identity_float4x4

        func uniforms(forViewIndex viewIndex: Int) -> Uniforms {
            let view = drawable.views[viewIndex]
            let viewMatrix = simdDeviceAnchor
            let viewMatrixFrame = simdDeviceAnchor
            let projection = ProjectiveTransform3D(leftTangent: Double(view.tangents[0]),
                                                   rightTangent: Double(view.tangents[1]),
                                                   topTangent: Double(view.tangents[2]),
                                                   bottomTangent: Double(view.tangents[3]),
                                                   nearZ: Double(drawable.depthRange.y),
                                                   farZ: Double(drawable.depthRange.x),
                                                   reverseZ: true)
            
            return Uniforms(projectionMatrix: .init(projection),  modelViewMatrix: viewMatrix, tangents: view.tangents)
        }
        
        self.uniforms[0].uniforms.0 = uniforms(forViewIndex: 0)
        if drawable.views.count > 1 {
            self.uniforms[0].uniforms.1 = uniforms(forViewIndex: 1)
        }
        
        rotation += 0.01
    }
    
    func renderSimFrame() {
        /// Per frame updates hare
        guard let frame = layerRenderer.queryNextFrame() else { return }
        
        frame.startUpdate()
        
        frame.endUpdate()
        
        guard let timing = frame.predictTiming() else { return }
        LayerRenderer.Clock().wait(until: timing.optimalInputTime)

        //LayerRenderer.Clock().wait(until: timing.optimalInputTime)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fatalError("Failed to create command buffer")
        }
        
        guard let drawable = frame.queryDrawable() else { return }
        
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        frame.startSubmission()
        
        if drawable.deviceAnchor == nil {
            
            let time = LayerRenderer.Clock.Instant.epoch.duration(to: drawable.frameTiming.presentationTime).timeInterval
            world.sendTracking(targetTimestamp: time)
            drawable.deviceAnchor = world.queryDevice(time)
        }
        
        let semaphore = inFlightSemaphore
        commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
            semaphore.signal()
        }
        
        
        renderLobby(drawable: drawable, commandBuffer: commandBuffer)
        
        drawable.encodePresent(commandBuffer: commandBuffer)
        commandBuffer.commit()
        frame.endSubmission()
    }
    
    func renderSimLoop() {
        layerRenderer.waitUntilRunning()
        EventHandler.shared.renderStarted = true
      //  EventHandler.shared.handleHeadsetRemovedOrReentry()
       // var timeSinceLastLoop = CACurrentMediaTime()
        while EventHandler.shared.renderStarted {
            if layerRenderer.state == .invalidated {
                print("Layer is invalidated")
                //EventHandler.shared.stop()
              //  EventHandler.shared.handleHeadsetRemovedOrReentry()
             //   EventHandler.shared.handleHeadsetRemoved()
             //   WorldTracker.shared.resetPlayspace()
                //alvr_pause()

                // visionOS sometimes sends these invalidated things really fkn late...
                // But generally, we want to exit fully when the user exits.
                
                break
            } else if layerRenderer.state == .paused {
                layerRenderer.waitUntilRunning()
                //EventHandler.shared.handleHeadsetRemovedOrReentry()
                continue
            } else {
                autoreleasepool {
                    self.renderSimFrame()
                }
            }
        }
    }
    
    // Generic matrix math utility functions
    func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
        let unitAxis = normalize(axis)
        let ct = cosf(radians)
        let st = sinf(radians)
        let ci = 1 - ct
        let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
        return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                             vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                             vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                             vector_float4(                  0,                   0,                   0, 1)))
    }

    func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
        return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                             vector_float4(0, 1, 0, 0),
                                             vector_float4(0, 0, 1, 0),
                                             vector_float4(translationX, translationY, translationZ, 1)))
    }

    func radians_from_degrees(_ degrees: Float) -> Float {
        return (degrees / 180) * .pi
    }

    
}

