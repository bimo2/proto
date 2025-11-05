//
//  ansi_reader.h
//  o1
//
//  Created by gpt-5-high on 2025-10-12.
//

#ifndef ANSI_READER_H
#define ANSI_READER_H

#include "ansi.h"

#include <stddef.h>
#include <stdint.h>

typedef struct ansi_reader_t ansi_reader_t;
typedef void (*ansi_reader_callback_t)(void *, ansi_t *);

ansi_reader_t *init_ansi_reader(void);

void free_ansi_reader(ansi_reader_t *reader);

void ansi_reader_reset(ansi_reader_t *reader);

int ansi_reader_set_osc_capacity(ansi_reader_t *reader, size_t capacity);

void ansi_reader_set_callback(ansi_reader_t *reader, ansi_reader_callback_t callback, void *user_data);

void ansi_reader_feed(ansi_reader_t *reader, const uint8_t *bytes, size_t length);

#endif // !ANSI_READER_H
