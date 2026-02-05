//
//  screen.h
//  o1
//
//  Created by gpt-5-high on 2025-10-16.
//

#ifndef SCREEN_H
#define SCREEN_H

#include "ansi.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct screen_cell_t {
    uint32_t codepoint;
    ansi_sgr_t attributes;
    uint8_t width;
    uint32_t link_id;
    bool dirty;
} screen_cell_t;

typedef struct screen_cursor_t {
    int32_t row;
    int32_t column;
    bool visible;
    bool blink;
    ansi_sgr_t attributes;
} screen_cursor_t;

typedef struct screen_t screen_t;

extern uint32_t screen_default_rows;
extern uint32_t screen_default_columns;
extern uint32_t screen_default_width;
extern uint32_t screen_default_height;
extern uint32_t screen_default_offset;

screen_t *init_screen(int32_t rows, int32_t columns);

void free_screen(screen_t *screen);

int32_t screen_rows(screen_t *screen);

int32_t screen_columns(screen_t *screen);

void screen_set_grid(screen_t *screen, int32_t rows, int32_t columns);

screen_cell_t *screen_cell(screen_t *screen, int32_t row, int32_t column);

void screen_set_cell(screen_t *screen, int32_t row, int32_t column, uint32_t codepoint, const ansi_sgr_t *attributes);

ansi_sgr_t *screen_attributes(screen_t *screen);

void screen_set_attributes(screen_t *screen, const ansi_sgr_t *attributes);

uint32_t screen_link_id(screen_t *screen);

const char *screen_link_url(screen_t *screen, uint32_t link_id);

void screen_set_link(screen_t *screen, const char *url);

void screen_clear_link(screen_t *screen);

bool screen_auto_wrap(screen_t *screen);

void screen_set_auto_wrap(screen_t *screen, bool enabled);

bool screen_insert_mode(screen_t *screen);

void screen_set_insert_mode(screen_t *screen, bool enabled);

bool screen_new_line_mode(screen_t *screen);

void screen_set_new_line_mode(screen_t *screen, bool enabled);

bool screen_origin_mode(screen_t *screen);

void screen_set_origin_mode(screen_t *screen, bool enabled);

screen_cursor_t *screen_cursor(screen_t *screen);

void screen_set_cursor_position(screen_t *screen, int32_t row, int32_t column);

void screen_move_cursor_absolute(screen_t *screen, int32_t row, int32_t column);

void screen_move_cursor_relative(screen_t *screen, int32_t rows, int32_t columns);

void screen_move_cursor_column(screen_t *screen, int32_t column);

void screen_save_cursor(screen_t *screen);

void screen_restore_cursor(screen_t *screen);

void screen_write_text(screen_t *screen, const uint8_t *text, size_t length);

void screen_write_utf32(screen_t *screen, uint32_t codepoint);

void screen_insert_utf32(screen_t *screen, uint32_t codepoint);

void screen_delete_utf32(screen_t *screen);

void screen_backspace(screen_t *screen);

void screen_newline(screen_t *screen);

void screen_carriage_return(screen_t *screen);

void screen_tab(screen_t *screen);

void screen_set_tab_stop(screen_t *screen);

void screen_reset_tab_stops(screen_t *screen);

void screen_clear_tab_stops(screen_t *screen, int32_t mode);

void screen_clear(screen_t *screen);

void screen_erase(screen_t *screen, int32_t mode);

void screen_erase_line(screen_t *screen, int32_t mode);

void screen_set_scroll_area(screen_t *screen, int32_t top, int32_t bottom);

void screen_scroll_up(screen_t *screen, int32_t lines);

void screen_scroll_down(screen_t *screen, int32_t lines);

void screen_index(screen_t *screen);

void screen_reverse_index(screen_t *screen);

void screen_insert_line(screen_t *screen, int32_t count);

void screen_delete_line(screen_t *screen, int32_t count);

void screen_insert_inline(screen_t *screen, int32_t count);

void screen_delete_inline(screen_t *screen, int32_t count);

void screen_erase_inline(screen_t *screen, int32_t count);

void screen_insert_column(screen_t *screen, int32_t count);

void screen_delete_column(screen_t *screen, int32_t count);

void screen_set_scrollback_capacity(screen_t *screen, size_t capacity);

int32_t screen_total_rows(screen_t *screen);

screen_cell_t *screen_absolute_row(screen_t *screen, int32_t index, bool *soft_wrap, bool *wide_wrap);

int32_t screen_viewport_index(screen_t *screen);

screen_cell_t *screen_viewport_row(screen_t *screen, int32_t index, bool *mutable);

int32_t screen_viewport_offset(screen_t *screen);

void screen_set_viewport_offset(screen_t *screen, int32_t offset);

void screen_viewport_scroll(screen_t *screen, int32_t delta);

int32_t screen_stage_viewport_scroll(screen_t *screen);

void screen_needs_display(screen_t *screen);

bool screen_invalidate_needs_display(screen_t *screen);

#endif // !SCREEN_H
