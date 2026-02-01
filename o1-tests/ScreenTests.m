//
//  ScreenTests.m
//  o1-tests
//
//  Created by grok-4 on 2025-11-09.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include "screen.h"

#include <string.h>

@interface ScreenTests : XCTestCase

@end

@implementation ScreenTests

- (void)setUp {
    screen_default_offset = 0;
}

- (void)test_grid_cursor {
    screen_t *screen = init_screen(5, 5);

    XCTAssertEqual(screen_cursor(screen)->row, 0);
    XCTAssertEqual(screen_cursor(screen)->column, 0);

    screen_set_cursor_position(screen, -999, 999);
    XCTAssertEqual(screen_cursor(screen)->row, 0);
    XCTAssertEqual(screen_cursor(screen)->column, 4);

    screen_set_cursor_position(screen, 999, -999);
    XCTAssertEqual(screen_cursor(screen)->row, 4);
    XCTAssertEqual(screen_cursor(screen)->column, 0);

    screen_set_cursor_position(screen, 0, 0);
    screen_move_cursor_relative(screen, 999, 999);
    XCTAssertEqual(screen_cursor(screen)->row, 4);
    XCTAssertEqual(screen_cursor(screen)->column, 4);

    screen_set_cursor_position(screen, 0, 0);
    screen_move_cursor_relative(screen, -999, -999);
    XCTAssertEqual(screen_cursor(screen)->row, 0);
    XCTAssertEqual(screen_cursor(screen)->column, 0);

    screen_set_cursor_position(screen, 0, 2);
    screen_write_utf32(screen, 'A');
    screen_write_utf32(screen, 0x0301u);
    XCTAssertEqual(screen_cursor(screen)->row, 0);
    XCTAssertEqual(screen_cursor(screen)->column, 3);

    screen_write_utf32(screen, 0x1F4AFu);
    XCTAssertEqual(screen_cursor(screen)->row, 0);
    XCTAssertEqual(screen_cursor(screen)->column, 4);

    screen_delete_utf32(screen);
    XCTAssertEqual(screen_cursor(screen)->row, 0);
    XCTAssertEqual(screen_cursor(screen)->column, 3);

    screen_write_utf32(screen, ' ');
    screen_write_utf32(screen, 0x1F4AFu);
    XCTAssertEqual(screen_cursor(screen)->row, 1);
    XCTAssertEqual(screen_cursor(screen)->column, 2);

    screen_move_cursor_relative(screen, 0, -1);
    XCTAssertEqual(screen_cursor(screen)->row, 1);
    XCTAssertEqual(screen_cursor(screen)->column, 0);

    screen_move_cursor_relative(screen, 0, 1);
    XCTAssertEqual(screen_cursor(screen)->row, 1);
    XCTAssertEqual(screen_cursor(screen)->column, 2);

    screen_delete_utf32(screen);
    XCTAssertEqual(screen_cursor(screen)->row, 0);
    XCTAssertEqual(screen_cursor(screen)->column, 4);

    free_screen(screen);
}

