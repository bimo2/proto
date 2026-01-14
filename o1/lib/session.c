//
//  session.c
//  o1
//
//  Created by gpt-5-high on 2025-10-10.
//

#include "session.h"

#include "buffer.h"
#include "include.h"
#include "screen.h"

#include <errno.h>
#include <fcntl.h>
#include <libproc.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <termios.h>
#include <unistd.h>

#ifdef __APPLE__
#include <util.h>
#else
#include <pty.h>
#endif

bool session_sandbox = false;

struct session_t {
    pid_t pid;
    int fd;
    bool running;
    buffer_t *pending;
};

static void sandbox(int fd) {
    struct termios options;

    if (tcgetattr(fd, &options) != 0) {
        log_error("tcgetattr error: %d", errno);

        return;
    }

    cfmakeraw(&options);
    options.c_lflag |= ISIG;
    options.c_oflag |= OPOST | ONLCR;
    options.c_cc[VMIN] = 1;
    options.c_cc[VTIME] = 0;

    if (tcsetattr(fd, TCSANOW, &options) != 0) {
        log_error("tcsetattr error: %d", errno);

        return;
    }
}

session_t *init_session(void) {
    session_t *session = (session_t *)calloc(1, sizeof(session_t));

    if (!session) {
        log_error("malloc failed: %zu", sizeof(session_t));

        return NULL;
    }

    session->pid = -1;
    session->fd = -1;
    session->running = false;
    session->pending = init_buffer(_MB(1));

    if (!session->pending) {
        free(session);

        return NULL;
    }

    return session;
}

void free_session(session_t *session) {
    if (!session) return;

    session_stop(session);
    free_buffer(session->pending);
    free(session);
}

pid_t session_pid(session_t *session) {
    return session->pid;
}

int session_fd(session_t *session) {
    return session->fd;
}

bool session_running(session_t *session) {
    return session->running;
}

const char *session_process(session_t *session) {
    static _Thread_local char buffer[PROC_PIDPATHINFO_MAXSIZE];

    if (proc_pidpath(session->pid, buffer, sizeof(buffer)) < 1) {
        log_error("proc_pidpath error: %d", errno);
        buffer[0] = '\0';
    }

    return buffer;
}

void session_start(session_t *session, const char *file, char *const argv[], char *const envp[]) {
    if (session->running) return;

    int master_fd = -1;
    struct winsize ws;

    memset(&ws, 0, sizeof(ws));
    ws.ws_row = screen_default_rows - screen_default_offset;
    ws.ws_col = screen_default_columns;
    ws.ws_xpixel = screen_default_width;
    ws.ws_ypixel = screen_default_height;

    pid_t pid = forkpty(&master_fd, NULL, NULL, &ws);

    if (pid < 0) {
        log_error("forkpty error: %d", errno);

        return;
    }

    if (pid == 0) {
        if (session_sandbox) sandbox(STDIN_FILENO);

        const char *home = getenv("HOME");

        if (home) chdir(home);

        execve(file, argv, envp);
        log_error("execve error: %d", errno);
        _exit(127);
    }

    int flags = fcntl(master_fd, F_GETFD);

    if (flags != -1) fcntl(master_fd, F_SETFD, flags | FD_CLOEXEC);

    int sflags = fcntl(master_fd, F_GETFL);

    if (sflags != -1) fcntl(master_fd, F_SETFL, sflags | O_NONBLOCK);

    session->pid = pid;
    session->fd = master_fd;
    session->running = true;
}

void session_stop(session_t *session) {
    if (!session->running) return;
    if (session->pid > 0) kill(session->pid, SIGTERM);

    if (session->fd > -1) {
        close(session->fd);
        session->fd = -1;
    }

    session->running = false;
    session->pid = -1;
}

ssize_t session_read(session_t *session, uint8_t *data, size_t length) {
    if (session->fd < 0) return -1;

    return read(session->fd, data, length);
}

ssize_t session_write(session_t *session, const uint8_t *data, size_t length, size_t *overwrite) {
    if (session->fd < 0) return -1;
    if (!data || length < 1) return 0;

    ssize_t total = 0;

    if (buffer_size(session->pending) < 1) {
        total = write(session->fd, data, length);

        if (total < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                total = 0;
            } else {
                log_error("write error: %d", errno);

                return total;
            }
        }

        if ((size_t)total == length) return total;

        data += total;
        length -= (size_t)total;
    }

    if (length > 0) buffer_write(session->pending, data, length, overwrite);

    return total + (ssize_t)length;
}

ssize_t session_flush_write(session_t *session) {
    if (session->fd < 0) return -1;
    if (buffer_size(session->pending) < 1) return 0;

    const uint8_t *segment_a;
    const uint8_t *segment_b;
    size_t length_a;
    size_t length_b;

    buffer_segment(session->pending, &segment_a, &length_a, &segment_b, &length_b);

    struct iovec iov[2];
    int iov_count = 0;

    if (length_a > 0) {
        iov[iov_count].iov_base = (void *)segment_a;
        iov[iov_count].iov_len = length_a;
        iov_count++;
    }

    if (length_b > 0) {
        iov[iov_count].iov_base = (void *)segment_b;
        iov[iov_count].iov_len = length_b;
        iov_count++;
    }

    ssize_t total = 0;

    if (iov_count > 0) {
        total = writev(session->fd, iov, iov_count);

        if (total < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                total = 0;
            } else {
                log_error("writev error: %d", errno);
                buffer_reset(session->pending);

                return total;
            }
        }

        buffer_shift(session->pending, total);
    }

    return total;
}

void session_update_window(session_t *session, uint32_t rows, uint32_t columns, uint32_t width, uint32_t height) {
    if (session->fd < 0) return;

    struct winsize ws;

    memset(&ws, 0, sizeof(ws));
    ws.ws_row = rows - screen_default_offset;
    ws.ws_col = columns;
    ws.ws_xpixel = width;
    ws.ws_ypixel = height;

    if (ioctl(session->fd, TIOCSWINSZ, &ws) == -1) log_error("ioctl error: %d", errno);

    return;
}
