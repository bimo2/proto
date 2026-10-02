//
//  hyperlink.h
//  o1
//
//  Created by grok-4.7-high-fast on 2026-10-01.
//

#ifndef HYPERLINK_H
#define HYPERLINK_H

#include "screen.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct hyperlink_t {
    int32_t row;
    int32_t start;
    int32_t end;
    char *value;
} hyperlink_t;

void hyperlink_search(hyperlink_t **links, screen_t *screen, int32_t first, int32_t last, size_t *count);

void hyperlink_clear(hyperlink_t *links, size_t count);

#endif // !HYPERLINK_H
