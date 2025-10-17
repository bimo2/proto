//
//  screen.c
//  o1
//
//  Created by gpt-5-high on 2025-10-16.
//

#include "screen.h"
#include "ansi.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#define DEFAULT_ROWS 24
#define DEFAULT_COLUMNS 80

static const ansi_sgr_t DEFAULT_ATTRIBUTES = {
    .flags = ANSI_SGR_FLAG_NONE,
    .fg_color = ANSI_COLOR_RESET,
    .bg_color = ANSI_COLOR_RESET,
};

struct screen_t {
    screen_cell_t **grid;
    int32_t rows;
    int32_t columns;
    ansi_sgr_t attributes;
    bool auto_wrap;
    bool insert_mode;
    bool origin_mode;
    int32_t scroll_top;
    int32_t scroll_bottom;
    screen_cursor_t cursor;
    screen_cursor_t saved_cursor;
    bool saved_cursor_valid;
};

static inline void cell_reset(screen_cell_t *cell) {
    if (!cell) return;

    cell->codepoint = ' ';
    cell->attributes = DEFAULT_ATTRIBUTES;
    cell->dirty = false;
}

static inline void cursor_reset(screen_cursor_t *cursor) {
    if (!cursor) return;

    cursor->row = 0;
    cursor->column = 0;
    cursor->visible = true;
    cursor->blink = false;
    cursor->attributes = DEFAULT_ATTRIBUTES;
}

static screen_cell_t **init_grid(int32_t rows, int32_t columns) {
    screen_cell_t **grid = calloc(rows, sizeof(screen_cell_t *));

    if (!grid) return NULL;

    for (int32_t i = 0; i < rows; i++) {
        grid[i] = calloc(columns, sizeof(screen_cell_t));

        if (!grid[i]) {
            for (int32_t j = 0; j < i; j++) free(grid[j]);

            free(grid);

            return NULL;
        }

        for (int32_t j = 0; j < columns; j++) cell_reset(&grid[i][j]);
    }

    return grid;
}

static void free_grid(screen_cell_t **grid, int32_t rows) {
    if (!grid) return;

    for (int32_t i = 0; i < rows; i++) free(grid[i]);

    free(grid);
}

static inline bool valid_position(screen_t *screen, int32_t row, int32_t column) {
    return row >= 0 && row < screen->rows && column >= 0 && column < screen->columns;
}

static inline void fix_cursor(screen_t *screen) {
    if (screen->cursor.row < 0) screen->cursor.row = 0;
    if (screen->cursor.row >= screen->rows) screen->cursor.row = screen->rows - 1;
    if (screen->cursor.column < 0) screen->cursor.column = 0;
    if (screen->cursor.column >= screen->columns) screen->cursor.column = screen->columns - 1;
}

static inline void mark_dirty_range(screen_t *screen, int32_t start, int32_t end) {
    if (start < 0) start = 0;
    if (end >= screen->rows) end = screen->rows - 1;

    for (int32_t i = start; i <= end; i++) {
        for (int32_t j = 0; j < screen->columns; j++) screen->grid[i][j].dirty = true;
    }
}

screen_t *init_screen(int32_t rows, int32_t columns) {
    if (rows < 1) rows = DEFAULT_ROWS;
    if (columns < 1) columns = DEFAULT_COLUMNS;

    screen_t *screen = calloc(1, sizeof(screen_t));

    if (!screen) return NULL;

    screen->grid = init_grid(rows, columns);

    if (!screen->grid) {
        free(screen);

        return NULL;
    }

    screen->rows = rows;
    screen->columns = columns;
    screen->attributes = DEFAULT_ATTRIBUTES;
    screen->auto_wrap = true;
    screen->insert_mode = false;
    screen->origin_mode = false;
    screen->scroll_top = 0;
    screen->scroll_bottom = rows - 1;
    cursor_reset(&screen->cursor);
    cursor_reset(&screen->saved_cursor);
    screen->saved_cursor_valid = false;

    return screen;
}

void free_screen(screen_t *screen) {
    if (!screen) return;

    free_grid(screen->grid, screen->rows);
    free(screen);
}

int32_t screen_rows(screen_t *screen) {
    return screen->rows;
}

int32_t screen_columns(screen_t *screen) {
    return screen->columns;
}

