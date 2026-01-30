//
//  unicode.c
//  o1
//
//  Created by gpt-5.1-high on 2025-11-16.
//

#include "unicode.h"

#include <ctype.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

unicode_codepoint_t unicode_default_codepoint = UNICODE_CODEPOINT_UTF16;

static inline bool range(uint32_t codepoint, uint32_t low, uint32_t high) {
    return codepoint >= low && codepoint <= high;
}

static inline bool zero_width(uint32_t codepoint) {
    if (range(codepoint, 0x0300u, 0x036Fu)) return true;
    if (range(codepoint, 0x1AB0u, 0x1AFFu)) return true;
    if (range(codepoint, 0x1DC0u, 0x1DFFu)) return true;
    if (codepoint == 0x200Du) return true;
    if (range(codepoint, 0x20D0u, 0x20FFu)) return true;
    if (codepoint == 0xFE0Eu) return true;
    if (codepoint == 0xFE0Fu) return true;
    if (range(codepoint, 0xFE20u, 0xFE2Fu)) return true;
    if (range(codepoint, 0xE0100u, 0xE01EFu)) return true;

    return false;
}

static inline bool wide_east_asian(uint32_t codepoint) {
    if (range(codepoint, 0x1100u, 0x115Fu)) return true;
    if (codepoint == 0x2329u) return true;
    if (codepoint == 0x232Au) return true;
    if (range(codepoint, 0x2E80u, 0x2FFBu)) return true;
    if (range(codepoint, 0x3040u, 0x30FFu)) return true;
    if (range(codepoint, 0x3100u, 0x312Fu)) return true;
    if (range(codepoint, 0x3130u, 0x318Fu)) return true;
    if (range(codepoint, 0x3190u, 0x31FFu)) return true;
    if (range(codepoint, 0x3200u, 0x32FEu)) return true;
    if (range(codepoint, 0x3300u, 0x4DBFu)) return true;
    if (range(codepoint, 0x4E00u, 0xA4C6u)) return true;
    if (range(codepoint, 0xA960u, 0xA97Cu)) return true;
    if (range(codepoint, 0xAC00u, 0xD7A3u)) return true;
    if (range(codepoint, 0xF900u, 0xFAFFu)) return true;
    if (range(codepoint, 0xFE10u, 0xFE19u)) return true;
    if (range(codepoint, 0xFE30u, 0xFE6Bu)) return true;
    if (range(codepoint, 0xFF01u, 0xFF60u)) return true;
    if (range(codepoint, 0xFFE0u, 0xFFE6u)) return true;

    return false;
}

static inline bool wide_legacy_symbol(uint32_t codepoint) {
    if (range(codepoint, 0x2300u, 0x23F3u)) return true;
    if (range(codepoint, 0x25A0u, 0x25FEu)) return true;
    if (range(codepoint, 0x2600u, 0x26FFu)) return true;
    if (range(codepoint, 0x2700u, 0x27BFu)) return true;
    if (range(codepoint, 0x2B50u, 0x2B55u)) return true;

    return false;
}

static inline bool emoji(uint32_t codepoint) {
    return range(codepoint, 0x1F000u, 0x1FAFFu);
}

int unicode_codepoint_width(uint32_t codepoint) {
    if (codepoint == 0) return 0;
    if (codepoint < 0x0020u) return 0;
    if (codepoint < 0x007Fu) return 1;
    if (codepoint < 0x00A0u) return 0;
    if (codepoint < 0x0300u) return 1;
    if (zero_width(codepoint)) return 0;
    if (wide_east_asian(codepoint)) return 2;
    if (wide_legacy_symbol(codepoint)) return 2;
    if (emoji(codepoint)) return 2;

    return 1;
}