- (void)test_grid_unicode {
    screen_t *screen = init_screen(5, 5);

    screen_write_utf32(screen, 'X');
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, 'X');
    XCTAssertEqual(screen_cell(screen, 0, 0)->width, 1);

    screen_set_cursor_position(screen, 0, 2);
    screen_write_utf32(screen, 'A');
    screen_write_utf32(screen, 0x0301u);
    XCTAssertEqual(screen_cell(screen, 0, 2)->codepoint, 'A');
    XCTAssertEqual(screen_cell(screen, 0, 2)->width, 1);
    XCTAssertEqual(screen_cell(screen, 0, 3)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 0, 3)->width, 1);

    screen_write_utf32(screen, 0x1F4AFu);
    XCTAssertEqual(screen_cell(screen, 0, 3)->codepoint, 0x1F4AFu);
    XCTAssertEqual(screen_cell(screen, 0, 3)->width, 2);
    XCTAssertEqual(screen_cell(screen, 0, 4)->codepoint, 0);
    XCTAssertEqual(screen_cell(screen, 0, 4)->width, 0);

    screen_delete_utf32(screen);
    XCTAssertEqual(screen_cell(screen, 0, 3)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 0, 3)->width, 1);
    XCTAssertEqual(screen_cell(screen, 0, 4)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 0, 4)->width, 1);

    screen_write_utf32(screen, ' ');
    screen_write_utf32(screen, 0x1F4AFu);
    XCTAssertEqual(screen_cell(screen, 0, 4)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 0, 4)->width, 1);
    XCTAssertEqual(screen_cell(screen, 1, 0)->codepoint, 0x1F4AFu);
    XCTAssertEqual(screen_cell(screen, 1, 0)->width, 2);
    XCTAssertEqual(screen_cell(screen, 1, 1)->codepoint, 0);
    XCTAssertEqual(screen_cell(screen, 1, 1)->width, 0);

    screen_delete_utf32(screen);
    XCTAssertEqual(screen_cell(screen, 0, 4)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 0, 4)->width, 1);
    XCTAssertEqual(screen_cell(screen, 1, 0)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 1, 0)->width, 1);
    XCTAssertEqual(screen_cell(screen, 1, 1)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 1, 1)->width, 1);

    free_screen(screen);
}

- (void)test_grid_dirty {
    screen_t *screen = init_screen(5, 5);

    XCTAssertFalse(screen_cell(screen, 0, 0)->dirty);

    screen_write_utf32(screen, 'X');
    XCTAssertTrue(screen_cell(screen, 0, 0)->dirty);
    XCTAssertFalse(screen_cell(screen, 0, 1)->dirty);

    screen_write_utf32(screen, 0x1F4AFu);
    XCTAssertTrue(screen_cell(screen, 0, 1)->dirty);
    XCTAssertTrue(screen_cell(screen, 0, 2)->dirty);
    XCTAssertFalse(screen_cell(screen, 0, 3)->dirty);

    screen_scroll_up(screen, 1);

    for (int i = 0; i < 5; i++) {
        for (int j = 0; j < 5; j++) {
            XCTAssertTrue(screen_cell(screen, i, j)->dirty);

            screen_cell(screen, i, j)->dirty = false;
        }
    }

    screen_set_grid(screen, 10, 10);
    XCTAssertTrue(screen_invalidate_needs_display(screen));

    for (int i = 0; i < 10; i++) {
        for (int j = 0; j < 10; j++) {
            XCTAssertTrue(screen_cell(screen, i, j)->dirty);

            screen_cell(screen, i, j)->dirty = false;
        }
    }

    screen_erase_line(screen, 2);
    XCTAssertTrue(screen_cell(screen, 0, 0)->dirty);
    XCTAssertFalse(screen_cell(screen, 1, 0)->dirty);

    free_screen(screen);
}

