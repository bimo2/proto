//
//  shaders_cpu.c
//  o1
//
//  Created by claude-4.5-opus-high-thinking on 2025-12-21.
//

#include "shaders_cpu.h"

#include "ansi.h"

#define rgb(red, green, blue) \
    (simd_float3){(red) / 255.0f, (green) / 255.0f, (blue) / 255.0f}

bool cpu_default_monochrome = false;
double cpu_default_cursor_fps = 60.0;
double cpu_default_cursor_interval = 1.0;
char cpu_default_font[CPU_FONT_NAME_LENGTH] = "";
float cpu_default_font_size = 12.0f;

simd_float3 cpu_default_colors[] = {
    rgb(0, 0, 0),
    rgb(255, 28, 62),
    rgb(29, 219, 108),
    rgb(245, 255, 46),
    rgb(46, 147, 255),
    rgb(255, 46, 248),
    rgb(46, 241, 255),
    rgb(168, 168, 168),
    rgb(87, 87, 87),
    rgb(255, 128, 147),
    rgb(115, 237, 166),
    rgb(250, 255, 148),
    rgb(148, 200, 255),
    rgb(255, 148, 251),
    rgb(148, 248, 255),
    rgb(255, 255, 255),
};

static simd_float3 indexed_color(int index) {
    if (index < CPU_USER_COLOR_LENGTH) return cpu_default_colors[index];

    if (index < 232) {
        static const uint8_t levels[6] = {0, 95, 135, 175, 215, 255};
        int base = index - 16;
        int red = base / 36;
        int green = (base % 36) / 6;
        int blue = base % 6;

        return rgb(levels[red], levels[green], levels[blue]);
    }

    uint8_t value = 8 + (index - 232) * 10;

    return rgb(value, value, value);
}

static simd_float4 reset_color(bool background) {
    simd_float3 fg_color = rgb(255, 255, 255);
    simd_float3 bg_color = rgb(0, 0, 0);

    return background ? simd_make_float4(bg_color, 0.0f) : simd_make_float4(fg_color, 1.0f);
}

simd_float4 cpu_rgba_color(uint32_t color, bool background) {
    int index = 0;
    uint8_t red = 0;
    uint8_t green = 0;
    uint8_t blue = 0;
    ansi_color_t kind = ansi_color_unpack(color, &index, &red, &green, &blue);

    switch (kind) {
        case ANSI_COLOR_INDEXED:
            if (index < 256) return simd_make_float4(indexed_color(index), 1.0f);

            return reset_color(background);
        case ANSI_COLOR_RGB:
            return simd_make_float4(rgb(red, green, blue), 1.0f);
        case ANSI_COLOR_DEFAULT:
            return reset_color(background);
    }
}
