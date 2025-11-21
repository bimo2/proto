//
//  ansi.c
//  o1
//
//  Created by gpt-5-high on 2025-10-12.
//

#include "ansi.h"

#include <stdint.h>
#include <stdio.h>

#define ANSI_BITWISE_MASK 0xFF000000u
#define ANSI_BITWISE_INDEXED 0x01000000u
#define ANSI_BITWISE_RGB 0x02000000u

static inline int mouse_modifier_bits(uint16_t flags) {
    int bits = 0;

    if (flags & ANSI_MOUSE_MODIFIER_FLAG_SHIFT) bits |= 4;
    if (flags & ANSI_MOUSE_MODIFIER_FLAG_OPTION) bits |= 8;
    if (flags & ANSI_MOUSE_MODIFIER_FLAG_CONTROL) bits |= 16;

    return bits;
}

static size_t mouse_data(ansi_mouse_t base, ansi_mouse_event_t event, uint16_t flags, uint32_t x, uint32_t y, uint8_t *data, size_t length) {
    if (!data || length < 6) return 0;

    int mods = mouse_modifier_bits(flags);
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

    int mods = mouse_modifier_bits(flags);
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

    if (total < 1 || (size_t)total >= length) return 0;

    return (size_t)total;
}

uint32_t ansi_color_pack_indexed(int index) {
    return ANSI_BITWISE_INDEXED | ((uint32_t)(index) & 0xFFu);
}

uint32_t ansi_color_pack_rgb(uint8_t red, uint8_t green, uint8_t blue) {
    return ANSI_BITWISE_RGB | (((uint32_t)red & 0xFFu) << 16) | (((uint32_t)green & 0xFFu) << 8) | ((uint32_t)blue & 0xFFu);
}

ansi_color_t ansi_color_unpack(uint32_t color, int *index, uint8_t *red, uint8_t *green, uint8_t *blue) {
    if (color == ANSI_COLOR_RESET) return ANSI_COLOR_DEFAULT;

    if ((color & ANSI_BITWISE_MASK) == ANSI_BITWISE_INDEXED) {
        if (index) *index = color & 0xFFu;

        return ANSI_COLOR_INDEXED;
    }

    if ((color & ANSI_BITWISE_MASK) == ANSI_BITWISE_RGB) {
        if (red) *red = (color >> 16) & 0xFFu;
        if (green) *green = (color >> 8) & 0xFFu;
        if (blue) *blue = color & 0xFFu;

        return ANSI_COLOR_RGB;
    }

    return ANSI_COLOR_DEFAULT;
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
