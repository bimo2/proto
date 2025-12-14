//
//  shaders_cpu.h
//  o1
//
//  Created by claude-4.5-opus-high-thinking on 2025-12-01.
//

#ifndef SHADERS_CPU_H
#define SHADERS_CPU_H

#include <simd/simd.h>

#define CPU_TERMINAL_VERTEX_SHADER "terminal_vertex"
#define CPU_TERMINAL_FRAGMENT_SHADER "terminal_fragment"

typedef struct cpu_glyph_instance_t {
    uint32_t glyph_id;
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
} cpu_grid_uniforms_t;

#endif // !SHADERS_CPU_H
