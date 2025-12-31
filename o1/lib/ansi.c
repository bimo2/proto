//
//  ansi.c
//  o1
//
//  Created by gpt-5-high on 2025-10-12.
//

#include "ansi.h"

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define COLOR_BITWISE_MASK 0xFF000000u
#define COLOR_BITWISE_INDEXED 0x01000000u
#define COLOR_BITWISE_RGB 0x02000000u

static inline size_t keyboard_data(const char *command, uint8_t *data, size_t length) {
    size_t total = strlen(command);

    if (length < total) return 0;

    memcpy(data, command, total);

    return total;
}

static inline size_t keyboard_csi_byte(char final_byte, uint8_t mods, uint8_t *data, size_t length) {
    int total = snprintf((char *)data, length, "\x1b[1;%u%c", (unsigned)mods, final_byte);

    if (total < 1 || (size_t)total > length) return 0;

    return (size_t)total;
}

static inline size_t keyboard_csi_code(uint32_t code, uint8_t mods, uint8_t *data, size_t length) {
    int total;

    if (mods > 1) {
        total = snprintf((char *)data, length, "\x1B[%u;%u~", (unsigned)code, (unsigned)mods);
    } else {
        total = snprintf((char *)data, length, "\x1B[%u~", (unsigned)code);
    }

    if (total < 1 || (size_t)total > length) return 0;

    return (size_t)total;
}

static size_t mouse_data(ansi_mouse_t base, ansi_mouse_event_t event, uint16_t flags, uint32_t x, uint32_t y, uint8_t *data, size_t length) {
    if (!data || length < 6) return 0;

    int mods = 0;

    if (flags & ANSI_MODIFIER_FLAG_SHIFT) mods |= 4;
    if (flags & ANSI_MODIFIER_FLAG_OPTION) mods |= 8;
    if (flags & ANSI_MODIFIER_FLAG_CONTROL) mods |= 16;

    uint8_t cb = 0;

    if (base == ANSI_MOUSE_WHEEL_UP || base == ANSI_MOUSE_WHEEL_DOWN) {
        if (event == ANSI_MOUSE_EVENT_UP) return 0;

        cb = (uint8_t)(base | mods);
    } else {
        switch (event) {
            case ANSI_MOUSE_EVENT_DOWN:
                cb = (uint8_t)(base | mods);

                break;
            case ANSI_MOUSE_EVENT_UP:
                cb = (uint8_t)(3 | mods);

                break;
            case ANSI_MOUSE_EVENT_DRAG:
                cb = (uint8_t)(base | 32 | mods);

                break;
            case ANSI_MOUSE_EVENT_MOVE:
                cb = (uint8_t)(3 | 32 | mods);

                break;
        }
    }

    uint8_t cx = (uint8_t)(x + 32);
    uint8_t cy = (uint8_t)(y + 32);
    size_t i = 0;

    data[i++] = 0x1Bu;
    data[i++] = '[';
    data[i++] = 'M';
    data[i++] = cb;
    data[i++] = cx;
    data[i++] = cy;

    return i;
}

static size_t mouse_data_sgr(ansi_mouse_t base, ansi_mouse_event_t event, uint16_t flags, uint32_t x, uint32_t y, uint8_t *data, size_t length) {
    if (!data) return 0;

    int mods = 0;

    if (flags & ANSI_MODIFIER_FLAG_SHIFT) mods |= 4;
    if (flags & ANSI_MODIFIER_FLAG_OPTION) mods |= 8;
    if (flags & ANSI_MODIFIER_FLAG_CONTROL) mods |= 16;

    int b = base | mods;
    char end = 'M';

    if ((base == ANSI_MOUSE_WHEEL_UP || base == ANSI_MOUSE_WHEEL_DOWN) && event == ANSI_MOUSE_EVENT_UP) return 0;

    switch (event) {
        case ANSI_MOUSE_EVENT_DOWN:
            end = 'M';

            break;
        case ANSI_MOUSE_EVENT_UP:
            b = 3 | mods;
            end = 'm';

            break;
        case ANSI_MOUSE_EVENT_DRAG:
            b |= 32;
            end = 'M';

            break;
        case ANSI_MOUSE_EVENT_MOVE:
            b = (3 | 32 | mods);
            end = 'M';

            break;
    }

    int total = snprintf((char *)data, length, "\x1b[<%d;%d;%d%c", b, x, y, end);

    if (total < 1 || (size_t)total > length) return 0;

    return (size_t)total;
}