void screen_set_grid(screen_t *screen, int32_t rows, int32_t columns) {
    if (rows < 1 || columns < 1) return;
    if (screen->rows == rows && screen->columns == columns) return;

    screen_cell_t **grid = init_grid(rows, columns);

    if (!grid) return;

    int32_t copy_rows = (screen->rows < rows) ? screen->rows : rows;
    int32_t copy_columns = (screen->columns < columns) ? screen->columns : columns;

    for (int32_t i = 0; i < copy_rows; i++) {
        for (int32_t j = 0; j < copy_columns; j++) grid[i][j] = screen->grid[i][j];
    }

    if (screen->scroll_bottom >= rows) screen->scroll_bottom = rows - 1;
    if (screen->cursor.row >= rows) screen->cursor.row = rows - 1;
    if (screen->cursor.column >= columns) screen->cursor.column = columns - 1;

    free_grid(screen->grid, screen->rows);
    screen->grid = grid;
    screen->rows = rows;
    screen->columns = columns;
    mark_dirty_range(screen, 0, rows - 1);
}

screen_cell_t *screen_cell(screen_t *screen, int32_t row, int32_t column) {
    if (!valid_position(screen, row, column)) return NULL;

    return &screen->grid[row][column];
}

void screen_set_cell(screen_t *screen, int32_t row, int32_t column, uint32_t codepoint, const ansi_sgr_t *attributes) {
    if (!valid_position(screen, row, column)) return;

    screen_cell_t *cell = &screen->grid[row][column];

    cell->codepoint = codepoint;

    if (attributes) {
        cell->attributes = *attributes;
    } else {
        cell->attributes = screen->attributes;
    }

    cell->dirty = true;
}

ansi_sgr_t *screen_attributes(screen_t *screen) {
    return &screen->attributes;
}

void screen_set_attributes(screen_t *screen, const ansi_sgr_t *attributes) {
    if (!attributes) {
        screen->attributes = DEFAULT_ATTRIBUTES;
    } else {
        screen->attributes = *attributes;
    }
}

bool screen_auto_wrap(screen_t *screen) {
    return screen->auto_wrap;
}

void screen_set_auto_wrap(screen_t *screen, bool enabled) {
    screen->auto_wrap = enabled;
}

bool screen_insert_mode(screen_t *screen) {
    return screen->insert_mode;
}

void screen_set_insert_mode(screen_t *screen, bool enabled) {
    screen->insert_mode = enabled;
}

bool screen_origin_mode(screen_t *screen) {
    return screen->origin_mode;
}

void screen_set_origin_mode(screen_t *screen, bool enabled) {
    screen->origin_mode = enabled;

    if (enabled) {
        screen->cursor.row = screen->scroll_top;
        screen->cursor.column = 0;
    } else {
        screen->cursor.row = 0;
        screen->cursor.column = 0;
    }

    fix_cursor(screen);
}

screen_cursor_t *screen_cursor(screen_t *screen) {
    return &screen->cursor;
}

void screen_set_cursor_position(screen_t *screen, int32_t row, int32_t column) {
    screen->cursor.row = row;
    screen->cursor.column = column;
    fix_cursor(screen);
}

void screen_move_cursor_absolute(screen_t *screen, int32_t row, int32_t column) {
    if (row > 0) row--;
    if (column > 0) column--;

    int32_t top = screen->origin_mode ? screen->scroll_top : 0;
    int32_t bottom = screen->origin_mode ? screen->scroll_bottom : screen->rows - 1;

    if (row < 0) row = 0;
    if (column < 0) column = 0;

    screen->cursor.row = top + row;
    screen->cursor.column = column;

    if (screen->cursor.row < top) screen->cursor.row = top;
    if (screen->cursor.row > bottom) screen->cursor.row = bottom;

    fix_cursor(screen);
}

void screen_move_cursor_relative(screen_t *screen, int32_t rows, int32_t columns) {
    screen->cursor.row += rows;
    screen->cursor.column += columns;
    fix_cursor(screen);
}

void screen_save_cursor(screen_t *screen) {
    screen->saved_cursor = screen->cursor;
    screen->saved_cursor_valid = true;
}

void screen_restore_cursor(screen_t *screen) {
    if (!screen->saved_cursor_valid) return;

    screen->cursor = screen->saved_cursor;
    fix_cursor(screen);
}

void screen_write_text(screen_t *screen, const uint8_t *text, size_t length) {
    if (!text || length == 0) return;

    for (size_t i = 0; i < length; i++) {
        uint32_t codepoint = text[i];

        if ((text[i] & 0x80) != 0) codepoint = text[i];

        screen_write_utf32(screen, codepoint);
    }
}

