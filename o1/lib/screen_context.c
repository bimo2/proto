//
//  screen_context.c
//  o1
//
//  Created by gpt-5-high on 2025-10-16.
//

#include "screen_context.h"

#include "ansi.h"
#include "include.h"
#include "screen.h"
#include "unicode.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct screen_context_t {
    screen_t *main;
    screen_t *alternate;
    screen_t *current;
    unicode_codepoint_t utf_codepoint;
    bool bracketed_paste;
    bool cursor_keys;
    screen_context_mouse_mode_t mouse_mode;
    bool mouse_sgr;
    bool focus_reporting;
    uint32_t last_codepoint;
    char *title;
    screen_context_title_callback_t on_title;
    void *title_user_data;
    screen_context_response_callback_t on_response;
    void *response_user_data;
    screen_context_bell_callback_t on_bell;
    void *bell_user_data;
    screen_context_mouse_callback_t on_mouse;
    void *mouse_user_data;
};

static inline void write_codepoint(screen_context_t *context, uint32_t codepoint) {
    if (!context->current) return;

    if (unicode_codepoint_supported(codepoint, context->utf_codepoint)) {
        screen_write_utf32(context->current, codepoint);

        return;
    }

    int width = unicode_codepoint_width(codepoint);

    if (width < 1) return;

    uint32_t replacement = width > 1 ? UNICODE_WIDE_REPLACEMENT : UNICODE_REPLACEMENT;

    screen_write_utf32(context->current, replacement);
}

static inline void apply_text(screen_context_t *context, const uint8_t *text, size_t length) {
    if (!text || length < 1) return;

    size_t i = 0;
    uint32_t last = 0;

    while (i < length) {
        uint32_t codepoint = 0;
        size_t used = unicode_decode_utf8(text + i, length - i, &codepoint);

        if (used < 1) break;

        write_codepoint(context, codepoint);
        last = codepoint;
        i += used;
    }

    context->last_codepoint = last;
}

static inline void apply_esc(screen_context_t *context, const ansi_esc_t *esc) {
    if (!esc || !context->current) return;

    switch (esc->event) {
        case ANSI_ESC_DEC_SAVE_CURSOR:
            screen_save_cursor(context->current);

            break;
        case ANSI_ESC_DEC_RESTORE_CURSOR:
            screen_restore_cursor(context->current);

            break;
        case ANSI_ESC_TAB_SET:
            screen_set_tab_stop(context->current);

            break;
        case ANSI_ESC_IND:
            screen_index(context->current);

            break;
        case ANSI_ESC_RI:
            screen_reverse_index(context->current);

            break;
        case ANSI_ESC_RESET:
            screen_clear(context->current);
            screen_set_attributes(context->current, NULL);
            screen_set_auto_wrap(context->current, true);
            screen_set_insert_mode(context->current, false);
            screen_set_new_line_mode(context->current, false);
            screen_set_origin_mode(context->current, false);
            screen_set_cursor_position(context->current, 0, 0);
            screen_cursor(context->current)->visible = true;
            screen_cursor(context->current)->blink = true;
            screen_set_scroll_area(context->current, 1, screen_rows(context->current));
            screen_reset_tab_stops(context->current);

            break;
    }
}

static inline int csi_parameter(const ansi_csi_t *csi, size_t index, int fallback) {
    if (index >= csi->parameters_count) return fallback;

    return csi->parameters[index] < 0 ? fallback : csi->parameters[index];
}

