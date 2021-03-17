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
    
    var timer: CADisplayLink!
    
    var renderer: Renderer?
    var rippleManager: RippleManager?
    
    override func viewDidLoad() {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(didTap))
        view.addGestureRecognizer(recognizer)
        
        timer = CADisplayLink(target: self, selector: #selector(renderFunc))
        timer.add(to: RunLoop.main, forMode: .default)
        
        renderer = Renderer(view: view)
        guard let renderer = renderer else {
            assertionFailure("Renderer failed to create")
            return
        }
        rippleManager = RippleManager(lifeTimeInSeconds: 10, renderer: renderer, displayResolution:  simd_float2(Float(view.frame.size.width), Float(view.frame.size.height)))
    }
    
    @objc func renderFunc() {
        autoreleasepool {
            guard let renderer = renderer else {
                assertionFailure("Renderer not present")
                return
            }
            rippleManager?.render(renderer: renderer)
        }
    }
    
    @objc func didTap(_ recognizer: UITapGestureRecognizer) {
        
        guard let ripple = rippleManager else {
            assertionFailure("RippleManager not present")
            return
        }
        let location = recognizer.location(in: view)
        ripple.addRipple(clickPosition: location)
    }
    
}
