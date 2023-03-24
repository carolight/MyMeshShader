//
//  Shaders.metal
//  MyMeshShader
//
//  Created by Caroline Begbie on 24/3/2023.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float3 position [[attribute(0)]];
  float3 normal [[attribute(1)]];
  float2 uvs [[attribute(2)]];
};

struct VertexOut {
  float4 position [[position]];
  float3 normal;
  float pointSize [[point_size]];
};

vertex VertexOut vertexMain(const VertexIn in [[stage_in]],
                            constant float4x4 &pvm [[buffer(1)]]) {
  VertexOut out {
    .position = pvm * float4(in.position, 1) ,
    .normal = in.normal,
    .pointSize = 5
  };
  return out;
}

fragment float4 fragmentColor(VertexOut in [[stage_in]],
                              constant float3 &color [[buffer(1)]]) {
  return float4(1.0 - (normalize(in.normal) * 0.5 + 0.5), 1);
  //return float4(color, 1);
}

struct ObjectInput {
  packed_float3 position;
  packed_float3 normal;
  simd_float2 uvs;
};

struct ObjectOutput {
  float4 position;
  float3 normal;
};

[[object]]
void objectMain(object_data ObjectOutput &payload [[payload]],
                const device ObjectInput *inputData [[buffer(0)]],
                constant float4x4 &pvm [[buffer(1)]],
                uint index [[thread_position_in_grid]],
                uint tid [[thread_index_in_threadgroup]],
                mesh_grid_properties mgp
                ) {

  ObjectOutput output;
  uint i = index;
  output.position = float4(inputData[i].position, 1);
  output.normal = inputData[i].normal;

  payload = output;

  // Apple says:
  // Set the output submesh count for the mesh shader.
  // Because the mesh shader is only producing one mesh, the threadgroup grid size is 1x1x1.
  if (tid == 0)
    mgp.set_threadgroups_per_grid(uint3(1, 1, 1));
}

struct VertexData { float4 position [[position]]; };
struct PrimitiveData { float4 color; };
using MeshTriangle = metal::mesh<
  VertexData,                 // Vertex type (like output of vertex shader)
  PrimitiveData,              // data for each primitive
  3,                         // maximum vertices
  1,                          // maximum primitives
  metal::topology::triangle   // topology
>;

[[mesh]]
void meshMain(MeshTriangle outputMesh,
              const object_data ObjectOutput &payload [[payload]],
              uint gid [[threadgroup_position_in_grid]],
              uint tid [[thread_index_in_threadgroup]],
              uint xtid [[thread_position_in_threadgroup]], // seems to be the same as tid
              constant float4x4 &pvm [[buffer(1)]])
{

  float4 v1 = float4(-0.01, 0, 0, 0);
  float4 v2 = float4(0, 0.1, 0, 0);
  float4 v3 = float4(0.01, 0, 0, 0);
  float4 vertices[3] = {v1, v2, v3};

  VertexData v;
  v.position = pvm * (payload.position + vertices[tid]);

  if (tid < 3) {
    outputMesh.set_vertex(tid, v);
    outputMesh.set_index(tid, tid);  // don't have to calculate indices as there is only one triangle
  }

  if (tid == 0) {
    PrimitiveData p;
    p.color = float4(1, 0, 1, 1);
    outputMesh.set_primitive(tid, p);
    outputMesh.set_primitive_count(1);
  }
}

struct FragmentIn {
  VertexData v;
  PrimitiveData p;
};

fragment float4 fragmentMesh(FragmentIn in [[stage_in]],
                             constant float3 &color [[buffer(1)]]) {
  return in.p.color;
}

