//
//  SwiftUIMetalView.swift
//  CustomMetalView
//
//  Created by Simon Anderson on 7/01/21.
//

import Foundation
import MetalKit
import SwiftUI

/// Setting up the file to work on OSX or IOS
#if os(OSX)
typealias ViewRepresentable = NSViewRepresentable
typealias ViewRepresentableContext = NSViewRepresentableContext
#elseif os(iOS)
typealias ViewRepresentable = UIViewRepresentable
typealias ViewRepresentableContext = UIViewRepresentableContext
#endif

// Creating a new MetalView object that will work in SwiftUI
struct MetalView: ViewRepresentable {

    /// The view model which will recieve input from the user, and pass it into the scene.
//    @Binding var viewModel: ViewModel
    
    func makeCoordinator() -> Renderer {
        let mtkView = MTKView()
        
        // Retrieves a metal device that will do the processing
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            mtkView.device = metalDevice
        }
        return Renderer(self, mtkView: mtkView)
    }
    
    #if os(OSX)
    
    func makeNSView(context: ViewRepresentableContext<MetalView>) -> MTKView {
        return context.coordinator.view
    }
    
    func updateNSView(_ nsView: MTKView, context: ViewRepresentableContext<MetalView>) {
    }
    
    #elseif os(iOS)
    
    func makeUIView(context: ViewRepresentableContext<MetalView>) -> MTKView {
        return context.coordinator.view
    }
    
    func updateUIView(_ uiView: MTKView, context: ViewRepresentableContext<MetalView>) {
    }
    
    #endif
}