void screen_write_utf32(screen_t *screen, uint32_t codepoint) {
    switch (codepoint) {
        case '\n':
            screen_newline(screen);

            return;
        case '\r':
            screen_carriage_return(screen);

            return;
        case '\t':
            screen_tab(screen);

            return;
        case '\b':
            screen_backspace(screen);

            return;
        case 0x7F:
            screen_delete_utf32(screen);

            return;
    }

    if (screen->cursor.column >= screen->columns) {
        if (screen->auto_wrap) {
            screen_newline(screen);
            screen->cursor.column = 0;
        } else {
            screen->cursor.column = screen->columns - 1;
        }
    }

    if (screen->insert_mode) {
        for (int32_t j = screen->columns - 1; j > screen->cursor.column; j--) {
            screen->grid[screen->cursor.row][j] = screen->grid[screen->cursor.row][j - 1];
            screen->grid[screen->cursor.row][j].dirty = true;
        }

        screen_set_cell(screen, screen->cursor.row, screen->cursor.column, codepoint, &screen->attributes);
        screen->cursor.column++;
    } else {
        screen_set_cell(screen, screen->cursor.row, screen->cursor.column, codepoint, &screen->attributes);
        screen->cursor.column++;
    }

    if (screen->cursor.column >= screen->columns) {
        if (screen->auto_wrap) {
            screen->cursor.column = 0;
            screen->cursor.row++;

            if (screen->cursor.row > screen->scroll_bottom) {
                screen_scroll_up(screen, 1);
                screen->cursor.row = screen->scroll_bottom;
            }
        } else {
            screen->cursor.column = screen->columns - 1;
        }
    }
}

void screen_insert_utf32(screen_t *screen, uint32_t codepoint) {
    if (!valid_position(screen, screen->cursor.row, screen->cursor.column)) return;

    for (int32_t j = screen->columns - 1; j > screen->cursor.column; j--) {
        screen->grid[screen->cursor.row][j] = screen->grid[screen->cursor.row][j - 1];
        screen->grid[screen->cursor.row][j].dirty = true;
    }

    screen_set_cell(screen, screen->cursor.row, screen->cursor.column, codepoint, &screen->attributes);
    screen->cursor.column++;
    fix_cursor(screen);
}

void screen_delete_utf32(screen_t *screen) {
    if (!valid_position(screen, screen->cursor.row, screen->cursor.column)) return;

    for (int32_t j = screen->cursor.column; j < screen->columns - 1; j++) {
        screen->grid[screen->cursor.row][j] = screen->grid[screen->cursor.row][j + 1];
        screen->grid[screen->cursor.row][j].dirty = true;
    }

    cell_reset(&screen->grid[screen->cursor.row][screen->columns - 1]);
    screen->grid[screen->cursor.row][screen->columns - 1].dirty = true;
}

void screen_backspace(screen_t *screen) {
    if (screen->cursor.column > 0) {
        screen->cursor.column--;
        screen_delete_utf32(screen);
    } else if (screen->cursor.row > 0) {
        screen->cursor.row--;
        screen->cursor.column = screen->columns - 1;
        screen_delete_utf32(screen);
    }
}

void screen_newline(screen_t *screen) {
    screen->cursor.column = 0;
    screen->cursor.row++;

    if (screen->cursor.row > screen->scroll_bottom) {
        screen_scroll_up(screen, 1);
        screen->cursor.row = screen->scroll_bottom;
    }
}

void screen_carriage_return(screen_t *screen) {
    screen->cursor.column = 0;
}

void screen_tab(screen_t *screen) {
    int32_t stop = ((screen->cursor.column / 8) + 1) * 8;

    screen->cursor.column = (stop < screen->columns) ? stop : screen->columns - 1;
}

void screen_clear(screen_t *screen) {
    for (int32_t i = 0; i < screen->rows; i++) {
        for (int32_t j = 0; j < screen->columns; j++) cell_reset(&screen->grid[i][j]);
    }

    mark_dirty_range(screen, 0, screen->rows - 1);
}

