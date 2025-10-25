//
//  screen_manager.c
//  o1
//
//  Created by gpt-5-high on 2025-10-16.
//

#include "screen_manager.h"

#include "ansi.h"
#include "screen.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct screen_manager_t {
    screen_t *main;
    screen_t *alternate;
    screen_t *current;
    bool bracketed_paste;
    bool cursor_keys;
    screen_manager_mouse_mode_t mouse_mode;
    bool mouse_sgr;
    bool focus_reporting;
    uint32_t last_codepoint;
    char *title;
    screen_manager_title_callback_t on_title;
    void *title_user_data;
    screen_manager_response_callback_t on_response;
    void *response_user_data;
    screen_manager_bell_callback_t on_bell;
    void *bell_user_data;
};

static inline void apply_text(screen_manager_t *manager, const uint8_t *text, size_t length) {
    if (!text || length < 1) return;

    for (size_t i = 0; i < length; i++) screen_write_utf32(manager->current, text[i]);

    manager->last_codepoint = text[length - 1];
}

static inline void apply_esc(screen_manager_t *manager, const ansi_esc_t *esc) {
    if (!esc || !manager->current) return;

    switch (esc->event) {
        case ANSI_ESC_DEC_SAVE_CURSOR:
            screen_save_cursor(manager->current);

            break;
        case ANSI_ESC_DEC_RESTORE_CURSOR:
            screen_restore_cursor(manager->current);

            break;
        case ANSI_ESC_TAB_SET:
            screen_tab(manager->current);

            break;
        case ANSI_ESC_IND:
            screen_scroll_up(manager->current, 1);

            break;
        case ANSI_ESC_RI:
            screen_scroll_down(manager->current, 1);

            break;
        case ANSI_ESC_RESET:
            screen_clear(manager->current);
            screen_set_attributes(manager->current, NULL);
            screen_set_auto_wrap(manager->current, true);
            screen_set_insert_mode(manager->current, false);
            screen_set_origin_mode(manager->current, false);
            screen_set_cursor_position(manager->current, 0, 0);
            screen_set_scroll_area(manager->current, 1, screen_rows(manager->current));

            break;
    }
}

static inline int csi_parameter(const ansi_csi_t *csi, size_t index, int fallback) {
    if (index >= csi->parameters_count) return fallback;

    return csi->parameters[index] < 0 ? fallback : csi->parameters[index];
}

