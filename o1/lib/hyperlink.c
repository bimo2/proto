//
//  hyperlink.c
//  o1
//
//  Created by grok-4.7-high-fast on 2026-10-01.
//

#include "hyperlink.h"

#include "include.h"
#include "screen.h"

#include <ctype.h>
#include <stdlib.h>
#include <string.h>

static bool scheme_value(uint32_t codepoint) {
    if (codepoint > 0x7Fu) return false;

    return isalnum((unsigned char)codepoint) || codepoint == '+' || codepoint == '-' || codepoint == '.';
}

static bool url_value(uint32_t codepoint) {
    if (codepoint <= 0x20u || codepoint > 0x7Eu) return false;

    return codepoint != '"' && codepoint != '\'' && codepoint != '<' && codepoint != '>';
}

static bool end_value(uint32_t codepoint) {
    switch (codepoint) {
        case '.':
        case ',':
        case ';':
        case ':':
        case '!':
        case '?':
        case ')':
        case ']':
        case '}':
            return true;
    }

    return false;
}

static bool valid_uri(const char *value) {
    if (!value || value[0] == '\0' || !isalpha((unsigned char)value[0])) return false;

    size_t index = 1;

    while (value[index] != '\0' && scheme_value((uint32_t)(unsigned char)value[index])) index++;

    return value[index] == ':';
}

static bool search_cells(hyperlink_t *link, const screen_cell_t *cells, int32_t length, int32_t start) {
    if (!link || !cells || length < 1 || start < 0 || start >= length) return false;
    if (cells[start].link_id != 0 || cells[start].width == 0) return false;
    if (cells[start].codepoint > 0x7Fu || !isalpha((unsigned char)cells[start].codepoint)) return false;
    if (start > 0 && cells[start - 1].link_id == 0 && scheme_value(cells[start - 1].codepoint)) return false;

    int32_t protocol = start + 1;

    while (protocol < length && cells[protocol].link_id == 0 && cells[protocol].width != 0 && scheme_value(cells[protocol].codepoint)) protocol++;

    if (protocol + 3 >= length) return false;
    if (cells[protocol].link_id != 0 || cells[protocol].codepoint != ':') return false;
    if (cells[protocol + 1].link_id != 0 || cells[protocol + 1].codepoint != '/') return false;
    if (cells[protocol + 2].link_id != 0 || cells[protocol + 2].codepoint != '/') return false;

    int32_t end = protocol + 3;

    while (end < length && cells[end].link_id == 0 && cells[end].width != 0 && url_value(cells[end].codepoint)) end++;
    while (end > protocol + 3 && end_value(cells[end - 1].codepoint)) end--;

    if (end <= protocol + 3) return false;

    link->row = -1;
    link->start = start;
    link->end = end;
    link->value = NULL;

    return true;
}

static void append_link(hyperlink_t **links, size_t *count, size_t *capacity, int32_t line, int32_t columns, int32_t first, int32_t last, int32_t start, int32_t end, const char *value) {
    if (!links || !count || !capacity || !value || columns < 1 || start < 0 || end <= start) return;

    int32_t location = start;
    size_t value_length = strlen(value);

    if (value_length == SIZE_MAX) return;

    while (location < end) {
        int32_t row = line + location / columns;
        int32_t column = location % columns;
        int32_t length = columns - column;

        if (length > end - location) length = end - location;

        if (row >= first && row <= last) {
            if (*count == *capacity) {
                size_t next = *capacity < 1 ? 8 : *capacity * 2;

                if (next < *capacity || next > SIZE_MAX / sizeof(hyperlink_t)) return;

                hyperlink_t *id = (hyperlink_t *)realloc(*links, next * sizeof(hyperlink_t));

                if (!id) {
                    log_error("realloc failed: %zu", next * sizeof(hyperlink_t));

                    return;
                }

                *links = id;
                *capacity = next;
            }

            char *copy = (char *)malloc(value_length + 1);

            if (!copy) {
                log_error("malloc failed: %zu", value_length + 1);

                return;
            }

            memcpy(copy, value, value_length);
            copy[value_length] = '\0';

            (*links)[*count] = (hyperlink_t){
                .row = row,
                .start = column,
                .end = column + length,
                .value = copy,
            };

            (*count)++;
        }

        location += length;
    }
}

