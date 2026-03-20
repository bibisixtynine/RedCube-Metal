#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4x4 modelViewProjectionMatrix;
    float4 instanceColor;
};

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float4 color [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float3 normal;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                             constant Uniforms *uniforms [[buffer(1)]],
                             uint instanceID [[instance_id]]) {
    VertexOut out;
    out.position = uniforms[instanceID].modelViewProjectionMatrix * float4(in.position, 1.0);
    
    float4 color = uniforms[instanceID].instanceColor;
    if (color.a < 0.0) {
        out.color = in.color;
    } else {
        out.color = color;
    }
    
    // Pass normal (ideally should be transformed by normal matrix)
    out.normal = in.normal;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    // Basic Directional Lighting
    float3 lightDir = normalize(float3(1.0, 1.0, 1.0));
    float diff = max(dot(normalize(in.normal), lightDir), 0.2); // 0.2 for ambient
    return float4(in.color.rgb * diff, in.color.a);
}
