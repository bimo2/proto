//
//  testing.h
//  o1-tests
//
//  Created by gpt-5.2-high on 2026-01-01.
//

#ifndef TESTING_H
#define TESTING_H

#include "ansi_reader.h"
#include "screen.h"
#include "screen_context.h"
#include "session.h"

#include <stddef.h>
#include <stdint.h>

#define TEST_ROWS 20
#define TEST_COLUMNS 73

typedef struct test_t {
    session_t *session;
    ansi_reader_t *reader;
    screen_context_t *context;
} test_t;

typedef struct test_cell_t {
    uint32_t codepoint;
    uint32_t flags;
    uint32_t fg_color;
    uint32_t bg_color;
} test_cell_t;

typedef struct test_cursor_t {
    int32_t row;
    int32_t column;
} test_cursor_t;

typedef uint32_t test_snapshot_t[TEST_ROWS][TEST_COLUMNS];

test_t *init_test(void);

void free_test(test_t *test);

void test_config(void);

void test_write(test_t *test, const uint8_t *bytes, size_t length);

int test_fixture(const char *path, size_t start, size_t end, uint8_t **bytes, size_t *length);

void test_snapshot(test_snapshot_t snapshot, const char *text);

const test_cell_t test_cell(test_t *test, int32_t row, int32_t column);

const test_cursor_t test_cursor(test_t *test);

#endif // !TESTING_H
