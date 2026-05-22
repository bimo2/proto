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

#define hex(value) \
    (simd_float3){(((value) >> 16) & 0xFFu) / 255.0f, (((value) >> 8) & 0xFFu) / 255.0f, ((value) & 0xFFu) / 255.0f}

bool cpu_default_monochrome = false;
double cpu_default_cursor_fps = 60.0;
double cpu_default_cursor_interval = 1.0;
char cpu_default_font[CPU_FONT_NAME_LENGTH] = "";
float cpu_default_font_size = 12.0f;

simd_float3 cpu_default_colors[] = {
    hex(0x262626u),
    hex(0xFF2146u),
    hex(0x1CD673u),
    hex(0xE6F520u),
    hex(0x2194FFu),
    hex(0xB45EFFu),
    hex(0x34DBEDu),
    hex(0xD1D1D1u),
    hex(0x5C5C5Cu),
    hex(0xFF5974u),
    hex(0x55E096u),
    hex(0xECF858u),
    hex(0x59AFFFu),
    hex(0xC786FFu),
    hex(0x67E4F2u),
    hex(0xDDDDDDu),
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
