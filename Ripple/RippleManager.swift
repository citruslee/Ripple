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
    
    //I split the times and ripple data in two for easier handling of GPU resources.
    //This way I don't need to do staggered reads over and over, nor need to copy
    //to separate buffer. It is a bit of an inconvenience but it works rather well
    //and keeps it simple
    var ripples: [RippleData] = []
    var startTimes: [Date] = []
    
    let timeToDie = Float(10.0)
        
    func addRipple(clickPosition: simd_float2) {
        ripples.append(RippleData(currentTime: 0, clickPosition: clickPosition))
        startTimes.append(Date())
    }
    
    func updateAndReturnRipples(renderEncoder: MTLRenderCommandEncoder, startArgumentIndex: Int) -> Int {
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
        return startArgumentIndex + 3
    }
    
    func pruneDeadRipples() {
        ripples = ripples.filter { ripple in
            return ripple.currentTime < timeToDie
        }
        startTimes = startTimes.filter { time in
            return Float(Date().timeIntervalSince(time) as Double) < timeToDie
        }
    }
}
