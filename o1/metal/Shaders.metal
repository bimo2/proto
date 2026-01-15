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
    uint font_index;
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

struct CursorUniforms {
    uint2 cell;
    uint visible;
    uint style;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    uint font_index;
    float4 fg_color;
    float4 bg_color;
    bool background;
    uint2 cell;
    float2 local;
};

vertex VertexOut terminal_vertex(uint vid [[vertex_id]], uint iid [[instance_id]], constant GlyphInstance* instances [[buffer(0)]], constant GridUniforms& grid_uniforms [[buffer(1)]], constant CursorUniforms& cursor_uniforms [[buffer(2)]]) {
    GlyphInstance glyph = instances[iid];
    uint local_vid = vid % 12;
    bool background = (local_vid < 6);
    float2 point;
    float2 pixel;
    float2 uv_out;
    float2 local = float2(0.0f);
    uint2 cell = uint2(uint(glyph.position.x), uint(glyph.position.y));
    bool cursor = cursor_uniforms.visible != 0 && all(cell == cursor_uniforms.cell);

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
        local = point;

        if (cursor && cursor_uniforms.style == 0) {
            constexpr float padding = 0.02f;

            point.x = point.x * (1.0f + 2.0f * padding) - padding;
        }

        pixel = glyph.position * grid_uniforms.cell_size + point * grid_uniforms.cell_size;
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
        pixel = glyph.position * grid_uniforms.cell_size + glyph.bearing + point * glyph.size;
        uv_out = mix(glyph.uv.xy, glyph.uv.zw, point);
    }

    float2 ndc = (pixel / grid_uniforms.viewport_size) * 2.0f - 1.0f;

    VertexOut out = {
        .position = float4(ndc, 0.0f, 1.0f),
        .uv = uv_out,
        .font_index = glyph.font_index,
        .fg_color = glyph.fg_color,
        .bg_color = glyph.bg_color,
        .background = background,
        .cell = cell,
        .local = local,
    };

    return out;
}

fragment float4 terminal_fragment(VertexOut in [[stage_in]], texture2d_array<float> atlas [[texture(0)]], sampler s [[sampler(0)]], constant GridUniforms& grid_uniforms [[buffer(0)]], constant CursorUniforms& cursor_uniforms [[buffer(1)]]) {
    bool cursor = cursor_uniforms.visible != 0 && all(in.cell == cursor_uniforms.cell);

    if (cursor && cursor_uniforms.style == 1 && in.background) {
        constexpr float width = 2.0f;
        float2 local = in.local * grid_uniforms.cell_size;

        bool border = (local.x < width) || (local.x > grid_uniforms.cell_size.x - width) || (local.y < width) || (local.y > grid_uniforms.cell_size.y - width);

        if (border) {
            float4 outline = float4(in.fg_color.rgb, 1.0f);

            return float4(outline.rgb * outline.a, outline.a);
        }
    }

    if (cursor && cursor_uniforms.style == 0) {
        float4 cursor_bg = float4(in.fg_color.rgb, 1.0f);
        float4 cursor_fg = in.bg_color;

        if (cursor_fg.a < 0.5f) {
            cursor_fg = float4(0.0f, 0.0f, 0.0f, 1.0f);
        } else {
            cursor_fg.a = 1.0f;
        }

        if (in.background) {
            return float4(cursor_bg.rgb * cursor_bg.a, cursor_bg.a);
        } else {
            float mask = atlas.sample(s, in.uv, in.font_index).r;
            float alpha = cursor_fg.a * mask;
            float3 rgb = cursor_fg.rgb * alpha;

            return float4(rgb, alpha);
        }
    }

    if (in.background) return float4(in.bg_color.rgb * in.bg_color.a, in.bg_color.a);

    float mask = atlas.sample(s, in.uv, in.font_index).r;
    float alpha = in.fg_color.a * mask;
    float3 rgb = in.fg_color.rgb * alpha;

    return float4(rgb, alpha);
}
