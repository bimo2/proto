//
//  screen_manager.c
//  o1
//
//  Created by gpt-5-high on 2025-10-16.
//

#include "screen_manager.h"
#include "ansi.h"
#include "screen.h"

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

struct screen_manager_t {
    screen_t *screen;
    uint32_t last_codepoint;
};

static inline void apply_text(screen_manager_t *manager, const uint8_t *text, size_t length) {
    if (!text || length == 0) return;

    for (size_t i = 0; i < length; i++) screen_write_utf32(manager->screen, text[i]);

    manager->last_codepoint = text[length - 1];
}

static inline void apply_esc(screen_manager_t *manager, const ansi_esc_t *esc) {
    if (!esc) return;

    switch (esc->event) {
        case ANSI_ESC_DEC_SAVE_CURSOR:
            screen_save_cursor(manager->screen);

            break;
        case ANSI_ESC_DEC_RESTORE_CURSOR:
            screen_restore_cursor(manager->screen);

            break;
        case ANSI_ESC_TAB_SET:
            screen_tab(manager->screen);

            break;
        case ANSI_ESC_IND:
            screen_scroll_up(manager->screen, 1);

            break;
        case ANSI_ESC_RI:
            screen_scroll_down(manager->screen, 1);

            break;
        case ANSI_ESC_RESET:
            screen_clear(manager->screen);
            screen_set_attributes(manager->screen, NULL);
            screen_set_auto_wrap(manager->screen, true);
            screen_set_insert_mode(manager->screen, false);
            screen_set_origin_mode(manager->screen, false);
            screen_set_cursor_position(manager->screen, 0, 0);
            screen_set_scroll_area(manager->screen, 1, screen_rows(manager->screen));

            break;
    }
}

static inline int csi_parameter(const ansi_csi_t *csi, size_t index, int fallback) {
    if (index >= csi->parameters_count) return fallback;

    return (csi->parameters[index] < 0) ? fallback : csi->parameters[index];
}


