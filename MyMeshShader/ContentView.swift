//
//  ContentView.swift
//  MyMeshShader
//
//  Created by Caroline Begbie on 24/3/2023.
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

