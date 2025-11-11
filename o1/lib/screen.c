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
#include <string.h>

static const ansi_sgr_t default_attributes = {
    .flags = ANSI_SGR_FLAG_NONE,
    .fg_color = ANSI_COLOR_RESET,
    .bg_color = ANSI_COLOR_RESET,
};

uint32_t screen_default_rows = 24;
uint32_t screen_default_columns = 80;
uint32_t screen_default_width = 0;
uint32_t screen_default_height = 0;

typedef struct {
    screen_cell_t *cells;
    size_t width;
    bool soft_wrap;
} line_t;

typedef struct {
    size_t capacity;
    screen_cell_t *cells;
    size_t width;
} staging_line_t;

typedef struct {
    size_t capacity;
    line_t *lines;
    size_t size;
    size_t head;
} scrollback_t;

typedef struct {
    size_t capacity;
    char **table;
    size_t size;
} link_table_t;

struct screen_t {
    screen_cell_t **grid;
    int32_t rows;
    int32_t columns;
    bool *soft_wrap;
    bool *tab_stops;
    ansi_sgr_t attributes;
    uint32_t link_id;
    link_table_t links;
    bool auto_wrap;
    bool insert_mode;
    bool origin_mode;
    int32_t scroll_top;
    int32_t scroll_bottom;
    screen_cursor_t cursor;
    screen_cursor_t saved_cursor;
    bool saved_cursor_valid;
    scrollback_t scrollback;
    int32_t viewport_offset;
    int32_t viewport_delta;
};

static inline size_t min(size_t a, size_t b) {
    return a < b ? a : b;
}

static inline void reset_cell(screen_cell_t *cell) {
    if (!cell) return;

    cell->codepoint = ' ';
    cell->attributes = default_attributes;
    cell->link_id = 0;
    cell->dirty = false;
}

static inline void reset_cursor(screen_cursor_t *cursor) {
    if (!cursor) return;

    cursor->row = 0;
    cursor->column = 0;
    cursor->visible = true;
    cursor->blink = false;
    cursor->attributes = default_attributes;
}

