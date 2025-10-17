//
//  ansi.c
//  o1
//
//  Created by gpt-5-high on 2025-10-12.
//

#include "ansi.h"

#include <stdint.h>

#define ANSI_BITWISE_MASK 0xFF000000u
#define ANSI_BITWISE_INDEXED 0x01000000u
#define ANSI_BITWISE_RGB 0x02000000u

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