static inline void apply_csi(screen_manager_t *manager, const ansi_csi_t *csi) {
    if (!csi || !manager->current) return;

    switch (csi->event) {
        case ANSI_CSI_CUU: {
            int value = csi_parameter(csi, 0, 1);

            screen_move_cursor_relative(manager->current, -value, 0);

            break;
        }
        case ANSI_CSI_CUD: {
            int value = csi_parameter(csi, 0, 1);

            screen_move_cursor_relative(manager->current, value, 0);

            break;
        }
        case ANSI_CSI_CUF: {
            int value = csi_parameter(csi, 0, 1);

            screen_move_cursor_relative(manager->current, 0, value);

            break;
        }
        case ANSI_CSI_CUB: {
            int value = csi_parameter(csi, 0, 1);

            screen_move_cursor_relative(manager->current, 0, -value);

            break;
        }
        case ANSI_CSI_CNL: {
            int value = csi_parameter(csi, 0, 1);

            for (int i = 0; i < value; i++) screen_newline(manager->current);

            break;
        }
        case ANSI_CSI_CPL: {
            int value = csi_parameter(csi, 0, 1);

            screen_move_cursor_relative(manager->current, -value, 0);
            screen_carriage_return(manager->current);

            break;
        }
        case ANSI_CSI_CHA: {
            int column = csi_parameter(csi, 0, 1);

            screen_move_cursor_absolute(manager->current, screen_cursor(manager->current)->row + 1, column);

            break;
        }
        case ANSI_CSI_CUP:
        case ANSI_CSI_HVP: {
            int row = csi_parameter(csi, 0, 1);
            int column = csi_parameter(csi, 1, 1);

            screen_move_cursor_absolute(manager->current, row, column);

            break;
        }
        case ANSI_CSI_ED: {
            int mode = csi_parameter(csi, 0, 0);

            screen_erase(manager->current, mode);

            break;
        }
        case ANSI_CSI_EL: {
            int mode = csi_parameter(csi, 0, 0);

            screen_erase_line(manager->current, mode);

            break;
        }
        case ANSI_CSI_DECSED: {
            int mode = csi_parameter(csi, 0, 0);

            screen_erase(manager->current, mode);

            break;
        }
        case ANSI_CSI_DECSEL: {
            int mode = csi_parameter(csi, 0, 0);

            screen_erase_line(manager->current, mode);

            break;
        }
        case ANSI_CSI_SU: {
            int value = csi_parameter(csi, 0, 1);

            screen_scroll_up(manager->current, value);

            break;
        }
        case ANSI_CSI_SD: {
            int value = csi_parameter(csi, 0, 1);

            screen_scroll_down(manager->current, value);

            break;
        }
        case ANSI_CSI_DECSTBM: {
            int top = csi_parameter(csi, 0, 1);
            int bottom = csi_parameter(csi, 1, screen_rows(manager->current));

            screen_set_scroll_area(manager->current, top, bottom);

            break;
        }
        case ANSI_CSI_SGR: {
            screen_set_attributes(manager->current, &csi->attributes);

            break;
        }
        case ANSI_CSI_SM: {
            if (csi->mode == ANSI_MODE_INSERT) screen_set_insert_mode(manager->current, true);

            break;
        }
        case ANSI_CSI_RM: {
            if (csi->mode == ANSI_MODE_INSERT) screen_set_insert_mode(manager->current, false);

            break;
        }
        case ANSI_CSI_DECSET: {
            switch (csi->dec_mode) {
                case ANSI_DEC_MODE_CURSOR_KEYS:
                    manager->cursor_keys = true;

                    break;
                case ANSI_DEC_MODE_ORIGIN:
                    screen_set_origin_mode(manager->current, true);

                    break;
                case ANSI_DEC_MODE_AUTO_WRAP:
                    screen_set_auto_wrap(manager->current, true);

                    break;
                case ANSI_DEC_MODE_CURSOR_BLINK:
                    screen_cursor(manager->current)->blink = true;

                    break;
                case ANSI_DEC_MODE_CURSOR_VISIBLE:
                    screen_cursor(manager->current)->visible = true;

                    break;
                case ANSI_DEC_MODE_MOUSE_X10:
                    manager->mouse_mode = SCREEN_MANAGER_MOUSE_X10;

                    break;
                case ANSI_DEC_MODE_MOUSE_NORMAL:
                    manager->mouse_mode = SCREEN_MANAGER_MOUSE_NORMAL;

                    break;
                case ANSI_DEC_MODE_MOUSE_ALL:
                    manager->mouse_mode = SCREEN_MANAGER_MOUSE_ALL;

                    break;
                case ANSI_DEC_MODE_FOCUS_REPORTING:
                    manager->focus_reporting = true;

                    break;
                case ANSI_DEC_MODE_MOUSE_SGR:
                    manager->mouse_sgr = true;

                    break;
                case ANSI_DEC_MODE_ALTERNATE_SCREEN:
                case ANSI_DEC_MODE_ALTERNATE_SCREEN_SAVE_CURSOR: {
                    if (!manager->alternate) manager->alternate = init_screen(screen_rows(manager->main), screen_columns(manager->main));
                    if (csi->dec_mode == ANSI_DEC_MODE_ALTERNATE_SCREEN_SAVE_CURSOR) screen_save_cursor(manager->main);

                    manager->current = manager->alternate;

                    break;
                }
                case ANSI_DEC_MODE_SAVE_CURSOR:
                    screen_save_cursor(manager->current);

                    break;
                case ANSI_DEC_MODE_BRACKETED_PASTE:
                    manager->bracketed_paste = true;

                    break;
                case ANSI_DEC_MODE_UNKNOWN:
                    break;
            }

            break;
        }
        case ANSI_CSI_DECRST: {
            switch (csi->dec_mode) {
                case ANSI_DEC_MODE_CURSOR_KEYS:
                    manager->cursor_keys = false;

                    break;
                case ANSI_DEC_MODE_ORIGIN:
                    screen_set_origin_mode(manager->current, false);

                    break;
                case ANSI_DEC_MODE_AUTO_WRAP:
                    screen_set_auto_wrap(manager->current, false);

                    break;
                case ANSI_DEC_MODE_CURSOR_BLINK:
                    screen_cursor(manager->current)->blink = false;

                    break;
                case ANSI_DEC_MODE_CURSOR_VISIBLE:
                    screen_cursor(manager->current)->visible = false;

                    break;
                case ANSI_DEC_MODE_MOUSE_X10:
                case ANSI_DEC_MODE_MOUSE_NORMAL:
                case ANSI_DEC_MODE_MOUSE_ALL:
                    manager->mouse_mode = SCREEN_MANAGER_MOUSE_NONE;

                    break;
                case ANSI_DEC_MODE_FOCUS_REPORTING:
                    manager->focus_reporting = false;

                    break;
                case ANSI_DEC_MODE_MOUSE_SGR:
                    manager->mouse_sgr = false;

                    break;
                case ANSI_DEC_MODE_ALTERNATE_SCREEN:
                case ANSI_DEC_MODE_ALTERNATE_SCREEN_SAVE_CURSOR: {
                    if (manager->current == manager->alternate) {
                        screen_clear(manager->alternate);
                        manager->current = manager->main;

                        if (csi->dec_mode == ANSI_DEC_MODE_ALTERNATE_SCREEN_SAVE_CURSOR) screen_restore_cursor(manager->main);
                    }

                    break;
                }
                case ANSI_DEC_MODE_SAVE_CURSOR:
                    screen_restore_cursor(manager->current);

                    break;
                case ANSI_DEC_MODE_BRACKETED_PASTE:
                    manager->bracketed_paste = false;

                    break;
                case ANSI_DEC_MODE_UNKNOWN:
                    break;
            }

            break;
        }
        case ANSI_CSI_DSR:
        case ANSI_CSI_DEC_DSR: {
            if (manager->on_response) {
                int value = csi_parameter(csi, 0, 0);

                switch (value) {
                    case 5:
                        if (csi->dec_private) break;

                        manager->on_response(manager->response_user_data, "\x1b[0n");

                        break;
                    case 6: {
                        screen_cursor_t *cursor = screen_cursor(manager->current);
                        int row = cursor->row + 1;
                        int column = cursor->column + 1;
                        char buffer[32];

                        snprintf(buffer, sizeof(buffer), "\x1b[%d;%dR", row, column);
                        manager->on_response(manager->response_user_data, buffer);

                        break;
                    }
                    default:
                        break;
                }
            }

            break;
        }
        case ANSI_CSI_DA: {
            if (manager->on_response) manager->on_response(manager->response_user_data, "\x1b[?1;2c");

            break;
        }
        case ANSI_CSI_REP: {
            int value = csi_parameter(csi, 0, 1);

            if (manager->last_codepoint != 0) {
                for (int i = 0; i < value; i++) screen_write_utf32(manager->current, manager->last_codepoint);
            }

            break;
        }
        case ANSI_CSI_TBC:
            // TODO

            break;
        case ANSI_CSI_BRP_START:
        case ANSI_CSI_BRP_END:
            // TODO

            break;
        case ANSI_CSI_KIND_UNKNOWN:
            break;
    }
}