static void search_line(hyperlink_t **links, size_t *count, size_t *capacity, screen_t *screen, const screen_cell_t *cells, int32_t length, int32_t line, int32_t columns, int32_t first, int32_t last) {
    int32_t column = 0;

    while (column < length) {
        uint32_t link_id = cells[column].link_id;

        if (link_id != 0) {
            int32_t end = column + 1;

            while (end < length && cells[end].link_id == link_id) end++;

            const char *value = screen_link_url(screen, link_id);

            if (valid_uri(value)) append_link(links, count, capacity, line, columns, first, last, column, end, value);

            column = end;

            continue;
        }

        hyperlink_t result;

        if (search_cells(&result, cells, length, column)) {
            size_t value_length = (size_t)(result.end - result.start);
            char *value = (char *)malloc(value_length + 1);

            if (!value) {
                log_error("malloc failed: %zu", value_length + 1);

                return;
            }

            for (int32_t index = result.start; index < result.end; index++) value[index - result.start] = (char)cells[index].codepoint;

            value[value_length] = '\0';
            append_link(links, count, capacity, line, columns, first, last, result.start, result.end, value);
            column = result.end;
            free(value);

            continue;
        }

        column++;
    }

    return;
}

void hyperlink_search(hyperlink_t **links, screen_t *screen, int32_t first, int32_t last, size_t *count) {
    if (!links || !count) return;

    *links = NULL;
    *count = 0;

    if (!screen) return;

    int32_t total = screen_total_rows(screen);
    int32_t columns = screen_columns(screen);

    if (total < 1 || columns < 1 || first < 0 || first >= total || last < first) return;
    if (last >= total) last = total - 1;

    int32_t search_first = first;
    int32_t search_last = last;

    while (search_first > 0) {
        bool soft_wrap = false;

        if (!screen_absolute_row(screen, search_first - 1, &soft_wrap, NULL) || !soft_wrap) break;

        search_first--;
    }

    while (search_last < total - 1) {
        bool soft_wrap = false;

        if (!screen_absolute_row(screen, search_last, &soft_wrap, NULL) || !soft_wrap) break;

        search_last++;
    }

    size_t capacity = 0;
    int32_t line = search_first;

    while (line <= search_last) {
        int32_t end = line;

        while (end < search_last) {
            bool soft_wrap = false;

            if (!screen_absolute_row(screen, end, &soft_wrap, NULL) || !soft_wrap) break;

            end++;
        }

        int32_t rows = end - line + 1;
        int32_t length = rows * columns;
        screen_cell_t *cells = (screen_cell_t *)malloc((size_t)length * sizeof(screen_cell_t));

        if (!cells) {
            log_error("malloc failed: %zu", (size_t)length * sizeof(screen_cell_t));
            hyperlink_clear(*links, *count);
            *links = NULL;
            *count = 0;

            return;
        }

        for (int32_t row = line; row <= end; row++) {
            const screen_cell_t *source = screen_absolute_row(screen, row, NULL, NULL);

            if (!source) {
                free(cells);
                hyperlink_clear(*links, *count);
                *links = NULL;
                *count = 0;

                return;
            }

            memcpy(cells + ((size_t)(row - line) * (size_t)columns), source, (size_t)columns * sizeof(screen_cell_t));
        }

        search_line(links, count, &capacity, screen, cells, length, line, columns, first, last);
        line = end + 1;
        free(cells);
    }

    return;
}

void hyperlink_clear(hyperlink_t *links, size_t count) {
    if (!links) return;

    for (size_t index = 0; index < count; index++) free(links[index].value);

    free(links);
}
