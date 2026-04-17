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
    bool monochrome;
};

struct CursorUniforms {
    uint2 cell;
    uint visible;
    uint style;
    float alpha;
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

constant float kCursorMaxAlpha = 0.85f;
constant float kCursorRadius = 4.5f;
constant float kCursorInset = 0.75f;
constant float kCursorPadding = 0.04f;

static float cursor_block_shape_alpha(float2 local, float2 cell_size, float padding, float inset) {
    float2 size = float2((1.0f + 2.0f * padding) * cell_size.x, cell_size.y);
    float2 point = float2((local.x + padding) * cell_size.x, local.y * cell_size.y);
    float radius = min(kCursorRadius, 0.5f * min(size.x, size.y));
    float max_inset = max(0.0f, min(0.5f * min(size.x, size.y) - 1e-3f, radius - 1e-3f));
    float local_inset = min(inset, max_inset);

    size = max(size - 2.0f * local_inset, float2(1e-3f));
    point -= local_inset;

    float local_radius = min(max(0.0f, radius - local_inset), 0.5f * min(size.x, size.y));
    float2 pixel = abs(point - size * 0.5f) - (size * 0.5f - local_radius);
    float distance = length(max(pixel, float2(0.0f))) + min(max(pixel.x, pixel.y), 0.0f) - local_radius;
    float aa = max(fwidth(distance), 1e-4f);

    return clamp(1.0f - smoothstep(0.0f, aa, distance), 0.0f, 1.0f);
}

vertex VertexOut terminal_vertex(uint vid [[vertex_id]], uint iid [[instance_id]], constant GlyphInstance* instances [[buffer(0)]], constant GridUniforms& grid_uniforms [[buffer(1)]], constant CursorUniforms& cursor_uniforms [[buffer(2)]]) {
    GlyphInstance glyph = instances[iid];
    uint local_vid = vid % 12;
    bool background = (local_vid < 6);
    float2 point;
    float2 pixel;
    float2 uv;
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

        if (cursor && (cursor_uniforms.style == 0 || cursor_uniforms.style == 1)) point.x = point.x * (1.0f + 2.0f * kCursorPadding) - kCursorPadding;

        local = point;
        pixel = glyph.position * grid_uniforms.cell_size + point * grid_uniforms.cell_size;
        uv = float2(0.0f);
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
        uv = mix(glyph.uv.xy, glyph.uv.zw, point);
    }

    float2 ndc = (pixel / grid_uniforms.viewport_size) * 2.0f - 1.0f;

    VertexOut out = {
        .position = float4(ndc, 0.0f, 1.0f),
        .uv = uv,
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
    float4 fg_color = in.fg_color;
    float4 bg_color = in.bg_color;

    if (grid_uniforms.monochrome) {
        constexpr float3 luminance = float3(0.2126f, 0.7152f, 0.0722f);
        float fg = dot(fg_color.rgb, luminance);
        float bg = dot(bg_color.rgb, luminance);

        fg_color.rgb = float3(fg);
        bg_color.rgb = float3(bg);
    }

    if (cursor && cursor_uniforms.style == 1 && in.background) {
        constexpr float width = 2.0f;
        float outer_alpha = cursor_block_shape_alpha(in.local, grid_uniforms.cell_size, kCursorPadding, kCursorInset);
        float inner_alpha = cursor_block_shape_alpha(in.local, grid_uniforms.cell_size, kCursorPadding, kCursorInset + width);
        float border_alpha = clamp(outer_alpha - inner_alpha, 0.0f, 1.0f);

        if (border_alpha > 0.0f) {
            float4 outline = float4(fg_color.rgb, 1.0f);
            float alpha = outline.a * border_alpha;

            return float4(outline.rgb * alpha, alpha);
        }

        bool inside = in.local.x >= 0.0f && in.local.x <= 1.0f;

        if (!inside) return float4(0.0f);
    }

    if (cursor && cursor_uniforms.style == 0) {
        float4 cursor_bg = float4(fg_color.rgb, 1.0f);
        float4 cursor_fg = bg_color;
        float blink = clamp(cursor_uniforms.alpha, 0.0f, 1.0f);

        if (cursor_fg.a < 0.5f) {
            cursor_fg = float4(0.0f, 0.0f, 0.0f, 1.0f);
        } else {
            cursor_fg.a = 1.0f;
        }

        if (in.background) {
            float shape_alpha = cursor_block_shape_alpha(in.local, grid_uniforms.cell_size, kCursorPadding, kCursorInset);
            float blend = blink * shape_alpha;
            float cursor_alpha = kCursorMaxAlpha;
            float3 base_rgb = bg_color.rgb * bg_color.a;
            float3 cursor_rgb = cursor_bg.rgb * cursor_alpha;
            float3 rgb = mix(base_rgb, cursor_rgb, blend);
            float alpha = mix(bg_color.a, cursor_alpha, blend);

            return float4(rgb, alpha);
        } else {
            float mask = atlas.sample(s, in.uv, in.font_index).r;
            float base_alpha = fg_color.a * mask;
            float cursor_alpha = cursor_fg.a * mask;
            float3 base_rgb = fg_color.rgb * base_alpha;
            float3 cursor_rgb = cursor_fg.rgb * cursor_alpha;
            float3 rgb = mix(base_rgb, cursor_rgb, blink);
            float alpha = mix(base_alpha, cursor_alpha, blink);

            return float4(rgb, alpha);
        }
    }

    if (in.background) return float4(bg_color.rgb * bg_color.a, bg_color.a);

    float mask = atlas.sample(s, in.uv, in.font_index).r;
    float alpha = fg_color.a * mask;
    float3 rgb = fg_color.rgb * alpha;

    return float4(rgb, alpha);
}