static inline void apply_osc(screen_manager_t *manager, const ansi_osc_t *osc) {
    if (!osc) return;

    switch (osc->event) {
        case ANSI_OSC_SET_TITLE: {
            if (osc->payload) {
                size_t length = strlen(osc->payload);
                char *copy = (char *)malloc(length + 1);

                if (copy) {
                    memcpy(copy, osc->payload, length + 1);
                    free(manager->title);
                    manager->title = copy;
                }

                if (manager->on_title) manager->on_title(manager->title_user_data, osc->payload);
            }

            break;
        }
        case ANSI_OSC_HYPERLINK:
        case ANSI_OSC_CLIPBOARD:
        case ANSI_OSC_KIND_UNKNOWN:
            break;
    }
}

screen_manager_t *init_screen_manager(void) {
    screen_manager_t *manager = (screen_manager_t *)calloc(1, sizeof(screen_manager_t));

    if (!manager) return NULL;

    screen_t *main = init_screen(-1, -1);

    if (!main) {
        free(manager);

        return NULL;
    }

    manager->main = main;
    manager->alternate = NULL;
    manager->current = main;
    manager->bracketed_paste = false;
    manager->cursor_keys = false;
    manager->mouse_mode = SCREEN_MANAGER_MOUSE_NONE;
    manager->mouse_sgr = false;
    manager->focus_reporting = false;
    manager->last_codepoint = 0;
    manager->title = NULL;
    manager->on_title = NULL;
    manager->title_user_data = NULL;
    manager->on_response = NULL;
    manager->response_user_data = NULL;
    manager->on_bell = NULL;
    manager->bell_user_data = NULL;

    return manager;
}

