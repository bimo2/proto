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

#define UNICODE_REPLACEMENT 0xFFFDu

typedef enum unicode_codepoint_t {
    UNICODE_CODEPOINT_DYNAMIC = 0,
    UNICODE_CODEPOINT_UTF8 = 8,
    UNICODE_CODEPOINT_UTF16 = 16,
    UNICODE_CODEPOINT_UTF32 = 32,
} unicode_codepoint_t;

extern unicode_codepoint_t unicode_default_codepoint;

int unicode_codepoint_width(uint32_t codepoint);

size_t unicode_decode_utf8(const uint8_t *bytes, size_t length, uint32_t *codepoint);

bool unicode_codepoint_supported(uint32_t codepoint, unicode_codepoint_t scalar);

size_t unicode_codepoint_string(uint32_t codepoint, char *buffer, size_t length);

#endif // !UNICODE_H