static screen_cell_t **init_grid(int32_t rows, int32_t columns) {
    screen_cell_t **grid = (screen_cell_t **)calloc(rows, sizeof(screen_cell_t *));

    if (!grid) return NULL;

    for (int32_t i = 0; i < rows; i++) {
        grid[i] = (screen_cell_t *)calloc(columns, sizeof(screen_cell_t));

        if (!grid[i]) {
            for (int32_t j = 0; j < i; j++) free(grid[j]);

            free(grid);

            return NULL;
        }

        for (int32_t j = 0; j < columns; j++) reset_cell(&grid[i][j]);
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

static inline void needs_layout(screen_t *screen, int32_t start, int32_t end) {
    if (start < 0) start = 0;
    if (end >= screen->rows) end = screen->rows - 1;

    for (int32_t i = start; i <= end; i++) {
        for (int32_t j = 0; j < screen->columns; j++) screen->grid[i][j].dirty = true;
    }
}

static void add_staging_cells(staging_line_t *line, const screen_cell_t *cells, size_t count) {
    if (!cells || count < 1) return;

    size_t need = line->width + count;

    if (need > line->capacity) {
        size_t next = line->capacity < 1 ? need : line->capacity * 2;

        if (next < need) next = need;

        screen_cell_t *id = (screen_cell_t *)realloc(line->cells, next * sizeof(screen_cell_t));

        if (!id) return;

        line->cells = id;
        line->capacity = next;
    }

    memcpy(line->cells + line->width, cells, count * sizeof(screen_cell_t));
    line->width += count;
}

static void add_staging_line(staging_line_t **lines, size_t *count, size_t *capacity, const staging_line_t *line) {
    if (!count || !capacity || !line) return;

    if (*count == *capacity) {
        size_t next = *capacity < 1 ? 128 : *capacity * 2;
        staging_line_t *id = (staging_line_t *)realloc(*lines, next * sizeof(staging_line_t));

        if (!id) return;

        *lines = id;
        *capacity = next;
    }

    (*lines)[(*count)++] = *line;
}

static void commit_staging_cells(line_t **lines, size_t *count, size_t *capacity, const screen_cell_t *cells, size_t width, bool soft_wrap, int32_t columns) {
    if (!count || !capacity) return;

    if (*count == *capacity) {
        size_t next = *capacity < 1 ? 256 : *capacity * 2;
        line_t *id = (line_t *)realloc(*lines, next * sizeof(line_t));

        if (!id) return;

        *lines = id;
        *capacity = next;
    }

    screen_cell_t *copy = (screen_cell_t *)malloc((size_t)columns * sizeof(screen_cell_t));

    if (copy) {
        for (size_t j = 0; j < (size_t)columns; j++) reset_cell(&copy[j]);

        if (cells && width > 0) {
            size_t length = min(width, (size_t)columns);

            memcpy(copy, cells, length * sizeof(screen_cell_t));
        }
    }

    (*lines)[*count].cells = copy;
    (*lines)[*count].soft_wrap = soft_wrap;
    (*count)++;
}

screen_t *init_screen(int32_t rows, int32_t columns) {
    if (rows < 1) rows = screen_default_rows;
    if (columns < 1) columns = screen_default_columns;

    screen_t *screen = (screen_t *)calloc(1, sizeof(screen_t));

    if (!screen) return NULL;

    screen->grid = init_grid(rows, columns);

    if (!screen->grid) {
        free(screen);

        return NULL;
    }

    screen->rows = rows;
    screen->columns = columns;
    screen->soft_wrap = (bool *)calloc(rows, sizeof(bool));

    if (!screen->soft_wrap) {
        free_grid(screen->grid, rows);
        free(screen);

        return NULL;
    }

    screen->tab_stops = (bool *)calloc((size_t)columns, sizeof(bool));

    if (!screen->tab_stops) {
        free(screen->soft_wrap);
        free_grid(screen->grid, rows);
        free(screen);

        return NULL;
    }

    screen->attributes = default_attributes;
    screen->link_id = 0;
    screen->links.capacity = 8;
    screen->links.table = (char **)calloc(screen->links.capacity, sizeof(char *));

    if (!screen->links.table) {
        free(screen->tab_stops);
        free(screen->soft_wrap);
        free_grid(screen->grid, rows);
        free(screen);

        return NULL;
    }

    screen->links.size = 1;
    screen->auto_wrap = true;
    screen->insert_mode = false;
    screen->origin_mode = false;
    screen->scroll_top = 0;
    screen->scroll_bottom = rows - 1;
    reset_cursor(&screen->cursor);
    reset_cursor(&screen->saved_cursor);
    screen->saved_cursor_valid = false;
    screen->scrollback.capacity = 10000;
    screen->scrollback.lines = NULL;

    if (screen->scrollback.capacity > 0) {
        screen->scrollback.lines = (line_t *)calloc(screen->scrollback.capacity, sizeof(line_t));

        if (!screen->scrollback.lines) {
            free(screen->links.table);
            free(screen->tab_stops);
            free(screen->soft_wrap);
            free_grid(screen->grid, rows);
            free(screen);

            return NULL;
        }
    }

    screen->scrollback.size = 0;
    screen->scrollback.head = 0;
    screen->viewport_offset = 0;
    screen->viewport_delta = 0;

    for (int32_t j = 8; j < columns; j += 8) screen->tab_stops[j] = true;

    return screen;
}

void free_screen(screen_t *screen) {
    if (!screen) return;

    if (screen->scrollback.lines) {
        for (size_t i = 0; i < screen->scrollback.size; i++) {
            size_t index = (screen->scrollback.head + i) % screen->scrollback.capacity;

            if (screen->scrollback.lines[index].cells) free(screen->scrollback.lines[index].cells);
        }

        free(screen->scrollback.lines);
    }

    if (screen->links.table) {
        for (size_t i = 1; i < screen->links.size; i++) free(screen->links.table[i]);

        free(screen->links.table);
    }

    free(screen->tab_stops);
    free(screen->soft_wrap);
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
    if (rows < 1) rows = screen_default_rows;
    if (columns < 1) columns = screen_default_columns;
    if (screen->rows == rows && screen->columns == columns) return;

    screen_cell_t **grid = init_grid(rows, columns);

    if (!grid) return;

    bool *soft_wrap = (bool *)calloc((size_t)rows, sizeof(bool));

    if (!soft_wrap) {
        free_grid(grid, rows);

        return;
    }

    if (columns == screen->columns) {
        if (rows > screen->rows) {
            size_t take = (size_t)rows - (size_t)screen->rows;

            if (take > screen->scrollback.size) take = screen->scrollback.size;

            size_t start = screen->scrollback.size - take;

            for (size_t i = 0; i < take; i++) {
                size_t index = (screen->scrollback.head + start + i) % screen->scrollback.capacity;
                line_t *line = &screen->scrollback.lines[index];

                if (line->cells) {
                    size_t width = min(line->width, (size_t)screen->columns);

                    if (width > 0) memcpy(grid[i], line->cells, width * sizeof(screen_cell_t));
                }

                soft_wrap[i] = false;
            }

            for (int32_t i = 0; i < screen->rows; i++) {
                memcpy(grid[(int32_t)take + i], screen->grid[i], (size_t)screen->columns * sizeof(screen_cell_t));
                soft_wrap[(int32_t)take + i] = screen->soft_wrap[i];
            }

            for (size_t i = 0; i < take; i++) {
                size_t index = (screen->scrollback.head + start + i) % screen->scrollback.capacity;

                if (screen->scrollback.lines[index].cells) {
                    free(screen->scrollback.lines[index].cells);
                    screen->scrollback.lines[index].cells = NULL;
                }

                screen->scrollback.lines[index].width = 0;
                screen->scrollback.lines[index].soft_wrap = false;
            }

            screen->scrollback.size -= take;

            if (screen->scroll_bottom >= rows) screen->scroll_bottom = rows - 1;
            if (screen->cursor.row >= 0) screen->cursor.row += (int32_t)take;
            if (screen->cursor.row >= rows) screen->cursor.row = rows - 1;
            if (screen->cursor.column >= columns) screen->cursor.column = columns - 1;
        } else {
            int32_t drop = screen->rows - rows;

            for (int32_t i = 0; i < drop; i++) {
                bool empty = true;

                for (int32_t j = 0; j < screen->columns; j++) {
                    if (screen->grid[i][j].codepoint != ' ') {
                        empty = false;

                        break;
                    }
                }

                if (!empty && screen->scrollback.capacity > 0) {
                    size_t index;

                    if (screen->scrollback.size < screen->scrollback.capacity) {
                        index = (screen->scrollback.head + screen->scrollback.size) % screen->scrollback.capacity;
                        screen->scrollback.size++;
                    } else {
                        index = screen->scrollback.head;
                        free(screen->scrollback.lines[index].cells);
                        screen->scrollback.head = (screen->scrollback.head + 1) % screen->scrollback.capacity;
                    }

                    screen->scrollback.lines[index].cells = (screen_cell_t *)malloc((size_t)screen->columns * sizeof(screen_cell_t));

                    if (screen->scrollback.lines[index].cells) {
                        memcpy(screen->scrollback.lines[index].cells, screen->grid[i], (size_t)screen->columns * sizeof(screen_cell_t));
                        screen->scrollback.lines[index].width = (size_t)screen->columns;
                        screen->scrollback.lines[index].soft_wrap = screen->soft_wrap[i];
                    } else {
                        screen->scrollback.lines[index].cells = NULL;
                        screen->scrollback.lines[index].width = 0;
                        screen->scrollback.lines[index].soft_wrap = false;
                    }
                }
            }

            for (int32_t i = 0; i < rows; i++) {
                memcpy(grid[i], screen->grid[drop + i], (size_t)screen->columns * sizeof(screen_cell_t));
                soft_wrap[i] = screen->soft_wrap[drop + i];
            }

            if (screen->scroll_bottom >= rows) screen->scroll_bottom = rows - 1;

            if (screen->cursor.row >= drop) {
                screen->cursor.row -= drop;
            } else {
                screen->cursor.row = 0;
            }

            if (screen->cursor.column >= columns) screen->cursor.column = columns - 1;
        }

        free(screen->soft_wrap);
        free_grid(screen->grid, screen->rows);
        screen->grid = grid;
        screen->rows = rows;
        screen->columns = columns;
        screen->soft_wrap = soft_wrap;

        if (screen->viewport_offset > screen->scrollback.size) screen->viewport_offset = (int32_t)screen->scrollback.size;

        needs_layout(screen, 0, rows - 1);

        return;
    }

    bool *tab_stops = (bool *)calloc((size_t)columns, sizeof(bool));

    if (!tab_stops) {
        free(soft_wrap);
        free_grid(grid, rows);

        return;
    }

    for (int32_t j = 0; j < min(screen->columns, columns); j++) {
        if (screen->tab_stops[j]) tab_stops[j] = true;
    }

    staging_line_t current = {
        .capacity = 0,
        .cells = NULL,
        .width = 0,
    };

    staging_line_t *staging = NULL;
    size_t staging_count = 0;
    size_t staging_capacity = 0;

    for (size_t i = 0; i < screen->scrollback.size; i++) {
        size_t index = (screen->scrollback.head + i) % screen->scrollback.capacity;
        line_t *line = &screen->scrollback.lines[index];
        size_t used = line->width;

        while (used > 0 && line->cells && line->cells[used - 1].codepoint == ' ') used--;

        if (line->cells && used > 0) add_staging_cells(&current, line->cells, used);

        if (!line->soft_wrap) {
            add_staging_line(&staging, &staging_count, &staging_capacity, &current);
            current.capacity = 0;
            current.cells = NULL;
            current.width = 0;
        }
    }

    for (int32_t i = 0; i < screen->rows; i++) {
        int32_t used = screen->columns;

        while (used > 0 && screen->grid[i][used - 1].codepoint == ' ') used--;

        if (used > 0) add_staging_cells(&current, screen->grid[i], (size_t)used);

        if (!screen->soft_wrap[i]) {
            add_staging_line(&staging, &staging_count, &staging_capacity, &current);
            current.capacity = 0;
            current.cells = NULL;
            current.width = 0;
        }
    }

    if (current.cells) {
        add_staging_line(&staging, &staging_count, &staging_capacity, &current);
        current.capacity = 0;
        current.cells = NULL;
        current.width = 0;
    }

    line_t *reflow = NULL;
    size_t reflow_count = 0;
    size_t reflow_capacity = 0;

    for (size_t i = 0; i < staging_count; i++) {
        staging_line_t *line = &staging[i];

        while (line->width > 0 && line->cells[line->width - 1].codepoint == ' ') line->width--;

        if (line->width < 1) {
            commit_staging_cells(&reflow, &reflow_count, &reflow_capacity, NULL, 0, false, columns);

            continue;
        }

        size_t start = 0;

        while (start < line->width) {
            size_t todo = line->width - start;
            size_t take = min(todo, (size_t)columns);
            bool soft_wrap = start + take < line->width;

            commit_staging_cells(&reflow, &reflow_count, &reflow_capacity, line->cells + start, take, soft_wrap, columns);
            start += take;
        }
    }

    if (screen->scrollback.lines) {
        for (size_t i = 0; i < screen->scrollback.size; i++) {
            size_t index = (screen->scrollback.head + i) % screen->scrollback.capacity;

            free(screen->scrollback.lines[index].cells);
            screen->scrollback.lines[index].cells = NULL;
            screen->scrollback.lines[index].width = 0;
            screen->scrollback.lines[index].soft_wrap = false;
        }

        screen->scrollback.size = 0;
        screen->scrollback.head = 0;
    }

    if (screen->scrollback.size < 1) {
        while (reflow_count > 0) {
            line_t *line = &reflow[reflow_count - 1];
            bool empty = true;

            if (line->cells) {
                for (int32_t j = 0; j < columns; j++) {
                    if (line->cells[j].codepoint != ' ') {
                        empty = false;

                        break;
                    }
                }
            }

            if (empty) {
                if (line->cells) free(line->cells);

                line->cells = NULL;
                line->width = 0;
                line->soft_wrap = false;
                reflow_count--;
            } else {
                break;
            }
        }
    }

    size_t take = min(reflow_count, (size_t)rows);
    size_t start = reflow_count - take;

    for (size_t i = 0; i < take; i++) {
        size_t reflow_index = start + i;
        size_t grid_index;

        if (screen->scrollback.size < 1 && reflow_count < (size_t)rows) {
            grid_index = i;
        } else {
            grid_index = (size_t)rows - take + i;
        }

        if (reflow[reflow_index].cells) memcpy(grid[grid_index], reflow[reflow_index].cells, (size_t)columns * sizeof(screen_cell_t));

        soft_wrap[grid_index] = reflow[reflow_index].soft_wrap;
    }

    size_t left = start;
    size_t keep = left;

    if (keep > screen->scrollback.capacity) keep = screen->scrollback.capacity;

    if (keep > 0 && screen->scrollback.capacity > 0) {
        if (!screen->scrollback.lines) {
            screen->scrollback.lines = (line_t *)calloc(screen->scrollback.capacity, sizeof(line_t));

            if (!screen->scrollback.lines) keep = 0;
        }

        for (size_t i = left - keep; i < left; i++) {
            size_t index = (screen->scrollback.head + screen->scrollback.size) % screen->scrollback.capacity;

            screen->scrollback.lines[index].cells = reflow[i].cells;
            screen->scrollback.lines[index].width = (size_t)columns;
            screen->scrollback.lines[index].soft_wrap = reflow[i].soft_wrap;
            screen->scrollback.size++;
            reflow[i].cells = NULL;
        }
    }

    for (size_t i = 0; i < left - keep; i++) free(reflow[i].cells);
    for (size_t i = start; i < reflow_count; i++) free(reflow[i].cells);

    free(reflow);

    if (staging) {
        for (size_t i = 0; i < staging_count; i++) free(staging[i].cells);

        free(staging);
    }

    if (screen->scroll_bottom >= rows) screen->scroll_bottom = rows - 1;
    if (screen->cursor.row >= rows) screen->cursor.row = rows - 1;
    if (screen->cursor.column >= columns) screen->cursor.column = columns - 1;

    free(screen->tab_stops);
    free(screen->soft_wrap);
    free_grid(screen->grid, screen->rows);
    screen->grid = grid;
    screen->rows = rows;
    screen->columns = columns;
    screen->soft_wrap = soft_wrap;
    screen->tab_stops = tab_stops;

    if (screen->viewport_offset > screen->scrollback.size) screen->viewport_offset = (int32_t)screen->scrollback.size;

    needs_layout(screen, 0, rows - 1);

    return;
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

    cell->link_id = screen->link_id;
    cell->dirty = true;
}

ansi_sgr_t *screen_attributes(screen_t *screen) {
    return &screen->attributes;
}

void screen_set_attributes(screen_t *screen, const ansi_sgr_t *attributes) {
    if (!attributes) {
        screen->attributes = default_attributes;
    } else {
        screen->attributes = *attributes;
    }
}

uint32_t screen_link_id(screen_t *screen) {
    return screen->link_id;
}

const char *screen_link_url(screen_t *screen, uint32_t link_id) {
    if (link_id == 0) return NULL;
    if ((size_t)link_id >= screen->links.size) return NULL;

    return screen->links.table[link_id];
}

void screen_set_link(screen_t *screen, const char *url) {
    if (!url || url[0] == '\0') {
        screen->link_id = 0;

        return;
    }

    for (size_t i = 1; i < screen->links.size; i++) {
        if (screen->links.table[i] && strcmp(screen->links.table[i], url) == 0) {
            screen->link_id = (uint32_t)i;

            return;
        }
    }

    if (screen->links.size == screen->links.capacity) {
        size_t next = screen->links.capacity < 1 ? 8 : screen->links.capacity * 2;
        char **id = (char **)realloc(screen->links.table, next * sizeof(char *));

        if (!id) {
            screen->link_id = 0;

            return;
        }

        for (size_t i = screen->links.capacity; i < next; i++) id[i] = NULL;

        screen->links.table = id;
        screen->links.capacity = next;
    }

    char *copy = (char *)malloc(strlen(url) + 1);

    if (!copy) {
        screen->link_id = 0;

        return;
    }

    memcpy(copy, url, strlen(url) + 1);
    uint32_t index = (uint32_t)screen->links.size;
    screen->links.table[index] = copy;
    screen->links.size++;
    screen->link_id = index;
}

void screen_clear_link(screen_t *screen) {
    screen->link_id = 0;
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
    if (!text || length < 1) return;

    for (size_t i = 0; i < length; i++) {
        uint32_t codepoint = text[i];

        if ((text[i] & 0x80) != 0) codepoint = text[i];

        screen_write_utf32(screen, codepoint);
    }
}

void screen_write_utf32(screen_t *screen, uint32_t codepoint) {
    switch (codepoint) {
        case '\n':
            if (screen->cursor.row > -1 && screen->cursor.row < screen->rows) {
                screen->soft_wrap[screen->cursor.row] = false;
                screen_newline(screen);
            }

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
            if (screen->cursor.row >= 0 && screen->cursor.row < screen->rows) screen->soft_wrap[screen->cursor.row] = true;

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

            int32_t last = screen->cursor.row - 1;

            if (last > -1 && last < screen->rows) screen->soft_wrap[last] = true;
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

    reset_cell(&screen->grid[screen->cursor.row][screen->columns - 1]);
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
    int32_t last = screen->cursor.row;

    screen->cursor.row++;
    screen->cursor.column = 0;

    if (screen->cursor.row > screen->scroll_bottom) {
        screen_scroll_up(screen, 1);
        screen->cursor.row = screen->scroll_bottom;
    }

    if (last > -1 && last < screen->rows) screen->soft_wrap[last] = false;
}

void screen_carriage_return(screen_t *screen) {
    screen->cursor.column = 0;
}

void screen_tab(screen_t *screen) {
    int32_t next = screen->cursor.column + 1;

    while (next < screen->columns && !screen->tab_stops[next]) next++;

    if (next >= screen->columns) next = screen->columns - 1;

    screen->cursor.column = next;
}

void screen_set_tab_stop(screen_t *screen) {
    if (screen->cursor.column < 0 || screen->cursor.column >= screen->columns) return;

    screen->tab_stops[screen->cursor.column] = true;
}

void screen_clear_tab_stops(screen_t *screen, int32_t mode) {
    switch (mode) {
        case 0:
            if (screen->cursor.column >= 0 && screen->cursor.column < screen->columns) screen->tab_stops[screen->cursor.column] = false;

            break;
        case 2:
        case 3:
            memset(screen->tab_stops, 0, (size_t)screen->columns * sizeof(bool));

            break;
        default:
            break;
    }
}

void screen_reset_tab_stops(screen_t *screen) {
    memset(screen->tab_stops, 0, (size_t)screen->columns * sizeof(bool));

    for (int32_t j = 8; j < screen->columns; j += 8) screen->tab_stops[j] = true;
}

void screen_clear(screen_t *screen) {
    for (int32_t i = 0; i < screen->rows; i++) {
        for (int32_t j = 0; j < screen->columns; j++) reset_cell(&screen->grid[i][j]);

        screen->soft_wrap[i] = false;
    }

    needs_layout(screen, 0, screen->rows - 1);
}

void screen_erase(screen_t *screen, int32_t mode) {
    switch (mode) {
        case 0:
            for (int32_t j = screen->cursor.column; j < screen->columns; j++) {
                reset_cell(&screen->grid[screen->cursor.row][j]);
                screen->grid[screen->cursor.row][j].dirty = true;
            }

            for (int32_t i = screen->cursor.row + 1; i < screen->rows; i++) {
                for (int32_t j = 0; j < screen->columns; j++) {
                    reset_cell(&screen->grid[i][j]);
                    screen->grid[i][j].dirty = true;
                }
            }

            break;
        case 1:
            for (int32_t i = 0; i < screen->cursor.row; i++) {
                for (int32_t j = 0; j < screen->columns; j++) {
                    reset_cell(&screen->grid[i][j]);
                    screen->grid[i][j].dirty = true;
                }
            }

            for (int32_t j = 0; j <= screen->cursor.column; j++) {
                reset_cell(&screen->grid[screen->cursor.row][j]);
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
            for (int32_t j = screen->cursor.column; j < screen->columns; j++) reset_cell(&screen->grid[screen->cursor.row][j]);

            break;
        case 1:
            for (int32_t j = 0; j <= screen->cursor.column; j++) reset_cell(&screen->grid[screen->cursor.row][j]);

            break;
        case 2:
            for (int32_t j = 0; j < screen->columns; j++) reset_cell(&screen->grid[screen->cursor.row][j]);

            break;
    }

    screen->grid[screen->cursor.row][0].dirty = true;
    screen->soft_wrap[screen->cursor.row] = false;
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

    if (screen->scroll_top == 0 && screen->scroll_bottom == screen->rows - 1) {
        if (screen->scrollback.lines) {
            for (int32_t i = 0; i < lines; i++) {
                size_t index;

                if (screen->scrollback.size < screen->scrollback.capacity) {
                    index = (screen->scrollback.head + screen->scrollback.size) % screen->scrollback.capacity;
                    screen->scrollback.size++;
                } else {
                    index = screen->scrollback.head;
                    free(screen->scrollback.lines[index].cells);
                    screen->scrollback.head = (screen->scrollback.head + 1) % screen->scrollback.capacity;
                }

                screen->scrollback.lines[index].cells = malloc((size_t)screen->columns * sizeof(screen_cell_t));

                if (screen->scrollback.lines[index].cells) {
                    memcpy(screen->scrollback.lines[index].cells, screen->grid[i],
                           (size_t)screen->columns * sizeof(screen_cell_t));
                    screen->scrollback.lines[index].width = (size_t)screen->columns;
                    screen->scrollback.lines[index].soft_wrap = screen->soft_wrap[i];
                } else {
                    screen->scrollback.lines[index].cells = NULL;
                    screen->scrollback.lines[index].width = 0;
                    screen->scrollback.lines[index].soft_wrap = false;
                }
            }
        }

        if (screen->viewport_offset > 0) {
            screen->viewport_offset += lines;

            if (screen->viewport_offset > screen->scrollback.size) screen->viewport_offset = (int32_t)screen->scrollback.size;
        }
    }

    for (int32_t i = screen->scroll_top; i <= screen->scroll_bottom - lines; i++) {
        for (int32_t j = 0; j < screen->columns; j++) {
            screen->grid[i][j] = screen->grid[i + lines][j];
            screen->grid[i][j].dirty = true;
        }

        screen->soft_wrap[i] = screen->soft_wrap[i + lines];
    }

    for (int32_t i = screen->scroll_bottom - lines + 1; i <= screen->scroll_bottom; i++) {
        for (int32_t j = 0; j < screen->columns; j++) {
            reset_cell(&screen->grid[i][j]);
            screen->grid[i][j].dirty = true;
        }

        screen->soft_wrap[i] = false;
    }
}

void screen_scroll_down(screen_t *screen, int32_t lines) {
    if (lines < 1) return;

    for (int32_t i = screen->scroll_bottom; i >= screen->scroll_top + lines; i--) {
        for (int32_t j = 0; j < screen->columns; j++) {
            screen->grid[i][j] = screen->grid[i - lines][j];
            screen->grid[i][j].dirty = true;
        }

        screen->soft_wrap[i] = screen->soft_wrap[i - lines];
    }

    for (int32_t i = screen->scroll_top; i < screen->scroll_top + lines; i++) {
        for (int32_t j = 0; j < screen->columns; j++) {
            reset_cell(&screen->grid[i][j]);
            screen->grid[i][j].dirty = true;
        }

        screen->soft_wrap[i] = false;
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
            reset_cell(&screen->grid[i][j]);
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
            reset_cell(&screen->grid[i][j]);
            screen->grid[i][j].dirty = true;
        }
    }
}

void screen_set_scrollback_capacity(screen_t *screen, size_t capacity) {
    if (screen->scrollback.capacity == capacity || capacity > INT32_MAX) return;

    line_t *lines = NULL;

    if (capacity > 0) {
        lines = (line_t *)calloc(capacity, sizeof(line_t));

        if (!lines) return;
    }

    size_t keep = screen->scrollback.size;

    if (keep > capacity) keep = capacity;

    for (size_t i = 0; i < keep; i++) {
        size_t index = (screen->scrollback.head + screen->scrollback.size - keep + i) % screen->scrollback.capacity;

        if (screen->scrollback.lines) {
            lines[i].width = screen->scrollback.lines[index].width;
            lines[i].soft_wrap = screen->scrollback.lines[index].soft_wrap;

            if (screen->scrollback.lines[index].cells && lines[i].width > 0) {
                lines[i].cells = (screen_cell_t *)malloc(lines[i].width * sizeof(screen_cell_t));

                if (!lines[i].cells) {
                    for (size_t j = 0; j < i; j++) free(lines[j].cells);

                    free(lines);

                    return;
                }

                memcpy(lines[i].cells, screen->scrollback.lines[index].cells, lines[i].width * sizeof(screen_cell_t));
            }
        } else {
            lines[i].width = 0;
            lines[i].soft_wrap = false;
        }
    }

    if (screen->scrollback.lines) {
        for (size_t i = 0; i < screen->scrollback.size; i++) {
            size_t index = (screen->scrollback.head + i) % screen->scrollback.capacity;

            if (screen->scrollback.lines[index].cells) free(screen->scrollback.lines[index].cells);
        }

        free(screen->scrollback.lines);
    }

    screen->scrollback.capacity = capacity;
    screen->scrollback.lines = lines;
    screen->scrollback.size = keep;
    screen->scrollback.head = 0;

    if (screen->viewport_offset > screen->scrollback.size) screen->viewport_offset = (int32_t)screen->scrollback.size;
}

screen_cell_t *screen_viewport_row(screen_t *screen, int32_t index, bool *mutable) {
    if (index < 0 || index >= screen->rows) return NULL;

    int32_t total = (int32_t)screen->scrollback.size + screen->rows;
    int32_t start = total - screen->rows - screen->viewport_offset;

    if (start < 0) start = 0;

    int32_t i = start + index;

    if ((size_t)i < screen->scrollback.size) {
        if (mutable) *mutable = false;
        if (!screen->scrollback.lines) return NULL;

        size_t scrollback_index = (screen->scrollback.head + (size_t)i) % screen->scrollback.capacity;

        return screen->scrollback.lines[scrollback_index].cells;
    }

    int32_t grid_index = i - (int32_t)screen->scrollback.size;

    if (grid_index < screen->rows) {
        if (mutable) *mutable = true;

        return screen->grid[grid_index];
    }

    return NULL;
}

int32_t screen_viewport_offset(screen_t *screen) {
    return screen->viewport_offset;
}

void screen_set_viewport_offset(screen_t *screen, int32_t offset) {
    if (offset < 0) offset = 0;
    if (offset > (int32_t)screen->scrollback.size) offset = (int32_t)screen->scrollback.size;

    int32_t last = screen->viewport_offset;

    screen->viewport_offset = offset;
    screen->viewport_delta += screen->viewport_offset - last;
}

void screen_viewport_scroll(screen_t *screen, int32_t delta) {
    screen_set_viewport_offset(screen, screen->viewport_offset + delta);
}

int32_t screen_stage_viewport_scroll(screen_t *screen) {
    int32_t delta = screen->viewport_delta;

    screen->viewport_delta = 0;

    return delta;
}