void free_screen_manager(screen_manager_t *manager) {
    if (!manager) return;

    free(manager->title);
    free_screen(manager->alternate);
    free_screen(manager->main);
    free(manager);
}

void screen_manager_reset(screen_manager_t *manager) {
    manager->current = manager->main;
    free_screen(manager->alternate);
    manager->alternate = NULL;
    manager->bracketed_paste = false;
    manager->cursor_keys = false;
    manager->mouse_mode = SCREEN_MANAGER_MOUSE_NONE;
    manager->mouse_sgr = false;
    manager->focus_reporting = false;
    manager->last_codepoint = 0;
    free(manager->title);
    manager->title = NULL;
}

screen_t *screen_manager_current_screen(screen_manager_t *manager) {
    return manager->current;
}

void screen_manager_set_grid(screen_manager_t *manager, int32_t rows, int32_t columns) {
    if (manager->main) screen_set_grid(manager->main, rows, columns);
    if (manager->alternate) screen_set_grid(manager->alternate, rows, columns);
}

const char *screen_manager_title(screen_manager_t *manager) {
    return manager->title;
}

void screen_manager_set_title(screen_manager_t *manager, const char *title) {
    if (!title) {
        free(manager->title);
        manager->title = NULL;

        return;
    }

    size_t length = strlen(title);
    char *copy = (char *)malloc(length + 1);

    if (!copy) return;

    memcpy(copy, title, length + 1);
    free(manager->title);
    manager->title = copy;
}

void screen_manager_set_title_callback(screen_manager_t *manager, screen_manager_title_callback_t callback, void *user_data) {
    manager->on_title = callback;
    manager->title_user_data = user_data;
}

void screen_manager_set_response_callback(screen_manager_t *manager, screen_manager_response_callback_t callback, void *user_data) {
    manager->on_response = callback;
    manager->response_user_data = user_data;
}

void screen_manager_set_bell_callback(screen_manager_t *manager, screen_manager_bell_callback_t callback, void *user_data) {
    manager->on_bell = callback;
    manager->bell_user_data = user_data;
}

void screen_manager_update(screen_manager_t *manager, const ansi_t *ansi) {
    if (!ansi) return;

    switch (ansi->event) {
        case ANSI_EVENT_TEXT:
            apply_text(manager, ansi->text.bytes, ansi->text.length);

            break;
        case ANSI_EVENT_ESC:
            apply_esc(manager, &ansi->esc);

            break;
        case ANSI_EVENT_CSI:
            apply_csi(manager, &ansi->csi);

            break;
        case ANSI_EVENT_OSC:
            apply_osc(manager, &ansi->osc);

            break;
        case ANSI_EVENT_BELL:
            if (manager->on_bell) manager->on_bell(manager->bell_user_data);

            break;
        case ANSI_EVENT_UNKNOWN:
            break;
    }
}

bool screen_manager_bracketed_paste(screen_manager_t *manager) {
    return manager->bracketed_paste;
}

bool screen_manager_cursor_keys(screen_manager_t *manager) {
    return manager->cursor_keys;
}

screen_manager_mouse_mode_t screen_manager_mouse_mode(screen_manager_t *manager) {
    return manager->mouse_mode;
}

bool screen_manager_mouse_sgr(screen_manager_t *manager) {
    return manager->mouse_sgr;
}

bool screen_manager_focus_reporting(screen_manager_t *manager) {
    return manager->focus_reporting;
}
