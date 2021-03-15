//
//  ViewController.swift
//  Ripple
//
//  Created by Laszlo Nagy on 14/03/2021.
//

import UIKit
import Metal
import simd

class ViewController: UIViewController {
    
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var samplerState: MTLSamplerState!
    var pso: MTLRenderPipelineState!
    var timer: CADisplayLink!
    var backgroundImage: Renderer.Texture!
    var renderer: Renderer!
    var rippleManager: RippleManager = RippleManager(lifeTimeInSeconds: 10)
    
    var resolution: simd_float2!
    
    override func viewDidLoad() {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(didTap))
        view.addGestureRecognizer(recognizer)
        
        renderer = Renderer(view: view)
        
        timer = CADisplayLink(target: self, selector: #selector(renderFunc))
        timer.add(to: RunLoop.main, forMode: .default)
        
        commandQueue = renderer.createCommandQueue()
        let shader = renderer.compileShader(vertexMain: "rippleVertex", pixelMain: "rippleFragment")
        pso = renderer.createPipelineState(shader: shader!)
        samplerState = renderer.createDefaultSamplerState()
        
        //backgroundImage = renderer.createAndLoadTexture(resourceName: "harold", xtension: "jpg", flip: false)
        backgroundImage = renderer.createAndLoadTexture(resourceName: "company", xtension: "png", flip: false)
        
        resolution = simd_float2(Float(view.frame.size.width), Float(view.frame.size.height))
    }
    
    @objc func renderFunc() {
        autoreleasepool {
            guard let drawable = renderer.getLayer().nextDrawable() else {
                return
            }
            
            let renderPassDescriptor = renderer.createRenderPassDescriptor(drawable: drawable, red: 0.392, green: 0.584, blue: 0.929)
                 
            let cmdBuf = commandQueue.makeCommandBuffer()!
            let renderEncoder = cmdBuf.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            //this is actually interesting. I am not doing a vertex buffer submission, and as you can see, I actually
            //omitted it from the code for a good reason. The reason is being sending always 3-4 vertices over PCI bus
            //can (not will, mind you!!!) be slow. First of all it is just easier to use math to create a fullscreen
            //triangle and second, it is even easier to do it from vertex shader, thus eliminating the need to send
            //anything, potentially gaining a small perf boost. In this case, it was mostly for convenience, than perf,
            //because the perf win in this case is mostly negligible. Still, a nice thing in a toolbox. Just set vertex
            //count to 3, instance count to 1, triangle type and fire it away. For the other part of this, refer to the
            //vertex shader.
            renderEncoder.setRenderPipelineState(pso)
            renderEncoder.setFragmentTexture(backgroundImage.texture, index: 0)
            renderEncoder.setFragmentSamplerState(samplerState, index: 0)
            
            let argumentIndex = 0
            renderEncoder.setFragmentBytes(&resolution, length: MemoryLayout<simd_float2>.stride, index: argumentIndex)
            _ = rippleManager.updateAndReturnRipples(renderEncoder: renderEncoder, startArgumentIndex: argumentIndex + 1)
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
            renderEncoder.endEncoding()
            
            cmdBuf.present(drawable)
            cmdBuf.commit()
            
        }
    }
    
    @objc func didTap(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: view)
        rippleManager.addRipple(clickPosition: simd_float2(Float(Float(location.x) / resolution.x), 1 - Float(Float(location.y) / resolution.y)))
        
    }
}
