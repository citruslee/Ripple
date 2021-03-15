//
//  Renderer.swift
//  Ripple
//
//  Created by Laszlo Nagy on 15/03/2021.
//

import Metal
import UIKit

class Renderer {
    
    struct Shader {
        var vertexShader: MTLFunction! = nil
        var pixelShader: MTLFunction! = nil
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
    
    var device: MTLDevice?
    var metalLayer: CAMetalLayer
    
    init(view: UIView) {
        device = MTLCreateSystemDefaultDevice()
        
        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.frame = view.layer.frame
        view.layer.addSublayer(metalLayer)
    }
    
    func compileShader(vertexMain: String, pixelMain: String) -> Shader! {
        guard let device = device else {
            assertionFailure("Device not present")
            return nil
        }
        
        let defaultLibrary = device.makeDefaultLibrary()!
        let vertexProgram = defaultLibrary.makeFunction(name: vertexMain)
        let fragmentProgram = defaultLibrary.makeFunction(name: pixelMain)
        return Shader(vertexShader: vertexProgram, pixelShader: fragmentProgram)
    }
    
    func createCommandQueue() -> MTLCommandQueue! {
        guard let device = device else {
            assertionFailure("Device not present")
            return nil
        }
        return device.makeCommandQueue()
    }
    
    func createPipelineState(shader: Shader) -> MTLRenderPipelineState! {
        guard let device = device else {
            assertionFailure("Device not present")
            return nil
        }
        
        let psoDesc = MTLRenderPipelineDescriptor()
        psoDesc.vertexFunction = shader.vertexShader
        psoDesc.fragmentFunction = shader.pixelShader
        psoDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        return try! device.makeRenderPipelineState(descriptor: psoDesc)
    }
    
    func createDefaultSamplerState() -> MTLSamplerState! {
        guard let device = device else {
            assertionFailure("Device not present")
            return nil
        }
        
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
        return device.makeSamplerState(descriptor: sampler)
    }
    
    func createRenderPassDescriptor(drawable: CAMetalDrawable, red: Double, green: Double, blue: Double) -> MTLRenderPassDescriptor {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        //cornflower blue, a nice colour from my direct3d days <3
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: red, green: green, blue: blue, alpha: 1.0)
        return renderPassDescriptor
    }
    
    func createAndLoadTexture(resourceName: String, xtension: String, flip: Bool) -> Texture! {
        guard let device = device else {
            assertionFailure("Device not present")
            return nil
        }
        
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
    
    func getLayer() -> CAMetalLayer {
        return metalLayer
    }
}
