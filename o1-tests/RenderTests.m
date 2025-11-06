//
//  RenderTests.m
//  o1-tests
//
//  Created by grok-4 on 2025-11-06.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include "render.h"
#include "screen.h"

#include <stddef.h>

@interface RenderTests : XCTestCase

@end

@implementation RenderTests

- (void)test_collect_span {
    screen_t *screen = init_screen(5, 5);
    render_t *ops;
    size_t count;

    screen_set_cell(screen, 1, 1, 'X', NULL);
    screen_set_cell(screen, 1, 2, 'Y', NULL);
    screen_set_cell(screen, 1, 3, 'Z', NULL);
    render_collect_ops(&ops, screen, &count);
    XCTAssertEqual(count, 1);
    XCTAssertEqual(ops[0].op, RENDER_OP_SPAN);
    XCTAssertEqual(ops[0].span.row, 1);
    XCTAssertEqual(ops[0].span.column, 1);
    XCTAssertEqual(ops[0].span.width, 3);
    XCTAssertEqual(ops[0].span.cells[0].codepoint, 'X');
    XCTAssertEqual(ops[0].span.cells[1].codepoint, 'Y');
    XCTAssertEqual(ops[0].span.cells[2].codepoint, 'Z');

    screen_set_cell(screen, 2, 0, 'X', NULL);
    screen_set_cell(screen, 2, 1, 'Y', NULL);
    screen_set_cell(screen, 2, 4, 'Z', NULL);
    render_collect_ops(&ops, screen, &count);
    XCTAssertEqual(count, 2);
    XCTAssertEqual(ops[0].op, RENDER_OP_SPAN);
    XCTAssertEqual(ops[0].span.row, 2);
    XCTAssertEqual(ops[0].span.column, 0);
    XCTAssertEqual(ops[0].span.width, 2);
    XCTAssertEqual(ops[0].span.cells[0].codepoint, 'X');
    XCTAssertEqual(ops[0].span.cells[1].codepoint, 'Y');
    XCTAssertEqual(ops[1].op, RENDER_OP_SPAN);
    XCTAssertEqual(ops[1].span.row, 2);
    XCTAssertEqual(ops[1].span.column, 4);
    XCTAssertEqual(ops[1].span.width, 1);
    XCTAssertEqual(ops[1].span.cells[0].codepoint, 'Z');

    render_clear_ops(ops, count);
    screen_set_cell(screen, 3, 0, 'X', NULL);
    screen_set_cell(screen, 3, 1, 'Y', NULL);
    screen_set_cell(screen, 3, 3, 'Z', NULL);
    render_collect_ops(&ops, screen, &count);
    XCTAssertEqual(count, 1);
    XCTAssertEqual(ops[0].op, RENDER_OP_SPAN);
    XCTAssertEqual(ops[0].span.row, 3);
    XCTAssertEqual(ops[0].span.column, 0);
    XCTAssertEqual(ops[0].span.width, 4);
    XCTAssertEqual(ops[0].span.cells[0].codepoint, 'X');
    XCTAssertEqual(ops[0].span.cells[1].codepoint, 'Y');
    XCTAssertEqual(ops[0].span.cells[2].codepoint, ' ');
    XCTAssertEqual(ops[0].span.cells[3].codepoint, 'Z');

    render_clear_ops(ops, count);
    free_screen(screen);
}

- (void)test_collect_scroll {
    screen_t *screen = init_screen(5, 5);
    render_t *ops;
    size_t count;

    screen_scroll_up(screen, 2);
    render_collect_ops(&ops, screen, &count);
    render_clear_ops(ops, count);
    screen_set_cell(screen, 0, 1, 'X', NULL);
    screen_set_cell(screen, 0, 2, 'Y', NULL);
    screen_set_cell(screen, 2, 4, 'Z', NULL);
    screen_viewport_scroll(screen, 1);
    render_collect_ops(&ops, screen, &count);
    XCTAssertEqual(count, 3);
    XCTAssertEqual(ops[0].op, RENDER_OP_SCROLL);
    XCTAssertEqual(ops[0].scroll.top, 0);
    XCTAssertEqual(ops[0].scroll.bottom, screen_rows(screen) - 1);
    XCTAssertEqual(ops[0].scroll.delta, 1);
    XCTAssertEqual(ops[1].op, RENDER_OP_SPAN);
    XCTAssertEqual(ops[1].span.row, 1);
    XCTAssertEqual(ops[1].span.column, 1);
    XCTAssertEqual(ops[1].span.width, 2);
    XCTAssertEqual(ops[1].span.cells[0].codepoint, 'X');
    XCTAssertEqual(ops[1].span.cells[1].codepoint, 'Y');
    XCTAssertEqual(ops[2].op, RENDER_OP_SPAN);
    XCTAssertEqual(ops[2].span.row, 3);
    XCTAssertEqual(ops[2].span.column, 4);
    XCTAssertEqual(ops[2].span.width, 1);
    XCTAssertEqual(ops[2].span.cells[0].codepoint, 'Z');

    render_clear_ops(ops, count);
    screen_viewport_scroll(screen, -1);
    render_collect_ops(&ops, screen, &count);
    XCTAssertEqual(count, 1);
    XCTAssertEqual(ops[0].op, RENDER_OP_SCROLL);
    XCTAssertEqual(ops[0].scroll.top, 0);
    XCTAssertEqual(ops[0].scroll.bottom, screen_rows(screen) - 1);
    XCTAssertEqual(ops[0].scroll.delta, -1);

    render_clear_ops(ops, count);
    free_screen(screen);
}

@end
