//
//  unicode.h
//  o1
//
//  Created by gpt-5-high on 2025-11-16.
//

#ifndef UNICODE_H
#define UNICODE_H

#include <stddef.h>
#include <stdint.h>

#define UNICODE_REPLACEMENT 0xFFFD

int unicode_codepoint_width(uint32_t codepoint);

size_t unicode_decode_utf8(const uint8_t *bytes, size_t length, uint32_t *codepoint);

#endif // !UNICODE_H