static inline void apply_csi(screen_context_t *context, const ansi_csi_t *csi) {
    if (!csi || !context->current) return;

    switch (csi->event) {
        case ANSI_CSI_CUU: {
            int value = csi_parameter(csi, 0, 1);

            screen_move_cursor_relative(context->current, -value, 0);

            break;
        }
        case ANSI_CSI_CUD: {
            int value = csi_parameter(csi, 0, 1);

            screen_move_cursor_relative(context->current, value, 0);

            break;
        }
        case ANSI_CSI_CUF: {
            int value = csi_parameter(csi, 0, 1);

            screen_move_cursor_relative(context->current, 0, value);

            break;
        }
        case ANSI_CSI_CUB: {
            int value = csi_parameter(csi, 0, 1);

            screen_move_cursor_relative(context->current, 0, -value);

            break;
        }
        case ANSI_CSI_CNL: {
            int value = csi_parameter(csi, 0, 1);

            for (int i = 0; i < value; i++) screen_newline(context->current);

            screen_carriage_return(context->current);

            break;
        }
        case ANSI_CSI_CPL: {
            int value = csi_parameter(csi, 0, 1);

            screen_move_cursor_relative(context->current, -value, 0);
            screen_carriage_return(context->current);

            break;
        }
        case ANSI_CSI_CHA:
        case ANSI_CSI_HPA: {
            int column = csi_parameter(csi, 0, 1);

            screen_move_cursor_column(context->current, column);

            break;
        }
        case ANSI_CSI_CUP:
        case ANSI_CSI_HVP: {
            int row = csi_parameter(csi, 0, 1);
            int column = csi_parameter(csi, 1, 1);

            screen_move_cursor_absolute(context->current, row, column);

            break;
        }
        case ANSI_CSI_VPA: {
            int row = csi_parameter(csi, 0, 1);
            int column = screen_cursor(context->current)->column + 1;

            screen_move_cursor_absolute(context->current, row, column);

            break;
        }
        case ANSI_CSI_ED: {
            int mode = csi_parameter(csi, 0, 0);

            screen_erase(context->current, mode);

            break;
        }
        case ANSI_CSI_EL: {
            int mode = csi_parameter(csi, 0, 0);

            screen_erase_line(context->current, mode);

            break;
        }
        case ANSI_CSI_ECH: {
            int value = csi_parameter(csi, 0, 1);

            screen_erase_inline(context->current, value);

            break;
        }
        case ANSI_CSI_ICH: {
            int value = csi_parameter(csi, 0, 1);

            screen_insert_inline(context->current, value);

            break;
        }
        case ANSI_CSI_DCH: {
            int value = csi_parameter(csi, 0, 1);

            screen_delete_inline(context->current, value);

            break;
        }
        case ANSI_CSI_IL: {
            int value = csi_parameter(csi, 0, 1);

            screen_insert_line(context->current, value);

            break;
        }
        case ANSI_CSI_DL: {
            int value = csi_parameter(csi, 0, 1);

            screen_delete_line(context->current, value);

            break;
        }
        case ANSI_CSI_SU: {
            int value = csi_parameter(csi, 0, 1);

            screen_scroll_up(context->current, value);

            break;
        }
        case ANSI_CSI_SD: {
            int value = csi_parameter(csi, 0, 1);

            screen_scroll_down(context->current, value);

            break;
        }
        case ANSI_CSI_SGR:
            screen_set_attributes(context->current, &csi->attributes);

            break;
        case ANSI_CSI_SM:
            switch (csi->mode) {
                case ANSI_MODE_INSERT:
                    screen_set_insert_mode(context->current, true);

                    break;
                case ANSI_MODE_NEW_LINE:
                    screen_set_new_line_mode(context->current, true);

                    break;
                case ANSI_MODE_UNKNOWN:
                    break;
            }

            break;
        case ANSI_CSI_RM:
            switch (csi->mode) {
                case ANSI_MODE_INSERT:
                    screen_set_insert_mode(context->current, false);

                    break;
                case ANSI_MODE_NEW_LINE:
                    screen_set_new_line_mode(context->current, false);

                    break;
                case ANSI_MODE_UNKNOWN:
                    break;
            }

            break;
        case ANSI_CSI_DSR:
        case ANSI_CSI_DECDSR:
            if (context->on_response) {
                int value = csi_parameter(csi, 0, 0);

                switch (value) {
                    case 5:
                        if (csi->dec_private) break;

                        context->on_response(context->response_user_data, "\x1b[0n");

                        break;
                    case 6: {
                        screen_cursor_t *cursor = screen_cursor(context->current);
                        int row = cursor->row + 1;
                        int column = cursor->column + 1;
                        char buffer[32];

                        snprintf(buffer, sizeof(buffer), "\x1b[%d;%dR", row, column);
                        context->on_response(context->response_user_data, buffer);

                        break;
                    }
                }
            }

            break;
        case ANSI_CSI_DA:
            if (context->on_response) {
                if (csi->intermediates_count > 0 && csi->intermediates[0] == '>') {
                    context->on_response(context->response_user_data, "\x1b[>0;0;0c");
                } else {
                    context->on_response(context->response_user_data, "\x1b[?1;2c");
                }
            }

            break;
        case ANSI_CSI_REP: {
            int value = csi_parameter(csi, 0, 1);

            if (context->last_codepoint != 0) {
                for (int i = 0; i < value; i++) write_codepoint(context, context->last_codepoint);
            }

            break;
        }
        case ANSI_CSI_TBC: {
            int mode = csi_parameter(csi, 0, 0);

            screen_clear_tab_stops(context->current, mode);

            break;
        }
        case ANSI_CSI_SCP:
            screen_save_cursor(context->current);

            break;
        case ANSI_CSI_RCP:
            screen_restore_cursor(context->current);

            break;
        case ANSI_CSI_DECSTBM: {
            int top = csi_parameter(csi, 0, 1);
            int bottom = csi_parameter(csi, 1, screen_rows(context->current));

            screen_set_scroll_area(context->current, top, bottom);

            break;
        }
        case ANSI_CSI_DECSET:
            switch (csi->dec_mode) {
                case ANSI_DEC_MODE_CURSOR_KEYS:
                    context->cursor_keys = true;

                    break;
                case ANSI_DEC_MODE_ORIGIN:
                    screen_set_origin_mode(context->current, true);

                    break;
                case ANSI_DEC_MODE_AUTO_WRAP:
                    screen_set_auto_wrap(context->current, true);

                    break;
                case ANSI_DEC_MODE_CURSOR_BLINK:
                    screen_cursor(context->current)->blink = true;

                    break;
                case ANSI_DEC_MODE_CURSOR_VISIBLE:
                    screen_cursor(context->current)->visible = true;

                    break;
                case ANSI_DEC_MODE_NEW_LINE:
                    screen_set_new_line_mode(context->current, true);

                    break;
                case ANSI_DEC_MODE_MOUSE_X10:
                    context->mouse_mode = SCREEN_CONTEXT_MOUSE_X10;

                    if (context->on_mouse) context->on_mouse(context->mouse_user_data, true);

                    break;
                case ANSI_DEC_MODE_MOUSE_NORMAL:
                    context->mouse_mode = SCREEN_CONTEXT_MOUSE_NORMAL;

                    if (context->on_mouse) context->on_mouse(context->mouse_user_data, true);

                    break;
                case ANSI_DEC_MODE_MOUSE_ALL:
                    context->mouse_mode = SCREEN_CONTEXT_MOUSE_ALL;

                    if (context->on_mouse) context->on_mouse(context->mouse_user_data, true);

                    break;
                case ANSI_DEC_MODE_FOCUS_REPORTING:
                    context->focus_reporting = true;

                    break;
                case ANSI_DEC_MODE_MOUSE_SGR:
                    context->mouse_sgr = true;

                    break;
                case ANSI_DEC_MODE_ALTERNATE_SCREEN:
                case ANSI_DEC_MODE_ALTERNATE_SCREEN_SAVE_CURSOR:
                    if (!context->alternate) {
                        context->alternate = init_screen(screen_rows(context->main), screen_columns(context->main));
                        screen_set_scrollback_capacity(context->alternate, 0);
                        screen_needs_display(context->alternate);
                    }

                    if (csi->dec_mode == ANSI_DEC_MODE_ALTERNATE_SCREEN_SAVE_CURSOR) screen_save_cursor(context->main);

                    context->current = context->alternate;

                    break;
                case ANSI_DEC_MODE_SAVE_CURSOR:
                    screen_save_cursor(context->current);

                    break;
                case ANSI_DEC_MODE_BRACKETED_PASTE:
                    context->bracketed_paste = true;

                    break;
                case ANSI_DEC_MODE_UNKNOWN:
                    break;
            }

            break;
        case ANSI_CSI_DECRST:
            switch (csi->dec_mode) {
                case ANSI_DEC_MODE_CURSOR_KEYS:
                    context->cursor_keys = false;

                    break;
                case ANSI_DEC_MODE_ORIGIN:
                    screen_set_origin_mode(context->current, false);

                    break;
                case ANSI_DEC_MODE_AUTO_WRAP:
                    screen_set_auto_wrap(context->current, false);

                    break;
                case ANSI_DEC_MODE_CURSOR_BLINK:
                    screen_cursor(context->current)->blink = false;

                    break;
                case ANSI_DEC_MODE_CURSOR_VISIBLE:
                    screen_cursor(context->current)->visible = false;

                    break;
                case ANSI_DEC_MODE_NEW_LINE:
                    screen_set_new_line_mode(context->current, false);

                    break;
                case ANSI_DEC_MODE_MOUSE_X10:
                case ANSI_DEC_MODE_MOUSE_NORMAL:
                case ANSI_DEC_MODE_MOUSE_ALL:
                    context->mouse_mode = SCREEN_CONTEXT_MOUSE_NONE;

                    if (context->on_mouse) context->on_mouse(context->mouse_user_data, false);

                    break;
                case ANSI_DEC_MODE_FOCUS_REPORTING:
                    context->focus_reporting = false;

                    break;
                case ANSI_DEC_MODE_MOUSE_SGR:
                    context->mouse_sgr = false;

                    break;
                case ANSI_DEC_MODE_ALTERNATE_SCREEN:
                case ANSI_DEC_MODE_ALTERNATE_SCREEN_SAVE_CURSOR:
                    if (context->current == context->alternate) {
                        screen_clear(context->alternate);
                        context->current = context->main;
                        screen_needs_display(context->main);

                        if (csi->dec_mode == ANSI_DEC_MODE_ALTERNATE_SCREEN_SAVE_CURSOR) screen_restore_cursor(context->main);
                    }

                    break;
                case ANSI_DEC_MODE_SAVE_CURSOR:
                    screen_restore_cursor(context->current);

                    break;
                case ANSI_DEC_MODE_BRACKETED_PASTE:
                    context->bracketed_paste = false;

                    break;
                case ANSI_DEC_MODE_UNKNOWN:
                    break;
            }

            break;
        case ANSI_CSI_DECSED: {
            int mode = csi_parameter(csi, 0, 0);

            screen_erase(context->current, mode);

            break;
        }
        case ANSI_CSI_DECSEL: {
            int mode = csi_parameter(csi, 0, 0);

            screen_erase_line(context->current, mode);

            break;
        }
        case ANSI_CSI_FCS_IN:
        case ANSI_CSI_FCS_OUT:
            // do nothing

            break;
        case ANSI_CSI_BRP_START:
        case ANSI_CSI_BRP_END:
            // do nothing

            break;
        case ANSI_CSI_KIND_UNKNOWN:
            break;
    }
}

