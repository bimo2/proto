//
//  session.c
//  o1
//
//  Created by gpt-5-high on 2025-10-10.
//

#include "session.h"
#include "buffer.h"
#include "include.h"

#include <errno.h>
#include <fcntl.h>
#include <libproc.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <termios.h>
#include <unistd.h>
#include <sys/uio.h>

struct session_t {
    pid_t pid;
    int fd;
    bool running;
    buffer_t *pending;
};

session_t *init_session(void) {
    session_t *session = calloc(1, sizeof(session_t));

    if (!session) return NULL;

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

char *session_process(session_t *session) {
    static _Thread_local char buffer[PROC_PIDPATHINFO_MAXSIZE];

    if (proc_pidpath(session->pid, buffer, sizeof(buffer)) < 1) {
        perror("proc_pidpath");
        buffer[0] = '\0';
    }

    return buffer;
}

void session_start(session_t *session, const char *file, char *const argv[], char *const envp[]) {
    if (session->running) return;

    int master_fd = posix_openpt(O_RDWR | O_NOCTTY);

    if (master_fd < 0) {
        perror("posix_openpt");

        return;
    }

    int flags = fcntl(master_fd, F_GETFD);

    if (flags != -1) fcntl(master_fd, F_SETFD, flags | FD_CLOEXEC);

    if (grantpt(master_fd) != 0) {
        perror("grantpt");
        close(master_fd);

        return;
    }

    if (unlockpt(master_fd) != 0) {
        perror("unlockpt");
        close(master_fd);

        return;
    }

    const char *slave_name = ptsname(master_fd);

    if (!slave_name) {
        perror("ptsname");
        close(master_fd);

        return;
    }

    pid_t child_pid = fork();

    if (child_pid < 0) {
        perror("fork");
        close(master_fd);

        return;
    }

    if (child_pid == 0) {
        setsid();

        int slave_fd = open(slave_name, O_RDWR);

        if (slave_fd < 0) {
            perror("open");
            _exit(127);
        }

        if (ioctl(slave_fd, TIOCSCTTY, (char *)NULL) == -1) perror("ioctl");

        struct termios tio;

        if (tcgetattr(slave_fd, &tio) == 0) {
            cfmakeraw(&tio);
            tio.c_cc[VMIN] = 1;
            tio.c_cc[VTIME] = 0;
            tcsetattr(slave_fd, TCSANOW, &tio);
        }

        dup2(slave_fd, STDIN_FILENO);
        dup2(slave_fd, STDOUT_FILENO);
        dup2(slave_fd, STDERR_FILENO);

        if (slave_fd > STDERR_FILENO) close(slave_fd);

        close(master_fd);
        execve(file, argv, envp);
        perror("execve");
        _exit(127);
    }

    session->pid = child_pid;
    session->fd = master_fd;
    session->running = true;

    int mflags = fcntl(master_fd, F_GETFL);

    if (mflags != -1) fcntl(master_fd, F_SETFL, mflags | O_NONBLOCK);

    return;
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

ssize_t session_write(session_t *session, const uint8_t *data, size_t length) {
    if (session->fd < 0) return -1;
    if (length == 0) return 0;

    ssize_t total = 0;

    if (session->pending->size == 0) {
        total = write(session->fd, data, length);

        if (total < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                total = 0;
            } else {
                perror("write");

                return total;
            }
        }

        if ((size_t)total == length) return total;

        data += total;
        length -= (size_t)total;
    }

    if (length > 0) buffer_write(session->pending, data, length, NULL);

    return total;
}

ssize_t session_flush_write(session_t *session) {
    if (session->fd < 0) return -1;
    if (session->pending->size == 0) return 0;

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

        if (total > 0) {
            buffer_shift(session->pending, total);
        } else if (total < 0) {
            if (errno != EAGAIN && errno != EWOULDBLOCK) {
                perror("writev");

                buffer_reset(session->pending);
            }
        }
    }

    return total;
}
