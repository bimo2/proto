//
//  session.h
//  o1
//
//  Created by gpt-5-high on 2025-10-10.
//

#ifndef SESSION_H
#define SESSION_H

#include <stdbool.h>
#include <stdint.h>
#include <sys/types.h>

typedef struct session_t session_t;

session_t *init_session(void);

void free_session(session_t *session);

pid_t session_pid(session_t *session);

int session_fd(session_t *session);

bool session_running(session_t *session);

char *session_process(session_t *session);

void session_start(session_t *session, const char *file, char *const argv[], char *const envp[]);

void session_stop(session_t *session);

ssize_t session_read(session_t *session, uint8_t *data, size_t length);

ssize_t session_write(session_t *session, const uint8_t *data, size_t length, size_t *overwrite);

ssize_t session_flush_write(session_t *session);

void session_update_window(session_t *session, uint32_t rows, uint32_t columns, uint32_t width, uint32_t height);

#endif // !SESSION_H
