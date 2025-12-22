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

simd_float3 cpu_default_colors[] = {
    rgb(0, 0, 0),
    rgb(255, 28, 62),
    rgb(46, 217, 117),
    rgb(245, 255, 46),
    rgb(46, 147, 255),
    rgb(255, 46, 248),
    rgb(46, 241, 255),
    rgb(168, 168, 168),
    rgb(87, 87, 87),
    rgb(255, 128, 147),
    rgb(134, 233, 175),
    rgb(250, 255, 148),
    rgb(148, 200, 255),
    rgb(255, 148, 251),
    rgb(148, 248, 255),
    rgb(255, 255, 255),
};

static simd_float4 reset_color(bool background) {
    return background ? simd_make_float4(cpu_default_colors[CPU_USER_COLOR_BLACK], 0.0f) : simd_make_float4(cpu_default_colors[CPU_USER_COLOR_BRIGHT_WHITE], 1.0f);
}

simd_float4 cpu_rgba_color(uint32_t color, bool background) {
    int index = 0;
    uint8_t red = 0;
    uint8_t green = 0;
    uint8_t blue = 0;
    ansi_color_t kind = ansi_color_unpack(color, &index, &red, &green, &blue);

    switch (kind) {
        case ANSI_COLOR_INDEXED:
            if (index < CPU_USER_COLOR_LENGTH) return simd_make_float4(cpu_default_colors[index], 1.0f);

            return reset_color(background);
        case ANSI_COLOR_RGB:
            return simd_make_float4(rgb(red, green, blue), 1.0f);
        case ANSI_COLOR_DEFAULT:
            return reset_color(background);
    }
}
