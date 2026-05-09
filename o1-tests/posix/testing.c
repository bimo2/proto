//
//  testing.c
//  o1-tests
//
//  Created by gpt-5.2-high on 2026-01-01.
//

#include "testing.h"

#include "ansi_reader.h"
#include "include.h"
#include "screen.h"
#include "screen_context.h"
#include "session.h"
#include "unicode.h"

#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static void on_ansi_callback(void *user_data, ansi_t *ansi) {
    test_t *test = (test_t *)user_data;

    if (!test) return;

    screen_context_update(test->context, ansi);
}

static int fixture(const char *path, uint8_t **bytes, size_t *length) {
    FILE *input = fopen(path, "rb");

    if (!input) {
        log_error("fopen error: %d", errno);

        return 0;
    }

    fseek(input, 0, SEEK_END);

    long size = ftell(input);

    if (size < 1) {
        fclose(input);

        return 0;
    }

    fseek(input, 0, SEEK_SET);
    *bytes = (uint8_t *)malloc((size_t)size);

    if (!(*bytes)) {
        log_error("malloc failed: %zu", (size_t)size);
        fclose(input);

        return 0;
    }

    *length = fread(*bytes, 1, (size_t)size, input);
    fclose(input);

    if (*length != (size_t)size) {
        free(*bytes);

        return 0;
    }

    while (*length > 0 && ((*bytes)[*length - 1] == '\n' || (*bytes)[*length - 1] == '\r')) (*length)--;

    return 1;
}

static size_t encode_utf8(uint32_t codepoint, char out[4]) {
    if (!out) return 0;
    if (codepoint > 0x10FFFFu) return 0;
    if (codepoint >= 0xD800u && codepoint <= 0xDFFFu) return 0;

    if (codepoint <= 0x7Fu) {
        out[0] = (char)codepoint;

        return 1;
    }

    if (codepoint <= 0x7FFu) {
        out[0] = (char)(0xC0u | (codepoint >> 6));
        out[1] = (char)(0x80u | (codepoint & 0x3Fu));

        return 2;
    }

    if (codepoint <= 0xFFFFu) {
        out[0] = (char)(0xE0u | (codepoint >> 12));
        out[1] = (char)(0x80u | ((codepoint >> 6) & 0x3Fu));
        out[2] = (char)(0x80u | (codepoint & 0x3Fu));

        return 3;
    }

    out[0] = (char)(0xF0u | (codepoint >> 18));
    out[1] = (char)(0x80u | ((codepoint >> 12) & 0x3Fu));
    out[2] = (char)(0x80u | ((codepoint >> 6) & 0x3Fu));
    out[3] = (char)(0x80u | (codepoint & 0x3Fu));

    return 4;
}

test_t *init_test(void) {
    test_t *test = (test_t *)calloc(1, sizeof(test_t));

    if (!test) {
        log_error("malloc failed: %zu", sizeof(test_t));

        return NULL;
    }

    session_t *session = init_session();
    ansi_reader_t *reader = init_ansi_reader();
    screen_context_t *context = init_screen_context();

    if (!session || !reader || !context) return NULL;

    test->session = session;
    test->reader = reader;
    test->context = context;
    ansi_reader_set_callback(reader, on_ansi_callback, test);
    screen_context_set_response_callback(context, NULL, test);
    screen_context_set_title_callback(context, NULL, test);
    screen_context_set_bell_callback(context, NULL, test);
    screen_context_set_mouse_callback(context, NULL, test);

    return test;
}

void free_test(test_t *test) {
    if (!test) return;

    free_screen_context(test->context);
    free_ansi_reader(test->reader);
    free_session(test->session);
}

void test_config(void) {
    screen_default_rows = TEST_ROWS;
    screen_default_columns = TEST_COLUMNS;
    screen_default_offset = 2;
    session_sandbox = true;
}

void test_write(test_t *test, const uint8_t *bytes, size_t length) {
    ansi_reader_feed(test->reader, bytes, length);
}

int test_fixture(const char *path, size_t start, size_t end, uint8_t **bytes, size_t *length) {
    if (!path || !bytes || !length) return 0;

    *bytes = NULL;
    *length = 0;

    uint8_t *buffer = NULL;
    size_t read = 0;

    if (!fixture(path, &buffer, &read)) return 0;
    if (end == SIZE_MAX) end = read;

    if (start > end || end > read) {
        free(buffer);

        return 0;
    }

    size_t take = end - start;

    if (start == 0 && end == read) {
        *bytes = buffer;
        *length = read;

        return 1;
    }

    if (take > 0) {
        *bytes = (uint8_t *)malloc(take);

        if (!(*bytes)) {
            log_error("malloc failed: %zu", take);
            free(buffer);

            return 0;
        }

        memcpy(*bytes, buffer + start, take);
        *length = take;
    }

    free(buffer);

    return 1;
}

void test_snapshot(test_snapshot_t snapshot, const char *text) {
    size_t row = 0;
    const char *line = text;

    while (*line && row < TEST_ROWS) {
        const char *end = line;

        while (*end && *end != '\\') end++;

        const uint8_t *p = (const uint8_t *)line;
        size_t remaining = (size_t)(end - line);
        size_t column = 0;

        while (column < TEST_COLUMNS) {
            if (remaining == 0) {
                snapshot[row][column++] = ' ';

                continue;
            }

            uint32_t codepoint;
            size_t used = unicode_decode_utf8(p, remaining, &codepoint);

            if (used == 0) break;

            p += used;
            remaining -= used;

            int width = unicode_codepoint_width(codepoint);

            if (width == 0) continue;

            snapshot[row][column++] = codepoint;

            if (width == 2 && column < TEST_COLUMNS) snapshot[row][column++] = 0;
        }

        if (*end == '\\') end++;

        line = end;
        row++;
    }

    while (row < TEST_ROWS) {
        for (size_t j = 0; j < TEST_COLUMNS; j++) snapshot[row][j] = ' ';

        row++;
    }
}

const test_cell_t test_cell(test_t *test, int32_t row, int32_t column) {
    screen_t *screen = screen_context_current_screen(test->context);
    screen_cell_t *cell = screen_cell(screen, row, column);

    return (const test_cell_t){
        .codepoint = cell->codepoint,
        .flags = cell->attributes.flags,
        .fg_color = cell->attributes.fg_color,
        .bg_color = cell->attributes.bg_color,
    };
}

const test_cursor_t test_cursor(test_t *test) {
    screen_t *screen = screen_context_current_screen(test->context);
    screen_cursor_t *cursor = screen_cursor(screen);

    return (const test_cursor_t){
        .row = cursor->row,
        .column = cursor->column,
    };
}

void test_print(test_t *test) {
    screen_t *screen = screen_context_current_screen(test->context);

    for (size_t i = 0; i < TEST_ROWS; i++) {
        for (size_t j = 0; j < TEST_COLUMNS; j++) {
            screen_cell_t *cell = screen_cell(screen, (int32_t)i, (int32_t)j);
            uint32_t codepoint = cell->codepoint;

            if (codepoint == 0) codepoint = ' ';

            char buffer[4];
            size_t length = encode_utf8(codepoint, buffer);

            if (length == 0) {
                fputc(' ', stdout);

                continue;
            }

            fwrite(buffer, 1, length, stdout);
        }

        fputs("\n", stdout);
    }

    fflush(stdout);
}
