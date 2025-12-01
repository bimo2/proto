//
//  shaders_cpu.h
//  o1
//
//  Created by claude-4.5-opus-high-thinking on 2025-12-01.
//

#ifndef SHADERS_CPU_H
#define SHADERS_CPU_H

#include <simd/simd.h>

#define CPU_DOT_VERTEX_SHADER "dotVertexShader"
#define CPU_DOT_FRAGMENT_SHADER "dotFragmentShader"

typedef struct cpu_grid_uniforms_t {
    simd_float2 viewport_size;
    simd_float2 cell_size;
    simd_uint2 grid_size;
    float dot_size;
} cpu_grid_uniforms_t;

#endif // !SHADERS_CPU_H
