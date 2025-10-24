//
//  render.c
//  o1
//
//  Created by gpt-5-high on 2025-10-22.
//

#include "render.h"

#include "screen.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static void add_render_op(render_t **ops, size_t *count, size_t *capacity, const render_t *diff) {
    if (*count == *capacity) {
        size_t next = *capacity < 1 ? 128 : *capacity * 2;
        render_t *id = (render_t *)realloc(*ops, next * sizeof(render_t));

        if (!id) return;

        *ops = id;
        *capacity = next;
    }

    (*ops)[(*count)++] = *diff;
}

static inline const screen_cell_t *retain_cells(const screen_cell_t *cells, size_t count) {
    if (count < 1) return cells;

    screen_cell_t *copy = (screen_cell_t *)malloc(count * sizeof(screen_cell_t));

    if (!copy) return NULL;

    memcpy(copy, cells, count * sizeof(screen_cell_t));

    return copy;
}

void render_collect_ops(render_t **ops, screen_t *screen, size_t *count) {
    if (!screen || !count) return;

    *ops = NULL;
    *count = 0;

    size_t capacity = 0;
    int32_t rows = screen_rows(screen);
    int32_t columns = screen_columns(screen);
    int32_t delta = screen_stage_viewport_scroll(screen);

    if (delta != 0) {
        render_op_scroll_t scroll = {
            .top = 0,
            .bottom = rows - 1,
            .delta = delta,
        };

        render_t diff = {
            .op = RENDER_OP_SCROLL,
            .scroll = scroll,
        };

        add_render_op(ops, count, &capacity, &diff);
    }

    for (int32_t i = 0; i < rows; i++) {
        bool mutable = false;
        screen_cell_t *cells = screen_viewport_row(screen, i, &mutable);

        if (!cells) continue;

        int32_t start = -1;
        render_t last = { .op = 0 };

        for (int32_t j = 0; j < columns; j++) {
            bool dirty = mutable ? cells[j].dirty : false;

            if (dirty) {
                if (start < 0) start = j;
            } else if (start > -1) {
                int32_t width = j - start;
                const screen_cell_t *span_cells = retain_cells(cells + start, width);

                render_op_span_t span = {
                    .row = i,
                    .column = start,
                    .cells = span_cells,
                    .width = width,
                };

                render_t diff = {
                    .op = RENDER_OP_SPAN,
                    .span = span,
                };

                if (last.op == RENDER_OP_SPAN && last.span.row == i && diff.span.column <= last.span.column + last.span.width + 1) {
                    size_t merge_width = (size_t)diff.span.column + diff.span.width - (size_t)last.span.column;

                    last.span.width = merge_width;
                    free((void *)last.span.cells);
                    last.span.cells = retain_cells(cells + last.span.column, merge_width);
                    (*ops)[*count - 1] = last;
                } else {
                    add_render_op(ops, count, &capacity, &diff);
                    last = diff;
                }

                start = -1;
            }
        }

        if (start > -1) {
            size_t width = (size_t)columns - (size_t)start;
            const screen_cell_t *span_cells = retain_cells(cells + start, width);

            render_op_span_t span = {
                .row = i,
                .column = start,
                .cells = span_cells,
                .width = width,
            };

            render_t diff = {
                .op = RENDER_OP_SPAN,
                .span = span,
            };

            add_render_op(ops, count, &capacity, &diff);
        }

        if (mutable) {
            for (int32_t j = 0; j < columns; j++) cells[j].dirty = false;
        }
    }
}

void render_clear_ops(render_t *ops, size_t count) {
    for (size_t i = 0; i < count; i++) {
        if (ops[i].op == RENDER_OP_SPAN && ops[i].span.cells) free((void *)ops[i].span.cells);
    }

    free(ops);
}
