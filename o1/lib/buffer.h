//
//  buffer.h
//  o1
//
//  Created by gpt-5-high on 2025-10-10.
//

#ifndef BUFFER_H
#define BUFFER_H

#include <stddef.h>
#include <stdint.h>

typedef struct buffer_t {
    size_t capacity;
    uint8_t *bytes;
    size_t size;
    size_t head;
} buffer_t;

buffer_t *init_buffer(size_t capacity);

void free_buffer(buffer_t *buffer);

void buffer_reset(buffer_t *buffer);

int buffer_set_capacity(buffer_t *buffer, size_t capacity, size_t *overwrite);

void buffer_segment(const buffer_t *buffer, const uint8_t **segment_a, size_t *length_a, const uint8_t **segment_b, size_t *length_b);

void buffer_shift(buffer_t *buffer, size_t length);

size_t buffer_read(const buffer_t *buffer, uint8_t *source, size_t length);

size_t buffer_write(buffer_t *buffer, const uint8_t *source, size_t length, size_t *overwrite);

#endif // !BUFFER_H