static inline void apply_osc(screen_context_t *context, const ansi_osc_t *osc) {
    if (!osc) return;

    switch (osc->event) {
        case ANSI_OSC_SET_TITLE: {
            if (!osc->payload) break;

            size_t length = strlen(osc->payload);
            char *copy = (char *)malloc(length + 1);

            if (copy) {
                memcpy(copy, osc->payload, length + 1);
                free(context->title);
                context->title = copy;
            } else {
                log_error("malloc failed: %zu", length + 1);
            }

            if (context->on_title) context->on_title(context->title_user_data, osc->payload);

            break;
        }
        case ANSI_OSC_HYPERLINK: {
            if (!osc->payload) {
                screen_clear_link(context->current);

                break;
            }

            const char *semi = strchr(osc->payload, ';');
            const char *uri = semi ? semi + 1 : NULL;

            if (uri && uri[0] != '\0') {
                screen_set_link(context->current, uri);
            } else {
                screen_clear_link(context->current);
            }

            break;
        }
        case ANSI_OSC_CLIPBOARD:
        case ANSI_OSC_KIND_UNKNOWN:
            break;
    }
}

screen_context_t *init_screen_context(void) {
    screen_context_t *context = (screen_context_t *)calloc(1, sizeof(screen_context_t));

    if (!context) {
        log_error("malloc failed: %zu", sizeof(screen_context_t));

        return NULL;
    }

    screen_t *main = init_screen(-1, -1);

    if (!main) {
        free(context);

        return NULL;
    }

    context->main = main;
    context->alternate = NULL;
    context->current = main;
    context->utf_codepoint = unicode_default_codepoint;
    context->bracketed_paste = false;
    context->cursor_keys = false;
    context->mouse_mode = SCREEN_CONTEXT_MOUSE_NONE;
    context->mouse_sgr = false;
    context->focus_reporting = false;
    context->last_codepoint = 0;
    context->title = NULL;
    context->on_title = NULL;
    context->title_user_data = NULL;
    context->on_response = NULL;
    context->response_user_data = NULL;
    context->on_bell = NULL;
    context->bell_user_data = NULL;

    return context;
}

