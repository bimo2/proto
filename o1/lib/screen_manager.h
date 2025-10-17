//
//  screen_manager.h
//  o1
//
//  Created by gpt-5-high on 2025-10-16.
//

#ifndef SCREEN_MANAGER_H
#define SCREEN_MANAGER_H

#include "ansi.h"
#include "screen.h"

typedef struct screen_manager_t screen_manager_t;

screen_manager_t *init_screen_manager(screen_t *screen);

void free_screen_manager(screen_manager_t *manager);

void screen_manager_set_screen(screen_manager_t *manager, screen_t *screen);

void screen_manager_update(screen_manager_t *manager, const ansi_t *ansi);

#endif // !SCREEN_MANAGER_H
