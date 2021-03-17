//
//  RippleManager.swift
//  Ripple
//
//  Created by Laszlo Nagy on 15/03/2021.
//

import UIKit
import simd

class RippleManager {
    
    struct RippleData {
        var currentTime: simd_float1
        var clickPosition: simd_float2
    }
    
    private var resolution: simd_float2!
    private var backgroundImage: Renderer.Texture!
    private var commandQueue: MTLCommandQueue!
    private var samplerState: MTLSamplerState!
    private var pso: MTLRenderPipelineState!

    private var ripples: [RippleData] = []
    private var startTimes: [Date] = []
    
    private var timeToDie: Float
    
    init(lifeTimeInSeconds: Float, renderer: Renderer, displayResolution: simd_float2) {
        timeToDie = lifeTimeInSeconds
        
        commandQueue = renderer.createCommandQueue()
        let shader = renderer.compileShader(vertexMain: "rippleVertex", pixelMain: "rippleFragment")
        pso = renderer.createPipelineState(shader: shader!)
        samplerState = renderer.createDefaultSamplerState()
        
        //backgroundImage = renderer.createAndLoadTexture(resourceName: "harold", xtension: "jpg", flip: false)
        backgroundImage = renderer.createAndLoadTexture(resourceName: "company", xtension: "png", flip: false)
        resolution = displayResolution
    }
      
    func addRipple(clickPosition: CGPoint) {
        ripples.append(RippleData(currentTime: 0, clickPosition: simd_float2(Float(Float(clickPosition.x) / resolution.x), 1 - Float(Float(clickPosition.y) / resolution.y))))
        startTimes.append(Date())
    }
    
    private func updateAndReturnRipples(renderEncoder: MTLRenderCommandEncoder, startArgumentIndex: Int) {
        ripples.indices.forEach { ripples[$0].currentTime = Float(Date().timeIntervalSince(startTimes[$0]) as Double) }
        pruneDeadRipples()
        var count = simd_float1(ripples.count)
        renderEncoder.setFragmentBytes(&count, length: MemoryLayout<simd_float1>.stride, index: startArgumentIndex)
        renderEncoder.setFragmentBytes(&ripples, length: MemoryLayout<RippleManager.RippleData>.stride * ripples.count, index: startArgumentIndex + 1)
        if ripples.count == 0 {
            var ripple = RippleManager.RippleData(currentTime: 0.0, clickPosition: simd_float2(0.0, 0.0))
            renderEncoder.setFragmentBytes(&ripple, length: MemoryLayout<RippleManager.RippleData>.stride, index: startArgumentIndex + 1)
        }
        var deathTimer = simd_float1(timeToDie)
        renderEncoder.setFragmentBytes(&deathTimer, length: MemoryLayout<simd_float1>.stride, index: startArgumentIndex + 2)
    }
    
    private func pruneDeadRipples() {
        ripples = ripples.filter { ripple in
            return ripple.currentTime < timeToDie
        }
        startTimes = startTimes.filter { time in
            return Float(Date().timeIntervalSince(time) as Double) < timeToDie
        }
    }
    
    func render(renderer: Renderer) {
        guard let drawable = renderer.getLayer().nextDrawable() else {
            return
        }
        let renderPassDescriptor = renderer.createRenderPassDescriptor(drawable: drawable, clearColour: UIColor.init(named: "ClearColour") ?? UIColor.black)
             
        guard let cmdBuf = commandQueue.makeCommandBuffer() else {
            return
        }
        guard let renderEncoder = cmdBuf.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            assertionFailure("Failed to create RenderEncoder")
            return
        }
        
        renderEncoder.setRenderPipelineState(pso)
        renderEncoder.setFragmentTexture(backgroundImage.texture, index: 0)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        
        let argumentIndex = 0
        renderEncoder.setFragmentBytes(&resolution, length: MemoryLayout<simd_float2>.stride, index: argumentIndex)
        updateAndReturnRipples(renderEncoder: renderEncoder, startArgumentIndex: argumentIndex + 1)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
        renderEncoder.endEncoding()
        
        cmdBuf.present(drawable)
        cmdBuf.commit()
    }
    
}