void free_screen_context(screen_context_t *context) {
    if (!context) return;

    free(context->title);
    free_screen(context->alternate);
    free_screen(context->main);
    free(context);
}

void screen_context_reset(screen_context_t *context) {
    context->current = context->main;

    if (context->main) {
        screen_set_auto_wrap(context->main, true);
        screen_set_insert_mode(context->main, false);
        screen_set_new_line_mode(context->main, false);
        screen_set_origin_mode(context->main, false);
    }

    free_screen(context->alternate);
    context->alternate = NULL;
    context->utf_codepoint = unicode_default_codepoint;
    context->bracketed_paste = false;
    context->cursor_keys = false;
    context->mouse_mode = SCREEN_CONTEXT_MOUSE_NONE;
    context->mouse_sgr = false;
    context->focus_reporting = false;
    context->last_codepoint = 0;
    free(context->title);
    context->title = NULL;
}

screen_t *screen_context_current_screen(screen_context_t *context) {
    return context->current;
}

void screen_context_set_grid(screen_context_t *context, int32_t rows, int32_t columns) {
    if (context->main) screen_set_grid(context->main, rows, columns);
    if (context->alternate) screen_set_grid(context->alternate, rows, columns);
}

unicode_codepoint_t screen_context_codepoint(screen_context_t *context) {
    return context->utf_codepoint;
}

