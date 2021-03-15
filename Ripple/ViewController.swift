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
    var metalLayer: CAMetalLayer!
    var timer: CADisplayLink!
    var backgroundImage: Texture!
    
    var startTime: Date!
    var resolution: simd_float2!
    var clickPos: simd_float2!
    //I split the times and ripple data in two for easier handling of GPU resources.
    //This way I don't need to do staggered reads over and over, nor need to copy
    //to separate buffer. It is a bit of an inconvenience but it works rather well
    //and keeps it simple
    var ripples: [RippleData] = []
    var startTimes: [Date] = []
    
    struct RippleData {
        var currentTime: simd_float1
        var clickPos: simd_float2
    }
    
    struct Texture {
        var texture: MTLTexture! = nil
        var target: MTLTextureType
        var width: Int
        var height: Int
        var depth: Int
        var format: MTLPixelFormat
        var path: String
        let bytesPerPixel:Int = 4
        let bitsPerComponent:Int = 8
    }
        
    func createAndLoadTexture(resourceName: String, xtension: String, flip: Bool) -> Texture {
        var texture = Texture(target: .type2D, width: 0, height: 0, depth: 1, format: .rgba8Unorm, path: Bundle.main.path(forResource: resourceName, ofType: xtension) ?? "")
        
        let image = (UIImage(contentsOfFile: texture.path)?.cgImage)!
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        texture.width = image.width
        texture.height = image.height
        
        let rowBytes = texture.width * texture.bytesPerPixel
        
        let context = CGContext(data: nil, width: texture.width, height: texture.height, bitsPerComponent: texture.bitsPerComponent, bytesPerRow: rowBytes, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let bounds = CGRect(x: 0, y: 0, width: Int(texture.width), height: Int(texture.height))
        context.clear(bounds)
        
        if flip == false{
            context.translateBy(x: 0, y: CGFloat(texture.height))
            context.scaleBy(x: 1.0, y: -1.0)
        }
        
        context.draw(image, in: bounds)
        
        let texDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MTLPixelFormat.rgba8Unorm, width: Int(texture.width), height: Int(texture.height), mipmapped: false)
        texture.target = texDescriptor.textureType
        texture.texture = device.makeTexture(descriptor: texDescriptor)
        
        let pixelsData = context.data!
        let region = MTLRegionMake2D(0, 0, Int(texture.width), Int(texture.height))
        texture.texture.replace(region: region, mipmapLevel: 0, withBytes: pixelsData, bytesPerRow: Int(rowBytes))
        return texture
    }
    
    override func viewDidLoad() {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(didTap))
        view.addGestureRecognizer(recognizer)
        
        device = MTLCreateSystemDefaultDevice()
        
        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.frame = view.layer.frame
        view.layer.addSublayer(metalLayer)
        
        timer = CADisplayLink(target: self, selector: #selector(renderFunc))
        timer.add(to: RunLoop.main, forMode: .default)
        
        commandQueue = device.makeCommandQueue()
        
        let defaultLibrary = device.makeDefaultLibrary()!
        let vertexProgram = defaultLibrary.makeFunction(name: "rippleVertex")
        let fragmentProgram = defaultLibrary.makeFunction(name: "rippleFragment")
            
        let psoDesc = MTLRenderPipelineDescriptor()
        psoDesc.vertexFunction = vertexProgram
        psoDesc.fragmentFunction = fragmentProgram
        psoDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
            
        pso = try! device.makeRenderPipelineState(descriptor: psoDesc)
        
        let sampler = MTLSamplerDescriptor()
        sampler.minFilter = MTLSamplerMinMagFilter.nearest
        sampler.magFilter = MTLSamplerMinMagFilter.nearest
        sampler.mipFilter = MTLSamplerMipFilter.nearest
        sampler.maxAnisotropy = 1
        sampler.sAddressMode = MTLSamplerAddressMode.clampToEdge
        sampler.tAddressMode = MTLSamplerAddressMode.clampToEdge
        sampler.rAddressMode = MTLSamplerAddressMode.clampToEdge
        sampler.normalizedCoordinates = true
        sampler.lodMinClamp = 0
        sampler.lodMaxClamp = .greatestFiniteMagnitude
        samplerState = device.makeSamplerState(descriptor: sampler)
        
        //backgroundImage = createAndLoadTexture(resourceName: "harold", xtension: "jpg", flip: false)
        backgroundImage = createAndLoadTexture(resourceName: "company", xtension: "png", flip: false)
        
        resolution = simd_float2(Float(view.frame.size.width), Float(view.frame.size.height))
    }
    
    func updateRipples() {
        if ripples.count == 0 || startTimes.count == 0 {
            return
        }
        ripples.indices.forEach { ripples[$0].currentTime = Float(Date().timeIntervalSince(startTimes[$0]) as Double) }
        
    }
    
    @objc func renderFunc() {
        autoreleasepool {
            updateRipples()
            guard let drawable = metalLayer?.nextDrawable() else { return }
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            //cornflower blue, a nice colour from my direct3d days <3
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 100/255, green: 149.0/255.0, blue: 237.0/255.0, alpha: 1.0)
            
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
            var count = simd_float1(ripples.count)
            
            renderEncoder.setFragmentBytes(&resolution, length: MemoryLayout<simd_float2>.stride, index: 0)
            renderEncoder.setFragmentBytes(&count, length: MemoryLayout<simd_float1>.stride, index: 1)
            renderEncoder.setFragmentBytes(&ripples, length: MemoryLayout<RippleData>.stride * ripples.count, index: 2)
            if ripples.count == 0 {
                var rip = RippleData(currentTime: 0.0, clickPos: simd_float2(0.0, 0.0))
                renderEncoder.setFragmentBytes(&rip, length: MemoryLayout<RippleData>.stride, index: 2)
                print("setting up zero data")
            }
            print(MemoryLayout<RippleData>.stride * ripples.count)
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
            renderEncoder.endEncoding()
            
            cmdBuf.present(drawable)
            cmdBuf.commit()
        }
    }
    
    @objc func didTap(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: view)
        
        clickPos = simd_float2(Float(Float(location.x) / resolution.x), 1 - Float(Float(location.y) / resolution.y))
        print(clickPos ?? 0.0)
        ripples.append(RippleData(currentTime: 0, clickPos: clickPos))
        startTimes.append(Date())
    }
}
