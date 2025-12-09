//
//  Shaders.metal
//  o1
//
//  Created by claude-4.5-opus-high-thinking on 2025-12-01.
//

#include <metal_stdlib>

using namespace metal;

struct GlyphInstance {
    uint glyph_id;
    float2 position;
    float4 uv;
    float2 size;
    float2 bearing;
    float4 fg_color;
    float4 bg_color;
};

struct GridUniforms {
    float2 viewport_size;
    float2 unit_size;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float4 fg_color;
    float4 bg_color;
};

vertex VertexOut terminal_vertex(uint vid [[vertex_id]], uint iid [[instance_id]], constant GlyphInstance* instances [[buffer(1)]], constant GridUniforms& uniforms [[buffer(0)]]) {
    GlyphInstance glyph = instances[iid];

    float2 quad[6] = {
        float2(0.0f, 0.0f),
        float2(1.0f, 0.0f),
        float2(0.0f, 1.0f),
        float2(1.0f, 0.0f),
        float2(1.0f, 1.0f),
        float2(0.0f, 1.0f),
    };

    float2 point = quad[vid];
    float2 pixel = glyph.position * uniforms.unit_size + glyph.bearing + point * glyph.size;
    float2 ndc = (pixel / uniforms.viewport_size) * 2.0f - 1.0f;

    VertexOut out = {
        .position = float4(ndc, 0.0f, 1.0f),
        .uv = mix(glyph.uv.xy, glyph.uv.zw, point),
        .fg_color = glyph.fg_color,
        .bg_color = glyph.bg_color,
    };

    return out;
}

fragment float4 terminal_fragment(VertexOut in [[stage_in]], texture2d<float> atlas [[texture(0)]], sampler s [[sampler(0)]]) {
    float mask = atlas.sample(s, in.uv).r;
    float3 rgb = in.fg_color.rgb * mask;
    float alpha = in.fg_color.a * mask;

    return float4(rgb, alpha);
}
