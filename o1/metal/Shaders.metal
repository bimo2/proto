//
//  Shaders.metal
//  o1
//
//  Created by claude-4.5-opus-high-thinking on 2025-12-01.
//

#include <metal_stdlib>

using namespace metal;

struct GridUniforms {
    float2 viewportSize;
    float2 cellSize;
    uint2 gridSize;
    float dotSize;
};

struct VertexOut {
    float4 position [[position]];
};

vertex VertexOut dotVertexShader(uint vertexID [[vertex_id]], uint instanceID [[instance_id]], constant GridUniforms &uniforms [[buffer(0)]]) {
    uint row = instanceID / uniforms.gridSize.x;
    uint column = instanceID % uniforms.gridSize.x;
    float2 center = float2((float(column) + 0.5f) * uniforms.cellSize.x, (float(row) + 0.5f) * uniforms.cellSize.y);
    float radius = uniforms.dotSize * 0.5f;

    float2 offsets[6] = {
        float2(-radius, -radius),
        float2(radius, -radius),
        float2(-radius, radius),
        float2(radius, -radius),
        float2(radius, radius),
        float2(-radius, radius),
    };

    float2 pixel = center + offsets[vertexID];
    float2 ndc = (pixel / uniforms.viewportSize) * 2.0f - 1.0f;

    ndc.y = -ndc.y;

    VertexOut out = {
        .position = float4(ndc, 0.0f, 1.0f),
    };

    return out;
}

fragment float4 dotFragmentShader(VertexOut in [[stage_in]]) {
    return float4(0.9f, 0.9f, 0.9f, 1.0f);
}
