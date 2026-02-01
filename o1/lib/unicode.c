//
//  unicode.c
//  o1
//
//  Created by gpt-5.1-high on 2025-11-16.
//

#include "unicode.h"

#include "include.h"

#include <ctype.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

#ifdef __APPLE__

#include <dispatch/dispatch.h>
#include <locale.h>

static dispatch_once_t once;

static void localize(void) {
    dispatch_once(&once, ^{
        const char *locale = setlocale(LC_CTYPE, "");

        if (!locale || strcmp(locale, "C") == 0 || strcmp(locale, "POSIX") == 0) {
            if (!setlocale(LC_CTYPE, "C.UTF-8")) log_error("setlocale error: %d", errno);
        }
    });
}

#else

#include <locale.h>
#include <pthread.h>

static pthread_once_t _1 = PTHREAD_ONCE_INIT;

static void assert_locale(void) {
    const char *locale = setlocale(LC_CTYPE, "");

    if (!locale || strcmp(locale, "C") == 0 || strcmp(locale, "POSIX") == 0) {
        if (!setlocale(LC_CTYPE, "C.UTF-8")) log_error("setlocale error: %d", errno);
    }
}

static void localize(void) {
    (void)pthread_once(&_1, assert_locale);
}

#endif

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

static inline bool invalid(uint32_t codepoint) {
    if (codepoint > 0x10FFFFu) return true;
    if (codepoint >= 0xD800u && codepoint <= 0xDFFFu) return true;

    return false;
}

int unicode_codepoint_width(uint32_t codepoint) {
    if (codepoint == 0) return 0;
    if (codepoint < 0x0020u) return 0;
    if (codepoint < 0x007Fu) return 1;
    if (codepoint < 0x00A0u) return 0;
    if (zero_width(codepoint)) return 0;
    if (invalid(codepoint)) return 1;

    localize();

    int width = wcwidth((wchar_t)codepoint);

    if (width < 0) return 1;
    if (width > 2) return 2;

    return width;
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