uint32_t ansi_color_pack_indexed(int index) {
    return COLOR_BITWISE_INDEXED | ((uint32_t)(index) & 0xFFu);
}

uint32_t ansi_color_pack_rgb(uint8_t red, uint8_t green, uint8_t blue) {
    return COLOR_BITWISE_RGB | (((uint32_t)red & 0xFFu) << 16) | (((uint32_t)green & 0xFFu) << 8) | ((uint32_t)blue & 0xFFu);
}

ansi_color_t ansi_color_unpack(uint32_t color, int *index, uint8_t *red, uint8_t *green, uint8_t *blue) {
    if (color == ANSI_COLOR_UNSET || color == ANSI_COLOR_RESET) return ANSI_COLOR_DEFAULT;

    if ((color & COLOR_BITWISE_MASK) == COLOR_BITWISE_INDEXED) {
        if (index) *index = color & 0xFFu;

        return ANSI_COLOR_INDEXED;
    }

    if ((color & COLOR_BITWISE_MASK) == COLOR_BITWISE_RGB) {
        if (red) *red = (color >> 16) & 0xFFu;
        if (green) *green = (color >> 8) & 0xFFu;
        if (blue) *blue = color & 0xFFu;

        return ANSI_COLOR_RGB;
    }

    return ANSI_COLOR_DEFAULT;
}

bool ansi_control(unsigned short code, uint8_t *byte) {
    if (code == ' ' || code == '@') {
        *byte = 0x00u;
    } else if (code >= 'a' && code <= 'z') {
        *byte = (uint8_t)(code - 'a' + 1);
    } else if (code >= 'A' && code <= 'Z') {
        *byte = (uint8_t)(code - 'A' + 1);
    } else {
        switch (code) {
            case '[':
                *byte = 0x1Bu;

                break;
            case '\\':
                *byte = 0x1Cu;

                break;
            case ']':
                *byte = 0x1Du;

                break;
            case '^':
                *byte = 0x1Eu;

                break;
            case '_':
                *byte = 0x1Fu;

                break;
            case '?':
                *byte = 0x7Fu;

                break;
            default:
                return false;
        }
    }

    return true;
}