size_t unicode_decode_utf8(const uint8_t *bytes, size_t length, uint32_t *codepoint) {
    if (!bytes || length < 1) return 0;

    uint8_t lead = bytes[0];

    if (lead <= 0x7Fu) {
        if (codepoint) *codepoint = (uint32_t)lead;

        return 1;
    }

    if (lead >= 0xC2u && lead <= 0xDFu) {
        if (length < 2) return 0;

        uint8_t second = bytes[1];

        if ((second & 0xC0u) != 0x80u) {
            if (codepoint) *codepoint = UNICODE_REPLACEMENT;

            return 1;
        }

        if (codepoint) *codepoint = ((uint32_t)(lead & 0x1Fu) << 6) | (uint32_t)(second & 0x3Fu);

        return 2;
    }

    if (lead >= 0xE0u && lead <= 0xEFu) {
        if (length < 3) return 0;

        uint8_t second = bytes[1];
        uint8_t third = bytes[2];

        if (((second & 0xC0u) != 0x80u) || ((third & 0xC0u) != 0x80u)) {
            if (codepoint) *codepoint = UNICODE_REPLACEMENT;

            return 1;
        }

        if (codepoint) *codepoint = ((uint32_t)(lead & 0x0Fu) << 12) | ((uint32_t)(second & 0x3Fu) << 6) | (uint32_t)(third & 0x3Fu);

        return 3;
    }

    if (lead >= 0xF0u && lead <= 0xF4u) {
        if (length < 4) return 0;

        uint8_t second = bytes[1];
        uint8_t third = bytes[2];
        uint8_t fourth = bytes[3];

        if (((second & 0xC0u) != 0x80u) || ((third & 0xC0u) != 0x80u) || ((fourth & 0xC0u) != 0x80u)) {
            if (codepoint) *codepoint = UNICODE_REPLACEMENT;

            return 1;
        }

        if (codepoint) *codepoint = ((uint32_t)(lead & 0x07u) << 18) | ((uint32_t)(second & 0x3Fu) << 12) | ((uint32_t)(third & 0x3Fu) << 6) | (uint32_t)(fourth & 0x3Fu);

        return 4;
    }

    if (codepoint) *codepoint = UNICODE_REPLACEMENT;

    return 1;
}

size_t unicode_encode_utf16(uint32_t codepoint, uint16_t out[2]) {
    if (!out) return 0;

    uint32_t value = codepoint;

    if (value > 0x10FFFFu) value = UNICODE_REPLACEMENT;
    if (value >= 0xD800u && value <= 0xDFFFu) value = UNICODE_REPLACEMENT;

    if (value <= 0xFFFFu) {
        out[0] = (uint16_t)value;
        out[1] = 0;

        return 1;
    }

    uint32_t shift = value - 0x10000u;

    out[0] = (uint16_t)(0xD800u + ((shift >> 10) & 0x3FFu));
    out[1] = (uint16_t)(0xDC00u + (shift & 0x3FFu));

    return 2;
}

bool unicode_codepoint_supported(uint32_t codepoint, unicode_codepoint_t scalar) {
    if (codepoint == UNICODE_REPLACEMENT) return true;

    switch (scalar) {
        case UNICODE_CODEPOINT_UTF8:
            return codepoint <= 0x7Fu;
        case UNICODE_CODEPOINT_UTF16:
            if (codepoint > 0xFFFFu) return false;

            return !(codepoint >= 0xD800u && codepoint <= 0xDFFFu);
        case UNICODE_CODEPOINT_UTF32:
        case UNICODE_CODEPOINT_DYNAMIC:
            if (codepoint > 0x10FFFFu) return false;

            return !(codepoint >= 0xD800u && codepoint <= 0xDFFFu);
    }
}

size_t unicode_codepoint_string(uint32_t codepoint, char *buffer, size_t length) {
    if (!buffer || length == 0) return 0;

    uint32_t value = codepoint;

    if (value > 0x10FFFFu) value = 0x10FFFFu;

    int total = snprintf(buffer, length, "U+%X", value);

    if (total < 0) return 0;
    if ((size_t)total >= length) return length - 1;

    return (size_t)total;
}

unicode_class_t unicode_class(uint32_t codepoint) {
    if (codepoint == 0 || codepoint == ' ' || codepoint == '\t') return UNICODE_CLASS_SPACE;

    if (codepoint <= 0x7Fu) {
        uint8_t byte = (uint8_t)codepoint;

        if (isalnum(byte) || byte == '_') return UNICODE_CLASS_WORD;

        return UNICODE_CLASS_OTHER;
    }

    return UNICODE_CLASS_WORD;
}
