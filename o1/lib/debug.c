//
//  debug.c
//  o1
//
//  Created by grok-code-fast-1 on 2026-01-21.
//

#include "debug.h"

#include "include.h"
#include "render.h"
#include "screen.h"

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

void debug_print_ops(render_t *ops, size_t count) {
    for (size_t i = 0; i < count; i++) {
        const render_t *diff = &ops[i];

        switch (diff->op) {
            case RENDER_OP_SPAN: {
                size_t width = diff->span.width;
                char *text = (char *)malloc(width + 1);

                if (!text) {
                    log_error("malloc failed: %zu", width + 1);

                    return;
                }

                for (size_t j = 0; j < width; j++) {
                    uint32_t codepoint = diff->span.cells[j].codepoint;

                    if (codepoint == 0) codepoint = ' ';

                    if (codepoint <= 0xFFu) {
                        text[j] = (char)codepoint;
                    } else {
                        text[j] = '?';
                    }
                }

                text[width] = '\0';
                printf("[span] %d %d \"%s\" (%zu)\n", diff->span.row, diff->span.column, text, diff->span.width);
                free(text);

                break;
            }
            case RENDER_OP_SCROLL: {
                char sign = diff->scroll.delta < 0 ? '-' : '+';

                printf("[scroll] %d %d %c%d\n", diff->scroll.top, diff->scroll.bottom, sign, diff->scroll.delta);

                break;
            }
        }
    }
}

void debug_print_screen(screen_t *screen) {
    int32_t rows = screen_rows(screen);
    int32_t columns = screen_columns(screen);
    size_t size = (size_t)rows * ((size_t)columns * 4 + 1) + 1;
    char *buffer = (char *)malloc(size);

    if (!buffer) {
        log_error("malloc failed: %zu", size);

        return;
    }

    screen_cursor_t *cursor = screen_cursor(screen);
    size_t offset = 0;

    for (int32_t i = 0; i < rows; i++) {
        for (int32_t j = 0; j < columns; j++) {
            if (cursor->row == i && cursor->column == j) {
                if (offset + 1 < size) buffer[offset++] = '|';

                continue;
            }

            screen_cell_t *cell = screen_cell(screen, i, j);

            if (!cell) {
                if (offset + 1 < size) buffer[offset++] = '?';

                continue;
            }

            uint32_t codepoint = cell->codepoint;

            if (codepoint == 0) codepoint = ' ';

            if (offset + 4 < size) {
                if (codepoint <= 0x7Fu) {
                    buffer[offset++] = (char)codepoint;
                } else if (codepoint <= 0x7FFu) {
                    buffer[offset++] = 0xC0u | ((codepoint >> 6) & 0x1Fu);
                    buffer[offset++] = 0x80u | (codepoint & 0x3Fu);
                } else if (codepoint <= 0xFFFFu) {
                    buffer[offset++] = 0xE0u | ((codepoint >> 12) & 0x0Fu);
                    buffer[offset++] = 0x80u | ((codepoint >> 6) & 0x3Fu);
                    buffer[offset++] = 0x80u | (codepoint & 0x3Fu);
                } else {
                    buffer[offset++] = 0xF0u | ((codepoint >> 18) & 0x07u);
                    buffer[offset++] = 0x80u | ((codepoint >> 12) & 0x3Fu);
                    buffer[offset++] = 0x80u | ((codepoint >> 6) & 0x3Fu);
                    buffer[offset++] = 0x80u | (codepoint & 0x3Fu);
                }
            }
        }

        if (offset + 1 < size && i < rows - 1) buffer[offset++] = '\n';
    }

    buffer[offset] = '\0';
    printf("%s\n", buffer);
    free(buffer);
}
