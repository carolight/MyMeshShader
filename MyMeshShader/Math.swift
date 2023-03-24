//
//  Math.swift
//  MyMeshShader
//
//  Created by Caroline Begbie on 24/3/2023.
//

import Foundation
import simd

typealias float2 = SIMD2<Float>
typealias float3 = SIMD3<Float>
typealias float4 = SIMD4<Float>
typealias float4x4 = simd_float4x4

let π = Float.pi

extension Float {
  var radiansToDegrees: Float {
    (self / π) * 180
  }
  var degreesToRadians: Float {
    (self / 180) * π
  }
}

extension simd_float4x4 {
  // MARK: - Translate
  init(translation: float3) {
    let col1 = float4(1, 0, 0, 0)
    let col2 = float4(0, 1, 0, 0)
    let col3 = float4(0, 0, 1, 0)
    let col4 = float4(translation, 1)
    self = float4x4(col1, col2, col3, col4)
  }

  // MARK: - Rotate
  init(rotationX angle: Float) {
    let matrix = float4x4(
      [1,           0,          0, 0],
      [0,  cos(angle), sin(angle), 0],
      [0, -sin(angle), cos(angle), 0],
      [0,           0,          0, 1]
    )
    self = matrix
  }

  init(rotationY angle: Float) {
    let matrix = float4x4(
      [cos(angle), 0, -sin(angle), 0],
      [         0, 1,           0, 0],
      [sin(angle), 0,  cos(angle), 0],
      [         0, 0,           0, 1]
    )
    self = matrix
  }

  init(rotationZ angle: Float) {
    let matrix = float4x4(
      [ cos(angle), sin(angle), 0, 0],
      [-sin(angle), cos(angle), 0, 0],
      [          0,          0, 1, 0],
      [          0,          0, 0, 1]
    )
    self = matrix
  }

  init(rotationYXZ angle: float3) {
    let rotationX = float4x4(rotationX: angle.x)
    let rotationY = float4x4(rotationY: angle.y)
    let rotationZ = float4x4(rotationZ: angle.z)
    self = rotationY * rotationX * rotationZ
  }

  // MARK: - projection matrix
  init(projectionFov fov: Float, near: Float, far: Float, aspect: Float, lhs: Bool = true) {
    let y = 1 / tan(fov * 0.5)
    let x = y / aspect
    let z = lhs ? far / (far - near) : far / (near - far)
    let X = float4( x,  0,  0,  0)
    let Y = float4( 0,  y,  0,  0)
    let Z = lhs ? float4( 0,  0,  z, 1) : float4( 0,  0,  z, -1)
    let W = lhs ? float4( 0,  0,  z * -near,  0) : float4( 0,  0,  z * near,  0)
    self.init()
    columns = (X, Y, Z, W)
  }
}

