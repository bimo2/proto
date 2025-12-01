//
//  screen_context.h
//  o1
//
//  Created by gpt-5-high on 2025-10-16.
//

#ifndef SCREEN_CONTEXT_H
#define SCREEN_CONTEXT_H

#include "ansi.h"
#include "screen.h"
#include "unicode.h"

#include <stdbool.h>
#include <stdint.h>

typedef struct screen_context_t screen_context_t;
typedef void (*screen_context_response_callback_t)(void *, const char *);
typedef void (*screen_context_title_callback_t)(void *, const char *);
typedef void (*screen_context_bell_callback_t)(void *);
typedef void (*screen_context_mouse_callback_t)(void *, bool);

typedef enum screen_context_mouse_mode_t {
    SCREEN_CONTEXT_MOUSE_NONE = 0,
    SCREEN_CONTEXT_MOUSE_X10,
    SCREEN_CONTEXT_MOUSE_NORMAL,
    SCREEN_CONTEXT_MOUSE_ALL,
} screen_context_mouse_mode_t;

screen_context_t *init_screen_context(void);

void free_screen_context(screen_context_t *context);

void screen_context_reset(screen_context_t *context);

screen_t *screen_context_current_screen(screen_context_t *context);

void screen_context_set_grid(screen_context_t *context, int32_t rows, int32_t columns);

unicode_codepoint_t screen_context_codepoint(screen_context_t *context);

void screen_context_set_codepoint(screen_context_t *context, unicode_codepoint_t scalar);

const char *screen_context_title(screen_context_t *context);

void screen_context_set_title(screen_context_t *context, const char *title);

void screen_context_set_title_callback(screen_context_t *context, screen_context_title_callback_t callback, void *user_data);

void screen_context_set_response_callback(screen_context_t *context, screen_context_response_callback_t callback, void *user_data);

void screen_context_set_bell_callback(screen_context_t *context, screen_context_bell_callback_t callback, void *user_data);

void screen_context_set_mouse_callback(screen_context_t *context, screen_context_mouse_callback_t callback, void *user_data);

void screen_context_update(screen_context_t *context, const ansi_t *ansi);

bool screen_context_bracketed_paste(screen_context_t *context);

bool screen_context_cursor_keys(screen_context_t *context);

screen_context_mouse_mode_t screen_context_mouse_mode(screen_context_t *context);

bool screen_context_mouse_sgr(screen_context_t *context);

bool screen_context_focus_reporting(screen_context_t *context);

#endif // !SCREEN_CONTEXT_H