size_t ansi_keyboard(ansi_keyboard_t value, uint16_t flags, bool cursor, uint8_t *data, size_t length) {
    if (!data) return 0;

    uint8_t mods = 1;

    if (flags & ANSI_MODIFIER_FLAG_SHIFT) mods += 1;
    if (flags & ANSI_MODIFIER_FLAG_OPTION) mods += 2;
    if (flags & ANSI_MODIFIER_FLAG_CONTROL) mods += 4;

    switch (value) {
        case ANSI_KEYBOARD_ESCAPE:
            data[0] = 0x1Bu;

            return 1;
        case ANSI_KEYBOARD_ENTER:
            data[0] = '\r';

            return 1;
        case ANSI_KEYBOARD_TAB:
            data[0] = '\t';

            return 1;
        case ANSI_KEYBOARD_BACKTAB:
            return keyboard_data("\x1b[Z", data, length);
        case ANSI_KEYBOARD_BACKSPACE:
            data[0] = 0x7Fu;

            return 1;
        case ANSI_KEYBOARD_DELETE:
            return keyboard_csi_code(3, mods, data, length);
        case ANSI_KEYBOARD_INSERT:
            return keyboard_csi_code(2, mods, data, length);
        case ANSI_KEYBOARD_UP:
            if (mods > 1) return keyboard_csi_byte('A', mods, data, length);

            if (cursor) {
                return keyboard_data("\x1bOA", data, length);
            } else {
                return keyboard_data("\x1b[A", data, length);
            }
        case ANSI_KEYBOARD_DOWN:
            if (mods > 1) return keyboard_csi_byte('B', mods, data, length);

            if (cursor) {
                return keyboard_data("\x1bOB", data, length);
            } else {
                return keyboard_data("\x1b[B", data, length);
            }
        case ANSI_KEYBOARD_LEFT:
            if (mods > 1) return keyboard_csi_byte('D', mods, data, length);

            if (cursor) {
                return keyboard_data("\x1bOD", data, length);
            } else {
                return keyboard_data("\x1b[D", data, length);
            }
        case ANSI_KEYBOARD_RIGHT:
            if (mods > 1) return keyboard_csi_byte('C', mods, data, length);

            if (cursor) {
                return keyboard_data("\x1bOC", data, length);
            } else {
                return keyboard_data("\x1b[C", data, length);
            }
        case ANSI_KEYBOARD_HOME:
            if (mods > 1) return keyboard_csi_byte('H', mods, data, length);

            if (cursor) {
                return keyboard_data("\x1bOH", data, length);
            } else {
                return keyboard_data("\x1b[H", data, length);
            }
        case ANSI_KEYBOARD_END:
            if (mods > 1) return keyboard_csi_byte('F', mods, data, length);

            if (cursor) {
                return keyboard_data("\x1bOF", data, length);
            } else {
                return keyboard_data("\x1b[F", data, length);
            }
        case ANSI_KEYBOARD_PAGE_UP:
            return keyboard_csi_code(5, mods, data, length);
        case ANSI_KEYBOARD_PAGE_DOWN:
            return keyboard_csi_code(6, mods, data, length);
        case ANSI_KEYBOARD_F1:
            return keyboard_data("\x1bOP", data, length);
        case ANSI_KEYBOARD_F2:
            return keyboard_data("\x1bOQ", data, length);
        case ANSI_KEYBOARD_F3:
            return keyboard_data("\x1bOR", data, length);
        case ANSI_KEYBOARD_F4:
            return keyboard_data("\x1bOS", data, length);
        case ANSI_KEYBOARD_F5:
            return keyboard_data("\x1b[15~", data, length);
        case ANSI_KEYBOARD_F6:
            return keyboard_data("\x1b[17~", data, length);
        case ANSI_KEYBOARD_F7:
            return keyboard_data("\x1b[18~", data, length);
        case ANSI_KEYBOARD_F8:
            return keyboard_data("\x1b[19~", data, length);
        case ANSI_KEYBOARD_F9:
            return keyboard_data("\x1b[20~", data, length);
        case ANSI_KEYBOARD_F10:
            return keyboard_data("\x1b[21~", data, length);
        case ANSI_KEYBOARD_F11:
            return keyboard_data("\x1b[23~", data, length);
        case ANSI_KEYBOARD_F12:
            return keyboard_data("\x1b[24~", data, length);
    }

    return 0;
}

size_t ansi_mouse_x10(ansi_mouse_t base, ansi_mouse_event_t event, uint16_t flags, uint32_t x, uint32_t y, bool sgr, uint8_t *data, size_t length) {
    if (event != ANSI_MOUSE_EVENT_DOWN) return 0;
    if (sgr) return mouse_data_sgr(base, event, flags, x, y, data, length);

    return mouse_data(base, event, flags, x, y, data, length);
}

size_t ansi_mouse_normal(ansi_mouse_t base, ansi_mouse_event_t event, uint16_t flags, uint32_t x, uint32_t y, bool sgr, uint8_t *data, size_t length) {
    if (event == ANSI_MOUSE_EVENT_MOVE) return 0;
    if (sgr) return mouse_data_sgr(base, event, flags, x, y, data, length);

    return mouse_data(base, event, flags, x, y, data, length);
}

size_t ansi_mouse_all(ansi_mouse_t base, ansi_mouse_event_t event, uint16_t flags, uint32_t x, uint32_t y, bool sgr, uint8_t *data, size_t length) {
    if (sgr) return mouse_data_sgr(base, event, flags, x, y, data, length);

    return mouse_data(base, event, flags, x, y, data, length);
}
