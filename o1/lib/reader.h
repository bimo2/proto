//
//  reader.h
//  o1
//
//  Created by gpt-5-high on 2025-10-12.
//

#ifndef READER_H
#define READER_H

#include "ansi.h"

#include <stddef.h>
#include <stdint.h>

typedef struct reader_t reader_t;
typedef void (*reader_ansi_callback_t)(void *, ansi_t *);

reader_t *init_reader(void);

void free_reader(reader_t *reader);

void reader_reset(reader_t *reader);

void reader_set_osc_capacity(reader_t *reader, size_t capacity);

void reader_set_ansi_callback(reader_t *reader, reader_ansi_callback_t callback, void *user_data);

void reader_feed(reader_t *reader, const uint8_t *bytes, size_t length);

#endif // !READER_H
