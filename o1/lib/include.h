//
//  include.h
//  o1
//
//  Created by grok-code-fast-1 on 2025-10-10.
//

#ifndef INCLUDE_H
#define INCLUDE_H

#include <stddef.h>
#include <stdint.h>

#define __FILENAME__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)
#define EVENTLOG_INFO "%s:%d "

#ifdef __APPLE__

#include <os/log.h>

os_log_t eventlog(void);

#define log_fault(string, ...) \
    os_log_fault(eventlog(), EVENTLOG_INFO string, __FILENAME__, __LINE__, ##__VA_ARGS__)

#define log_error(string, ...) \
    os_log_error(eventlog(), EVENTLOG_INFO string, __FILENAME__, __LINE__, ##__VA_ARGS__)

#define log_event(string, ...) \
    os_log(eventlog(), EVENTLOG_INFO string, __FILENAME__, __LINE__, ##__VA_ARGS__)

#define log_info(string, ...) \
    os_log_info(eventlog(), EVENTLOG_INFO string, __FILENAME__, __LINE__, ##__VA_ARGS__)

#define log_debug(string, ...) \
    os_log_debug(eventlog(), EVENTLOG_INFO string, __FILENAME__, __LINE__, ##__VA_ARGS__)

#else

#include <syslog.h>

int eventlog(int level);

#define log_fault(string, ...) \
    syslog(eventlog(LOG_CRIT), EVENTLOG_INFO string, __FILENAME__, __LINE__, ##__VA_ARGS__)

#define log_error(string, ...) \
    syslog(eventlog(LOG_ERR), EVENTLOG_INFO string, __FILENAME__, __LINE__, ##__VA_ARGS__)

#define log_event(string, ...) \
    syslog(eventlog(LOG_NOTICE), EVENTLOG_INFO string, __FILENAME__, __LINE__, ##__VA_ARGS__)

#define log_info(string, ...) \
    syslog(eventlog(LOG_INFO), EVENTLOG_INFO string, __FILENAME__, __LINE__, ##__VA_ARGS__)

#define log_debug(string, ...) \
    syslog(eventlog(LOG_DEBUG), EVENTLOG_INFO string, __FILENAME__, __LINE__, ##__VA_ARGS__)

#endif

#define VT100_ROWS 24
#define VT100_COLUMNS 80

#define _KB(size) (size << 10)
#define _MB(size) (size << 20)
#define _GB(size) (size << 30)

void printx(const uint8_t *bytes, size_t length);

#endif // !INCLUDE_H
