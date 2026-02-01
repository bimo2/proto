//
//  unicode.h
//  o1
//
//  Created by gpt-5.1-high on 2025-11-16.
//

#ifndef UNICODE_H
#define UNICODE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define UNICODE_REPLACEMENT 0x0020u
#define UNICODE_WIDE_REPLACEMENT 0x3000u

typedef enum unicode_codepoint_t {
    UNICODE_CODEPOINT_DYNAMIC = 0,
    UNICODE_CODEPOINT_UTF8 = 8,
    UNICODE_CODEPOINT_UTF16 = 16,
    UNICODE_CODEPOINT_UTF32 = 32,
} unicode_codepoint_t;

typedef enum unicode_class_t {
    UNICODE_CLASS_SPACE = 0,
    UNICODE_CLASS_WORD,
    UNICODE_CLASS_OTHER,
} unicode_class_t;

extern unicode_codepoint_t unicode_default_codepoint;

int unicode_codepoint_width(uint32_t codepoint);

size_t unicode_decode_utf8(const uint8_t *bytes, size_t length, uint32_t *codepoint);

size_t unicode_encode_utf16(uint32_t codepoint, uint16_t out[2]);

bool unicode_codepoint_supported(uint32_t codepoint, unicode_codepoint_t scalar);

size_t unicode_codepoint_string(uint32_t codepoint, char *buffer, size_t length);

unicode_class_t unicode_class(uint32_t codepoint);

#endif // !UNICODE_H