- (void)test_grid_modes {
    screen_t *screen = init_screen(5, 5);

    screen_set_cursor_position(screen, 0, 2);
    screen_set_new_line_mode(screen, false);
    screen_write_utf32(screen, '\n');
    XCTAssertEqual(screen_cursor(screen)->row, 1);
    XCTAssertEqual(screen_cursor(screen)->column, 2);

    screen_set_cursor_position(screen, 0, 2);
    screen_set_new_line_mode(screen, true);
    screen_write_utf32(screen, '\n');
    XCTAssertEqual(screen_cursor(screen)->row, 1);
    XCTAssertEqual(screen_cursor(screen)->column, 0);

    screen_clear(screen);
    screen_set_auto_wrap(screen, false);
    screen_set_cursor_position(screen, 0, 4);
    screen_write_utf32(screen, 'X');
    screen_write_utf32(screen, 'Y');
    XCTAssertEqual(screen_cell(screen, 0, 4)->codepoint, 'Y');
    XCTAssertEqual(screen_cursor(screen)->row, 0);

    screen_clear(screen);
    screen_set_auto_wrap(screen, true);
    screen_set_cursor_position(screen, 0, 4);
    screen_write_utf32(screen, 'X');
    screen_write_utf32(screen, 'Y');
    XCTAssertEqual(screen_cell(screen, 0, 4)->codepoint, 'X');
    XCTAssertEqual(screen_cell(screen, 1, 0)->codepoint, 'Y');

    screen_clear(screen);
    screen_set_cursor_position(screen, 0, 0);

    for (int i = 0; i < 5; i++) screen_write_utf32(screen, 'A' + i);

    screen_set_cursor_position(screen, 0, 2);
    screen_set_insert_mode(screen, true);
    XCTAssertTrue(screen_insert_mode(screen));

    screen_write_utf32(screen, 'X');
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, 'A');
    XCTAssertEqual(screen_cell(screen, 0, 1)->codepoint, 'B');
    XCTAssertEqual(screen_cell(screen, 0, 2)->codepoint, 'X');
    XCTAssertEqual(screen_cell(screen, 0, 3)->codepoint, 'C');
    XCTAssertEqual(screen_cell(screen, 0, 4)->codepoint, 'D');

    screen_set_insert_mode(screen, false);
    XCTAssertFalse(screen_insert_mode(screen));

    screen_set_scroll_area(screen, 3, 5);
    screen_set_origin_mode(screen, true);
    XCTAssertTrue(screen_origin_mode(screen));

    screen_move_cursor_absolute(screen, 1, 1);
    XCTAssertEqual(screen_cursor(screen)->row, 2);
    XCTAssertEqual(screen_cursor(screen)->column, 0);

    screen_set_origin_mode(screen, false);
    XCTAssertFalse(screen_origin_mode(screen));

    screen_move_cursor_absolute(screen, 1, 1);
    XCTAssertEqual(screen_cursor(screen)->row, 0);
    XCTAssertEqual(screen_cursor(screen)->column, 0);

    free_screen(screen);
}

- (void)test_grid_hyperlink {
    screen_t *screen = init_screen(5, 5);
    const char *url = "https://apple.com";
    const char *text = "test";
    size_t length = (size_t)strlen(text);

    screen_set_link(screen, url);
    screen_write_text(screen, (const uint8_t *)text, length);
    screen_clear_link(screen);
    screen_write_utf32(screen, '?');

    for (int32_t j = 0; j < (int32_t)length; j++) {
        screen_cell_t *cell = screen_cell(screen, 0, j);

        XCTAssertEqual(strcmp(screen_link_url(screen, cell->link_id), url), 0);
    }

    screen_cell_t *cell = screen_cell(screen, 0, (int32_t)length);

    XCTAssertEqual(cell->link_id, 0);
    XCTAssertEqual(screen_link_url(screen, cell->link_id), NULL);

    free_screen(screen);
}

- (void)test_grid_layout {
    screen_t *screen = init_screen(5, 5);

    for (int i = 0; i < 6; i++) screen_write_utf32(screen, 'A');

    screen_set_grid(screen, 5, 10);
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, 'A');
    XCTAssertEqual(screen_cell(screen, 0, 5)->codepoint, 'A');
    XCTAssertEqual(screen_cell(screen, 0, 6)->codepoint, ' ');

    screen_set_grid(screen, 5, 5);
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, 'A');
    XCTAssertEqual(screen_cell(screen, 1, 0)->codepoint, 'A');
    XCTAssertEqual(screen_cell(screen, 1, 1)->codepoint, ' ');

    screen_set_scrollback_capacity(screen, 5);

    for (int k = 1; k < 6; k++) {
        screen_write_utf32(screen, '\r');
        screen_write_utf32(screen, '\n');

        for (int i = 0; i < 6; i++) screen_write_utf32(screen, 'A' + k);
    }

    screen_set_grid(screen, 10, 10);
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, 'B');
    XCTAssertEqual(screen_cell(screen, 0, 5)->codepoint, 'B');
    XCTAssertEqual(screen_cell(screen, 0, 6)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 4, 0)->codepoint, 'F');
    XCTAssertEqual(screen_cell(screen, 4, 5)->codepoint, 'F');
    XCTAssertEqual(screen_cell(screen, 4, 6)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 5, 0)->codepoint, ' ');

    screen_set_grid(screen, 5, 5);
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, 'D');
    XCTAssertEqual(screen_cell(screen, 0, 1)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 1, 0)->codepoint, 'E');
    XCTAssertEqual(screen_cell(screen, 2, 0)->codepoint, 'E');
    XCTAssertEqual(screen_cell(screen, 2, 1)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 3, 0)->codepoint, 'F');
    XCTAssertEqual(screen_cell(screen, 4, 0)->codepoint, 'F');
    XCTAssertEqual(screen_cell(screen, 4, 1)->codepoint, ' ');

    screen_write_utf32(screen, '\r');
    screen_write_utf32(screen, '\n');

    for (int i = 0; i < 4; i++) screen_write_utf32(screen, i % 2 == 0 ? 'X' : ' ');

    screen_write_utf32(screen, 0x1F4AFu);
    screen_set_grid(screen, 10, 10);
    XCTAssertEqual(screen_cell(screen, 4, 0)->codepoint, 'X');
    XCTAssertEqual(screen_cell(screen, 4, 3)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 4, 4)->codepoint, 0x1F4AFu);
    XCTAssertEqual(screen_cell(screen, 4, 5)->codepoint, 0);
    XCTAssertEqual(screen_cell(screen, 4, 6)->codepoint, ' ');

    screen_set_grid(screen, 5, 5);
    XCTAssertEqual(screen_cell(screen, 3, 0)->codepoint, 'X');
    XCTAssertEqual(screen_cell(screen, 3, 3)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 3, 4)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 4, 0)->codepoint, 0x1F4AFu);
    XCTAssertEqual(screen_cell(screen, 4, 1)->codepoint, 0);
    XCTAssertEqual(screen_cell(screen, 4, 2)->codepoint, ' ');

    free_screen(screen);
}