void screen_erase(screen_t *screen, int32_t mode) {
    switch (mode) {
        case 0:
            for (int32_t j = screen->cursor.column; j < screen->columns; j++) {
                cell_reset(&screen->grid[screen->cursor.row][j]);
                screen->grid[screen->cursor.row][j].dirty = true;
            }

            for (int32_t i = screen->cursor.row + 1; i < screen->rows; i++) {
                for (int32_t j = 0; j < screen->columns; j++) {
                    cell_reset(&screen->grid[i][j]);
                    screen->grid[i][j].dirty = true;
                }
            }

            break;
        case 1:
            for (int32_t i = 0; i < screen->cursor.row; i++) {
                for (int32_t j = 0; j < screen->columns; j++) {
                    cell_reset(&screen->grid[i][j]);
                    screen->grid[i][j].dirty = true;
                }
            }

            for (int32_t j = 0; j <= screen->cursor.column; j++) {
                cell_reset(&screen->grid[screen->cursor.row][j]);
                screen->grid[screen->cursor.row][j].dirty = true;
            }

            break;
        case 2:
            screen_clear(screen);

            break;
    }
}

void screen_erase_line(screen_t *screen, int32_t mode) {
    if (!valid_position(screen, screen->cursor.row, 0)) return;

    switch (mode) {
        case 0:
            for (int32_t j = screen->cursor.column; j < screen->columns; j++)
                cell_reset(&screen->grid[screen->cursor.row][j]);

            break;
        case 1:
            for (int32_t j = 0; j <= screen->cursor.column; j++)
                cell_reset(&screen->grid[screen->cursor.row][j]);

            break;
        case 2:
            for (int32_t j = 0; j < screen->columns; j++)
                cell_reset(&screen->grid[screen->cursor.row][j]);

            break;
    }

    screen->grid[screen->cursor.row][0].dirty = true;
}

void screen_set_scroll_area(screen_t *screen, int32_t top, int32_t bottom) {
    if (top > 0) top--;
    if (bottom > 0) bottom--;
    if (top < 0) top = 0;
    if (bottom >= screen->rows) bottom = screen->rows - 1;
    if (top > bottom) top = bottom;

    screen->scroll_top = top;
    screen->scroll_bottom = bottom;
}

void screen_scroll_up(screen_t *screen, int32_t lines) {
    if (lines < 1) return;

    for (int32_t i = screen->scroll_top; i <= screen->scroll_bottom - lines; i++) {
        for (int32_t j = 0; j < screen->columns; j++) {
            screen->grid[i][j] = screen->grid[i + lines][j];
            screen->grid[i][j].dirty = true;
        }
    }

    for (int32_t i = screen->scroll_bottom - lines + 1; i <= screen->scroll_bottom; i++) {
        for (int32_t j = 0; j < screen->columns; j++) {
            cell_reset(&screen->grid[i][j]);
            screen->grid[i][j].dirty = true;
        }
    }
}

void screen_scroll_down(screen_t *screen, int32_t lines) {
    if (lines < 1) return;

    for (int32_t i = screen->scroll_bottom; i >= screen->scroll_top + lines; i--) {
        for (int32_t j = 0; j < screen->columns; j++) {
            screen->grid[i][j] = screen->grid[i - lines][j];
            screen->grid[i][j].dirty = true;
        }
    }

    for (int32_t i = screen->scroll_top; i < screen->scroll_top + lines; i++) {
        for (int32_t j = 0; j < screen->columns; j++) {
            cell_reset(&screen->grid[i][j]);
            screen->grid[i][j].dirty = true;
        }
    }
}

void screen_insert_line(screen_t *screen, int32_t count) {
    if (count < 1) return;

    screen_scroll_down(screen, count);
    screen->cursor.column = 0;
}

void screen_delete_line(screen_t *screen, int32_t count) {
    if (count < 1) return;

    screen_scroll_up(screen, count);
}

void screen_insert_column(screen_t *screen, int32_t count) {
    if (count < 1) return;

    for (int32_t i = screen->scroll_top; i <= screen->scroll_bottom; i++) {
        for (int32_t j = screen->columns - 1; j >= screen->cursor.column + count; j--) {
            screen->grid[i][j] = screen->grid[i][j - count];
            screen->grid[i][j].dirty = true;
        }

        for (int32_t j = screen->cursor.column; j < screen->cursor.column + count; j++) {
            cell_reset(&screen->grid[i][j]);
            screen->grid[i][j].dirty = true;
        }
    }
}

void screen_delete_column(screen_t *screen, int32_t count) {
    if (count < 1) return;

    for (int32_t i = screen->scroll_top; i <= screen->scroll_bottom; i++) {
        for (int32_t j = screen->cursor.column; j < screen->columns - count; j++) {
            screen->grid[i][j] = screen->grid[i][j + count];
            screen->grid[i][j].dirty = true;
        }

        for (int32_t j = screen->columns - count; j < screen->columns; j++) {
            cell_reset(&screen->grid[i][j]);
            screen->grid[i][j].dirty = true;
        }
    }
}
