//
//  shaders_cpu.h
//  o1
//
//  Created by claude-4.5-opus-high-thinking on 2025-12-01.
//

#ifndef SHADERS_CPU_H
#define SHADERS_CPU_H

#include <simd/simd.h>
#include <stdbool.h>
#include <stdint.h>

#define CPU_TERMINAL_VERTEX_COUNT 12
#define CPU_TERMINAL_VERTEX_SHADER "terminal_vertex"
#define CPU_TERMINAL_FRAGMENT_SHADER "terminal_fragment"
#define CPU_USER_COLOR_LENGTH 16

typedef enum cpu_user_color_t {
    CPU_USER_COLOR_BLACK = 0,
    CPU_USER_COLOR_RED,
    CPU_USER_COLOR_GREEN,
    CPU_USER_COLOR_YELLOW,
    CPU_USER_COLOR_BLUE,
    CPU_USER_COLOR_MAGENTA,
    CPU_USER_COLOR_CYAN,
    CPU_USER_COLOR_WHITE,
    CPU_USER_COLOR_BRIGHT_BLACK,
    CPU_USER_COLOR_BRIGHT_RED,
    CPU_USER_COLOR_BRIGHT_GREEN,
    CPU_USER_COLOR_BRIGHT_YELLOW,
    CPU_USER_COLOR_BRIGHT_BLUE,
    CPU_USER_COLOR_BRIGHT_MAGENTA,
    CPU_USER_COLOR_BRIGHT_CYAN,
    CPU_USER_COLOR_BRIGHT_WHITE,
} cpu_user_color_t;

typedef enum cpu_font_index_t {
    CPU_FONT_INDEX_REGULAR = 0,
    CPU_FONT_INDEX_BOLD,
} cpu_font_index_t;

typedef enum cpu_cursor_style_t {
    CPU_CURSOR_STYLE_BLOCK = 0,
    CPU_CURSOR_STYLE_BLOCK_OUTLINE,
} cpu_cursor_style_t;

typedef struct cpu_glyph_instance_t {
    uint32_t glyph_id;
    uint32_t font_index;
    simd_float2 position;
    simd_float4 uv;
    simd_float2 size;
    simd_float2 bearing;
    simd_float4 fg_color;
    simd_float4 bg_color;
} cpu_glyph_instance_t;

typedef struct cpu_grid_uniforms_t {
    simd_float2 viewport_size;
    simd_float2 cell_size;
    bool monochrome;
} cpu_grid_uniforms_t;

typedef struct cpu_cursor_uniforms_t {
    simd_uint2 cell;
    uint32_t visible;
    cpu_cursor_style_t style;
    float alpha;
} cpu_cursor_uniforms_t;

extern bool cpu_default_monochrome;
extern double cpu_default_cursor_fps;
extern double cpu_default_cursor_interval;
extern simd_float3 cpu_default_colors[CPU_USER_COLOR_LENGTH];

simd_float4 cpu_rgba_color(uint32_t color, bool background);

#endif // !SHADERS_CPU_H
