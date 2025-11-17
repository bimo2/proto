//
//  unicode.c
//  o1
//
//  Created by gpt-5-high on 2025-11-16.
//

#include "unicode.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

static inline bool in(uint32_t codepoint, uint32_t low, uint32_t high) {
    return codepoint >= low && codepoint <= high;
}

static inline bool zero_width(uint32_t codepoint) {
    if (in(codepoint, 0x0300, 0x036F)) return true;
    if (in(codepoint, 0x1AB0, 0x1AFF)) return true;
    if (in(codepoint, 0x1DC0, 0x1DFF)) return true;
    if (in(codepoint, 0x20D0, 0x20FF)) return true;
    if (in(codepoint, 0xFE20, 0xFE2F)) return true;
    if (in(codepoint, 0xE0100, 0xE01EF)) return true;
    if (codepoint == 0x200D || codepoint == 0xFE0E || codepoint == 0xFE0F) return true;

    return false;
}

static inline bool wide_east_asian(uint32_t codepoint) {
    if (in(codepoint, 0x1100, 0x115F)) return true;
    if (in(codepoint, 0x2E80, 0x2FFB)) return true;
    if (in(codepoint, 0x3040, 0x30FF)) return true;
    if (in(codepoint, 0x3100, 0x312F)) return true;
    if (in(codepoint, 0x3130, 0x318F)) return true;
    if (in(codepoint, 0x3190, 0x31FF)) return true;
    if (in(codepoint, 0x3200, 0x32FE)) return true;
    if (in(codepoint, 0x3300, 0x4DBF)) return true;
    if (in(codepoint, 0x4E00, 0xA4C6)) return true;
    if (in(codepoint, 0xA960, 0xA97C)) return true;
    if (in(codepoint, 0xAC00, 0xD7A3)) return true;
    if (in(codepoint, 0xF900, 0xFAFF)) return true;
    if (in(codepoint, 0xFE10, 0xFE19)) return true;
    if (in(codepoint, 0xFE30, 0xFE6B)) return true;
    if (in(codepoint, 0xFF01, 0xFF60)) return true;
    if (in(codepoint, 0xFFE0, 0xFFE6)) return true;
    if (codepoint == 0x2329 || codepoint == 0x232A) return true;

    return false;
}

static inline bool wide_legacy_symbol(uint32_t codepoint) {
    if (in(codepoint, 0x2300, 0x23F3)) return true;
    if (in(codepoint, 0x25A0, 0x25FE)) return true;
    if (in(codepoint, 0x2600, 0x26FF)) return true;
    if (in(codepoint, 0x2700, 0x27BF)) return true;
    if (in(codepoint, 0x2B50, 0x2B55)) return true;
    if (in(codepoint, 0x2500, 0x259F)) return true;

    return false;
}

int unicode_codepoint_width(uint32_t codepoint) {
    if (codepoint == 0) return 0;
    if (codepoint < 0x20) return 0;
    if (codepoint < 0x7F) return 1;
    if (codepoint < 0xA0) return 0;
    if (codepoint < 0x0300) return 1;
    if (zero_width(codepoint)) return 0;
    if (wide_east_asian(codepoint)) return 2;
    if (wide_legacy_symbol(codepoint)) return 2;

    return 1;
}

size_t unicode_decode_utf8(const uint8_t *bytes, size_t length, uint32_t *codepoint) {
    if (!bytes || length < 1) return 0;

    uint8_t lead = bytes[0];

    if (lead <= 0x7F) {
        if (codepoint) *codepoint = (uint32_t)lead;

        return 1;
    }

    if (lead >= 0xC2 && lead <= 0xDF) {
        if (length < 2) return 0;

        uint8_t second = bytes[1];

        if ((second & 0xC0) != 0x80) {
            if (codepoint) *codepoint = UNICODE_REPLACEMENT;

            return 1;
        }

        if (codepoint) *codepoint = ((uint32_t)(lead & 0x1F) << 6) | (uint32_t)(second & 0x3F);

        return 2;
    }

    if (lead >= 0xE0 && lead <= 0xEF) {
        if (length < 3) return 0;

        uint8_t second = bytes[1];
        uint8_t third = bytes[2];

        if (((second & 0xC0) != 0x80) || ((third & 0xC0) != 0x80)) {
            if (codepoint) *codepoint = UNICODE_REPLACEMENT;

            return 1;
        }

        if (codepoint) *codepoint = ((uint32_t)(lead & 0x0F) << 12) | ((uint32_t)(second & 0x3F) << 6) | (uint32_t)(third & 0x3F);

        return 3;
    }

    if (lead >= 0xF0 && lead <= 0xF4) {
        if (length < 4) return 0;

        uint8_t second = bytes[1];
        uint8_t third = bytes[2];
        uint8_t fourth = bytes[3];

        if (((second & 0xC0) != 0x80) || ((third & 0xC0) != 0x80) || ((fourth & 0xC0) != 0x80)) {
            if (codepoint) *codepoint = UNICODE_REPLACEMENT;

            return 1;
        }

        if (codepoint) *codepoint = ((uint32_t)(lead & 0x07) << 18) | ((uint32_t)(second & 0x3F) << 12) | ((uint32_t)(third & 0x3F) << 6) | (uint32_t)(fourth & 0x3F);

        return 4;
    }

    if (codepoint) *codepoint = UNICODE_REPLACEMENT;

    return 1;
}
