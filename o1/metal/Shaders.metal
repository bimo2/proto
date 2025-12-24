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
    float2 cell_size;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float4 fg_color;
    float4 bg_color;
    bool background;
};

vertex VertexOut terminal_vertex(uint vid [[vertex_id]], uint iid [[instance_id]], constant GlyphInstance* instances [[buffer(1)]], constant GridUniforms& uniforms [[buffer(0)]]) {
    GlyphInstance glyph = instances[iid];
    uint local_vid = vid % 12;
    bool background = (local_vid < 6);
    float2 point;
    float2 pixel;
    float2 uv_out;

    if (background) {
        float2 quad[6] = {
            float2(0.0f, 0.0f),
            float2(1.0f, 0.0f),
            float2(0.0f, 1.0f),
            float2(1.0f, 0.0f),
            float2(1.0f, 1.0f),
            float2(0.0f, 1.0f),
        };

        point = quad[local_vid];
        pixel = glyph.position * uniforms.cell_size + point * uniforms.cell_size;
        uv_out = float2(0.0f);
    } else {
        uint text_vid = local_vid - 6;

        float2 quad[6] = {
            float2(0.0f, 0.0f),
            float2(1.0f, 0.0f),
            float2(0.0f, 1.0f),
            float2(1.0f, 0.0f),
            float2(1.0f, 1.0f),
            float2(0.0f, 1.0f),
        };

        point = quad[text_vid];
        pixel = glyph.position * uniforms.cell_size + glyph.bearing + point * glyph.size;
        uv_out = mix(glyph.uv.xy, glyph.uv.zw, point);
    }

    float2 ndc = (pixel / uniforms.viewport_size) * 2.0f - 1.0f;

    VertexOut out = {
        .position = float4(ndc, 0.0f, 1.0f),
        .uv = uv_out,
        .fg_color = glyph.fg_color,
        .bg_color = glyph.bg_color,
        .background = background,
    };

    return out;
}

fragment float4 terminal_fragment(VertexOut in [[stage_in]], texture2d<float> atlas [[texture(0)]], sampler s [[sampler(0)]]) {
    if (in.background) {
        return float4(in.bg_color.rgb * in.bg_color.a, in.bg_color.a);
    } else {
        float mask = atlas.sample(s, in.uv).r;
        float alpha = in.fg_color.a * mask;
        float3 rgb = in.fg_color.rgb * alpha;

        return float4(rgb, alpha);
    }
}