void screen_context_set_codepoint(screen_context_t *context, unicode_codepoint_t scalar) {
    context->utf_codepoint = scalar;
}

const char *screen_context_title(screen_context_t *context) {
    return context->title;
}

void screen_context_set_title(screen_context_t *context, const char *title) {
    if (!title) {
        free(context->title);
        context->title = NULL;

        return;
    }

    size_t length = strlen(title);
    char *copy = (char *)malloc(length + 1);

    if (!copy) {
        log_error("malloc failed: %zu", length + 1);

        return;
    }

    memcpy(copy, title, length + 1);
    free(context->title);
    context->title = copy;
}

void screen_context_set_title_callback(screen_context_t *context, screen_context_title_callback_t callback, void *user_data) {
    context->on_title = callback;
    context->title_user_data = user_data;
}

void screen_context_set_response_callback(screen_context_t *context, screen_context_response_callback_t callback, void *user_data) {
    context->on_response = callback;
    context->response_user_data = user_data;
}

void screen_context_set_bell_callback(screen_context_t *context, screen_context_bell_callback_t callback, void *user_data) {
    context->on_bell = callback;
    context->bell_user_data = user_data;
}

void screen_context_set_mouse_callback(screen_context_t *context, screen_context_mouse_callback_t callback, void *user_data) {
    context->on_mouse = callback;
    context->mouse_user_data = user_data;
}

void screen_context_update(screen_context_t *context, const ansi_t *ansi) {
    if (!ansi) return;

    switch (ansi->event) {
        case ANSI_EVENT_TEXT:
            apply_text(context, ansi->text.bytes, ansi->text.length);

            break;
        case ANSI_EVENT_ESC:
            apply_esc(context, &ansi->esc);

            break;
        case ANSI_EVENT_CSI:
            apply_csi(context, &ansi->csi);

            break;
        case ANSI_EVENT_OSC:
            apply_osc(context, &ansi->osc);

            break;
        case ANSI_EVENT_BELL:
            if (context->on_bell) context->on_bell(context->bell_user_data);

            break;
        case ANSI_EVENT_UNKNOWN:
            break;
    }

    if (context->current && screen_viewport_offset(context->current) != 0) screen_set_viewport_offset(context->current, 0);
}

void screen_context_scroll(screen_context_t *context, int32_t delta) {
    if (!context->current) return;

    screen_viewport_scroll(context->current, delta);
}

bool screen_context_bracketed_paste(screen_context_t *context) {
    return context->bracketed_paste;
}

bool screen_context_cursor_keys(screen_context_t *context) {
    return context->cursor_keys;
}

screen_context_mouse_mode_t screen_context_mouse_mode(screen_context_t *context) {
    return context->mouse_mode;
}

bool screen_context_mouse_sgr(screen_context_t *context) {
    return context->mouse_sgr;
}

bool screen_context_focus_reporting(screen_context_t *context) {
    return context->focus_reporting;
}
