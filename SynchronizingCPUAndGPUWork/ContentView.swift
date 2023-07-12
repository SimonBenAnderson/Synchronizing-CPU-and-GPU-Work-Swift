//
//  ContentView.swift
//  SynchronizingCPUAndGPUWork
//
//  Created by Simon Anderson on 11/07/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            MetalView()
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
