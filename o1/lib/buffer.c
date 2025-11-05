//
//  buffer.c
//  o1
//
//  Created by gpt-5-high on 2025-10-10.
//

#include "buffer.h"

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

struct buffer_t {
    size_t capacity;
    uint8_t *bytes;
    size_t size;
    size_t head;
};

static inline size_t min(size_t a, size_t b) {
    return a < b ? a : b;
}

buffer_t *init_buffer(size_t capacity) {
    if (capacity < 1) return NULL;

    buffer_t *buffer = (buffer_t *)calloc(1, sizeof(buffer_t));

    if (!buffer) return NULL;

    buffer->capacity = capacity;
    buffer->bytes = (uint8_t *)malloc(capacity);

    if (!buffer->bytes) {
        free(buffer);

        return NULL;
    }

    buffer->size = 0;
    buffer->head = 0;

    return buffer;
}

void free_buffer(buffer_t *buffer) {
    if (!buffer) return;

    free(buffer->bytes);
    free(buffer);
}

void buffer_reset(buffer_t *buffer) {
    buffer->size = 0;
    buffer->head = 0;
}

size_t buffer_capacity(buffer_t *buffer) {
    return buffer->capacity;
}

int buffer_set_capacity(buffer_t *buffer, size_t capacity, size_t *overwrite) {
    if (capacity < 1) return -1;
    if (overwrite) *overwrite = 0;
    if (buffer->capacity == capacity) return 0;

    uint8_t *bytes = (uint8_t *)malloc(capacity);

    if (!bytes) return -1;

    size_t size = min(buffer->size, capacity);

    if (overwrite && capacity < buffer->size) *overwrite = buffer->size - capacity;

    if (size > 0) {
        size_t offset = buffer->size - size;
        size_t start = (buffer->head + offset) % buffer->capacity;
        size_t size_a = min(size, buffer->capacity - start);

        memcpy(bytes, buffer->bytes + start, size_a);

        size_t size_b = size - size_a;

        if (size_b > 0) memcpy(bytes + size_a, buffer->bytes, size_b);
    }

    buffer->capacity = capacity;
    free(buffer->bytes);
    buffer->bytes = bytes;
    buffer->size = size;
    buffer->head = 0;

    return 0;
}

size_t buffer_size(buffer_t *buffer) {
    return buffer->size;
}

void buffer_segment(const buffer_t *buffer, const uint8_t **segment_a, size_t *length_a, const uint8_t **segment_b, size_t *length_b) {
    if (buffer->size < 1) {
        if (segment_a) *segment_a = NULL;
        if (length_a) *length_a = 0;
        if (segment_b) *segment_b = NULL;
        if (length_b) *length_b = 0;

        return;
    }

    size_t size_a = min(buffer->size, buffer->capacity - buffer->head);

    if (segment_a) *segment_a = buffer->bytes + buffer->head;
    if (length_a) *length_a = size_a;

    size_t size_b = buffer->size - size_a;

    if (size_b > 0) {
        if (segment_b) *segment_b = buffer->bytes;
        if (length_b) *length_b = size_b;
    } else {
        if (segment_b) *segment_b = NULL;
        if (length_b) *length_b = 0;
    }
}

void buffer_shift(buffer_t *buffer, size_t length) {
    if (length < 1) return;

    if (length >= buffer->size) {
        buffer_reset(buffer);

        return;
    }

    buffer->head = (buffer->head + length) % buffer->capacity;
    buffer->size -= length;
}

size_t buffer_read(const buffer_t *buffer, uint8_t *source, size_t length) {
    if (!source || buffer->size < 1 || length < 1) return 0;

    size_t size = min(length, buffer->size);
    size_t size_a = min(size, buffer->capacity - buffer->head);

    memcpy(source, buffer->bytes + buffer->head, size_a);

    size_t size_b = size - size_a;

    if (size_b > 0) memcpy(source + size_a, buffer->bytes, size_b);

    return size;
}

size_t buffer_write(buffer_t *buffer, const uint8_t *source, size_t length, size_t *overwrite) {
    if (!source || buffer->capacity < 1 || length < 1) {
        if (overwrite) *overwrite = 0;

        return 0;
    }

    size_t size = min(length, buffer->capacity);
    size_t drop = buffer->size + size > buffer->capacity ? buffer->size + size - buffer->capacity : 0;

    if (drop > 0) {
        buffer->head = (buffer->head + drop) % buffer->capacity;
        buffer->size -= drop;
    }

    if (overwrite) {
        size_t source_drop = length > size ? length - size : 0;

        *overwrite = drop + source_drop;
    }

    size_t start = (buffer->head + buffer->size) % buffer->capacity;
    size_t size_a = min(size, buffer->capacity - start);

    memcpy(buffer->bytes + start, source + length - size, size_a);

    size_t size_b = size - size_a;

    if (size_b > 0) memcpy(buffer->bytes, source + length - size + size_a, size_b);

    buffer->size += size;

    return size;
}