- (void)test_scrollback {
    screen_t *screen = init_screen(5, 5);

    screen_set_scrollback_capacity(screen, 2);

    for (int k = 0; k < 4; k++) {
        screen_set_cell(screen, 0, 0, 'A' + k, NULL);
        screen_scroll_up(screen, 1);
    }

    screen_set_viewport_offset(screen, 2);
    XCTAssertEqual(screen_viewport_row(screen, 0, NULL)[0].codepoint, 'C');
    XCTAssertEqual(screen_viewport_row(screen, 1, NULL)[0].codepoint, 'D');

    screen_set_viewport_offset(screen, 0);
    screen_set_cursor_position(screen, 0, 0);
    screen_clear(screen);

    for (int k = 0; k < 5; k++) screen_set_cell(screen, k, 0, 'A' + k, NULL);

    screen_set_cursor_position(screen, 4, 4);
    screen_write_utf32(screen, 'X');
    screen_write_utf32(screen, ' ');
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, 'B');
    XCTAssertEqual(screen_cell(screen, 3, 4)->codepoint, 'X');
    XCTAssertEqual(screen_cell(screen, 4, 0)->codepoint, ' ');

    screen_set_viewport_offset(screen, 0);
    screen_set_cursor_position(screen, 0, 0);
    screen_clear(screen);

    for (int k = 0; k < 6; k++) screen_write_utf32(screen, 'A' + k);

    screen_scroll_up(screen, 1);
    screen_set_viewport_offset(screen, 1);

    bool mutable;
    screen_cell_t *cells;

    cells = screen_viewport_row(screen, 0, &mutable);
    XCTAssertEqual(cells[0].codepoint, 'A');
    XCTAssertFalse(mutable);

    cells = screen_viewport_row(screen, 1, &mutable);
    XCTAssertEqual(cells[0].codepoint, 'F');
    XCTAssertTrue(mutable);

    free_screen(screen);
}

- (void)test_viewport {
    screen_t *screen = init_screen(5, 5);

    screen_set_scrollback_capacity(screen, 5);
    screen_scroll_up(screen, 3);
    screen_viewport_scroll(screen, 1);
    XCTAssertEqual(screen_viewport_offset(screen), 1);
    XCTAssertEqual(screen_stage_viewport_scroll(screen), 1);

    screen_viewport_scroll(screen, 999);
    XCTAssertEqual(screen_viewport_offset(screen), 3);
    XCTAssertEqual(screen_stage_viewport_scroll(screen), 2);

    free_screen(screen);
}

@end
