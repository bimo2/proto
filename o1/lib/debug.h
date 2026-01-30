//
//  debug.h
//  o1
//
//  Created by grok-code-fast-1 on 2026-01-21.
//

#ifndef DEBUG_H
#define DEBUG_H

#include "render.h"
#include "screen.h"

#include <stddef.h>

void debug_out(const char *file, const uint8_t *bytes, size_t length);

void debug_print_ops(render_t *ops, size_t count);

void debug_print_screen(screen_t *screen);

#endif // !DEBUG_H
