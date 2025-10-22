//
//  render.h
//  o1
//
//  Created by gpt-5-high on 2025-10-22.
//

#ifndef RENDER_H
#define RENDER_H

#include "screen.h"

#include <stddef.h>
#include <stdint.h>

typedef enum render_op_t {
    RENDER_OP_SPAN = 1,
    RENDER_OP_SCROLL,
} render_op_t;

typedef struct render_op_span_t {
    int32_t row;
    int32_t column;
    const screen_cell_t *cells;
    size_t width;
} render_op_span_t;

typedef struct render_op_scroll_t {
    int32_t top;
    int32_t bottom;
    int32_t delta;
} render_op_scroll_t;

typedef struct render_t {
    render_op_t op;
    union {
        render_op_span_t span;
        render_op_scroll_t scroll;
    };
} render_t;

void render_collect_ops(screen_t *screen, render_t **ops, size_t *count);

void render_clear_ops(render_t *ops, size_t count);

#endif // !RENDER_H