static inline void apply_csi(screen_manager_t *manager, const ansi_csi_t *csi) {
    if (!csi) return;

    switch (csi->event) {
        case ANSI_CSI_CUU: {
            int value = csi_parameter(csi, 0, 1);

            screen_move_cursor_relative(manager->screen, -value, 0);

            break;
        }
        case ANSI_CSI_CUD: {
            int value = csi_parameter(csi, 0, 1);

            screen_move_cursor_relative(manager->screen, value, 0);

            break;
        }
        case ANSI_CSI_CUF: {
            int value = csi_parameter(csi, 0, 1);

            screen_move_cursor_relative(manager->screen, 0, value);

            break;
        }
        case ANSI_CSI_CUB: {
            int value = csi_parameter(csi, 0, 1);

            screen_move_cursor_relative(manager->screen, 0, -value);

            break;
        }
        case ANSI_CSI_CNL: {
            int value = csi_parameter(csi, 0, 1);

            for (int i = 0; i < value; i++) screen_newline(manager->screen);

            break;
        }
        case ANSI_CSI_CPL: {
            int value = csi_parameter(csi, 0, 1);

            screen_move_cursor_relative(manager->screen, -value, 0);
            screen_carriage_return(manager->screen);

            break;
        }
        case ANSI_CSI_CHA: {
            int column = csi_parameter(csi, 0, 1);

            screen_move_cursor_absolute(manager->screen, screen_cursor(manager->screen)->row + 1, column);

            break;
        }
        case ANSI_CSI_CUP:
        case ANSI_CSI_HVP: {
            int row = csi_parameter(csi, 0, 1);
            int column = csi_parameter(csi, 1, 1);

            screen_move_cursor_absolute(manager->screen, row, column);

            break;
        }
        case ANSI_CSI_ED: {
            int mode = csi_parameter(csi, 0, 0);

            screen_erase(manager->screen, mode);

            break;
        }
        case ANSI_CSI_EL: {
            int mode = csi_parameter(csi, 0, 0);

            screen_erase_line(manager->screen, mode);

            break;
        }
        case ANSI_CSI_DECSED: {
            int mode = csi_parameter(csi, 0, 0);

            screen_erase(manager->screen, mode);

            break;
        }
        case ANSI_CSI_DECSEL: {
            int mode = csi_parameter(csi, 0, 0);

            screen_erase_line(manager->screen, mode);

            break;
        }
        case ANSI_CSI_SU: {
            int value = csi_parameter(csi, 0, 1);

            screen_scroll_up(manager->screen, value);

            break;
        }
        case ANSI_CSI_SD: {
            int value = csi_parameter(csi, 0, 1);

            screen_scroll_down(manager->screen, value);

            break;
        }
        case ANSI_CSI_DECSTBM: {
            int top = csi_parameter(csi, 0, 1);
            int bottom = csi_parameter(csi, 1, screen_rows(manager->screen));

            screen_set_scroll_area(manager->screen, top, bottom);

            break;
        }
        case ANSI_CSI_SGR: {
            screen_set_attributes(manager->screen, &csi->attributes);

            break;
        }
        case ANSI_CSI_SM: {
            if (csi->mode == ANSI_MODE_INSERT) screen_set_insert_mode(manager->screen, true);

            break;
        }
        case ANSI_CSI_RM: {
            if (csi->mode == ANSI_MODE_INSERT) screen_set_insert_mode(manager->screen, false);

            break;
        }
        case ANSI_CSI_DECSET: {
            switch (csi->dec_mode) {
                case ANSI_DEC_MODE_ORIGIN:
                    screen_set_origin_mode(manager->screen, true);

                    break;
                case ANSI_DEC_MODE_AUTO_WRAP:
                    screen_set_auto_wrap(manager->screen, true);

                    break;
                case ANSI_DEC_MODE_CURSOR_VISIBLE: {
                    screen_cursor(manager->screen)->visible = true;

                    break;
                }
                case ANSI_DEC_MODE_CURSOR_BLINK: {
                    screen_cursor(manager->screen)->blink = true;

                    break;
                }
                default:
                    break;
            }

            break;
        }
        case ANSI_CSI_DECRST: {
            switch (csi->dec_mode) {
                case ANSI_DEC_MODE_ORIGIN:
                    screen_set_origin_mode(manager->screen, false);

                    break;
                case ANSI_DEC_MODE_AUTO_WRAP:
                    screen_set_auto_wrap(manager->screen, false);

                    break;
                case ANSI_DEC_MODE_CURSOR_VISIBLE: {
                    screen_cursor(manager->screen)->visible = false;

                    break;
                }
                case ANSI_DEC_MODE_CURSOR_BLINK: {
                    screen_cursor(manager->screen)->blink = false;

                    break;
                }
                default:
                    break;
            }

            break;
        }
        case ANSI_CSI_DSR:
        case ANSI_CSI_DEC_DSR:
        case ANSI_CSI_DA:
            // TODO

            break;
        case ANSI_CSI_REP: {
            int value = csi_parameter(csi, 0, 1);

            if (manager->last_codepoint != 0) {
                for (int i = 0; i < value; i++)
                    screen_write_utf32(manager->screen, manager->last_codepoint);
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
    // TODO
}

screen_manager_t *init_screen_manager(screen_t *screen) {
    if (!screen) return NULL;

    screen_manager_t *manager = (screen_manager_t *)calloc(1, sizeof(screen_manager_t));

    if (!manager) return NULL;

    manager->screen = screen;
    manager->last_codepoint = 0;

    return manager;
}

void free_screen_manager(screen_manager_t *manager) {
    if (!manager) return;

    free(manager);
}

void screen_manager_set_screen(screen_manager_t *manager, screen_t *screen) {
    if (!screen) return;

    manager->screen = screen;
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
        case ANSI_EVENT_UNKNOWN:
            break;
    }
}
