//
//  SessionTests.m
//  o1-tests
//
//  Created by grok-4 on 2025-11-04.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include "include.h"
#include "screen.h"
#include "session.h"

#include <dispatch/dispatch.h>
#include <errno.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/uio.h>
#include <termios.h>
#include <unistd.h>

static char *const envp[] = {"TERM=xterm-256color", NULL};

@interface SessionTests : XCTestCase

@end

@implementation SessionTests

- (void)setUp {
    session_sandbox = true;
    screen_default_offset = 0;
}

- (void)test_start_stop {
    session_t *session = init_session();

    XCTAssertFalse(session_running(session));

    char *const argv[] = {"/bin/sleep", "1", NULL};

    session_start(session, argv[0], argv, envp);
    XCTAssertTrue(session_running(session));
    XCTAssertGreaterThan(session_pid(session), 0);
    XCTAssertGreaterThanOrEqual(session_fd(session), 0);

    session_stop(session);
    XCTAssertFalse(session_running(session));
    XCTAssertEqual(session_pid(session), -1);
    XCTAssertEqual(session_fd(session), -1);

    free_session(session);
}

- (void)test_throughput_min {
    session_t *session = init_session();
    char *const argv[] = {"/bin/cat", NULL};

    session_start(session, argv[0], argv, envp);

    const char *text = "testing\n";
    size_t length = strlen(text);
    ssize_t total = session_write(session, (const uint8_t *)text, length, NULL);

    XCTAssertEqual(total, length);

    XCTestExpectation *expectation = [self expectationWithDescription:@"did read bytes"];
    __block NSMutableData *output = [NSMutableData data];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        uint8_t data[64];
        size_t total = 0;

        while (total < length) {
            ssize_t received = session_read(session, data + total, sizeof(data) - total);

            if (received > 0) {
                total += (size_t)received;

                continue;
            }

            if (received < 0 && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)) continue;

            break;
        }

        [output appendBytes:data length:total];
        [expectation fulfill];
    });

    [self waitForExpectations:@[expectation] timeout:1.0];
    XCTAssertEqual(output.length, length + 1);
    XCTAssertEqual(memcmp(output.bytes, "testing\r\n", length), 0);

    session_stop(session);
    free_session(session);
}

- (void)test_throughput_max {
    session_t *session = init_session();
    char *const argv[] = {"/bin/cat", NULL};

    session_start(session, argv[0], argv, envp);
    XCTAssertTrue(session_running(session));

    uint8_t data[_MB(1) + _KB(512)];

    memset(data, 'A', sizeof(data));

    ssize_t write_total = session_write(session, (const uint8_t *)data, sizeof(data), NULL);

    XCTAssertEqual((size_t)write_total, sizeof(data));

    XCTestExpectation *expectation = [self expectationWithDescription:@"did read bytes"];
    const size_t target = _MB(1);
    __block size_t read_total = 0;
    __weak __block void (^weakBlock)(void);

    __block void (^block)(void) = ^{
        session_flush_write(session);

        uint8_t data[_KB(32)];
        ssize_t received = session_read(session, data, sizeof(data));

        if (received > 0) {
            read_total += (size_t)received;

            if (read_total >= target) {
                [expectation fulfill];

                return;
            }
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC), dispatch_get_main_queue(), weakBlock);
    };

    weakBlock = block;
    block();

    [self waitForExpectations:@[expectation] timeout:5.0];
    XCTAssertGreaterThan(read_total, 0);

    session_stop(session);
    free_session(session);
}

- (void)test_window {
    session_t *session = init_session();
    char *const argv[] = {"/bin/sleep", "1", NULL};

    session_start(session, argv[0], argv, envp);
    XCTAssertTrue(session_running(session));

    struct winsize ws;

    memset(&ws, 0, sizeof(ws));
    ioctl(session_fd(session), TIOCGWINSZ, &ws);
    XCTAssertEqual(ws.ws_row, 24);
    XCTAssertEqual(ws.ws_col, 80);

    uint32_t rows = 16;
    uint32_t columns = 64;

    session_update_window(session, rows, columns, 0, 0);
    memset(&ws, 0, sizeof(ws));
    ioctl(session_fd(session), TIOCGWINSZ, &ws);
    XCTAssertEqual(ws.ws_row, rows);
    XCTAssertEqual(ws.ws_col, columns);

    session_stop(session);
    free_session(session);
}

@end
