//
//  screen_manager.h
//  o1
//
//  Created by gpt-5-high on 2025-10-16.
//

#ifndef SCREEN_MANAGER_H
#define SCREEN_MANAGER_H

#include "ansi.h"
#include "screen.h"
#include "unicode.h"

#include <stdbool.h>
#include <stdint.h>

typedef struct screen_manager_t screen_manager_t;
typedef void (*screen_manager_response_callback_t)(void *, const char *);
typedef void (*screen_manager_title_callback_t)(void *, const char *);
typedef void (*screen_manager_bell_callback_t)(void *);
typedef void (*screen_manager_mouse_callback_t)(void *, bool);

typedef enum screen_manager_mouse_mode_t {
    SCREEN_MANAGER_MOUSE_NONE = 0,
    SCREEN_MANAGER_MOUSE_X10,
    SCREEN_MANAGER_MOUSE_NORMAL,
    SCREEN_MANAGER_MOUSE_ALL,
} screen_manager_mouse_mode_t;

screen_manager_t *init_screen_manager(void);

void free_screen_manager(screen_manager_t *manager);

void screen_manager_reset(screen_manager_t *manager);

screen_t *screen_manager_current_screen(screen_manager_t *manager);

void screen_manager_set_grid(screen_manager_t *manager, int32_t rows, int32_t columns);

unicode_codepoint_t screen_manager_codepoint(screen_manager_t *manager);

void screen_manager_set_codepoint(screen_manager_t *manager, unicode_codepoint_t scalar);

const char *screen_manager_title(screen_manager_t *manager);

void screen_manager_set_title(screen_manager_t *manager, const char *title);

void screen_manager_set_title_callback(screen_manager_t *manager, screen_manager_title_callback_t callback, void *user_data);

void screen_manager_set_response_callback(screen_manager_t *manager, screen_manager_response_callback_t callback, void *user_data);

void screen_manager_set_bell_callback(screen_manager_t *manager, screen_manager_bell_callback_t callback, void *user_data);

void screen_manager_set_mouse_callback(screen_manager_t *manager, screen_manager_mouse_callback_t callback, void *user_data);

void screen_manager_update(screen_manager_t *manager, const ansi_t *ansi);

bool screen_manager_bracketed_paste(screen_manager_t *manager);

bool screen_manager_cursor_keys(screen_manager_t *manager);

screen_manager_mouse_mode_t screen_manager_mouse_mode(screen_manager_t *manager);

bool screen_manager_mouse_sgr(screen_manager_t *manager);

bool screen_manager_focus_reporting(screen_manager_t *manager);

#endif // !SCREEN_MANAGER_H
