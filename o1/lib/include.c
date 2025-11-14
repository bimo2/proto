//
//  include.c
//  o1
//
//  Created by grok-code-fast-1 on 2025-11-11.
//

#include "include.h"

#ifdef __APPLE__

#include <dispatch/dispatch.h>
#include <os/log.h>

os_log_t eventlog(void) {
    static os_log_t log;
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        log = os_log_create("com.github.o1", "eventlog");
    });

    return log;
}

#else

#include <pthread.h>
#include <syslog.h>

static pthread_once_t _1 = PTHREAD_ONCE_INIT;

static void logging(void) {
    openlog("com.github.o1", LOG_PID | LOG_CONS, LOG_USER);
}

int eventlog(int level) {
    pthread_once(&_1, logging);

    return level;
}

#endif
