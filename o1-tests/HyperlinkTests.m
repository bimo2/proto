//
//  HyperlinkTests.m
//  o1-tests
//
//  Created by grok-4.7-high-fast on 2026-10-02.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include "hyperlink.h"
#include "screen.h"

#include <string.h>

@interface HyperlinkTests : XCTestCase

@end

@implementation HyperlinkTests

- (void)test_search_osc {
    const char *value = "https://example.com?osc=8";
    const char *label = "OSC 8";
    screen_t *screen = init_screen(5, 10);

    screen_set_link(screen, value);
    screen_write_text(screen, (const uint8_t *)label, strlen(label));
    screen_clear_link(screen);

    int32_t first = screen_viewport_index(screen) + (int32_t)screen_default_offset;
    int32_t last = screen_viewport_index(screen) + screen_rows(screen) - 1;
    hyperlink_t *links = NULL;
    size_t count = 0;

    hyperlink_search(&links, screen, first, last, &count);
    XCTAssertEqual(count, 1);
    XCTAssertEqual(strcmp(links[0].value, value), 0);
    XCTAssertEqual(links[0].end - links[0].start, (int32_t)strlen(label));

    hyperlink_clear(links, count);
    free_screen(screen);
}

- (void)test_search_text {
    const char *value = "o1://127.0.0.1/";
    screen_t *screen = init_screen(5, 10);

    screen_write_text(screen, (const uint8_t *)value, strlen(value));

    int32_t first = screen_viewport_index(screen) + (int32_t)screen_default_offset;
    int32_t last = screen_viewport_index(screen) + screen_rows(screen) - 1;
    hyperlink_t *links = NULL;
    size_t count = 0;

    hyperlink_search(&links, screen, first, last, &count);
    XCTAssertGreaterThan(count, 1);

    size_t cells = 0;

    for (size_t index = 0; index < count; index++) {
        XCTAssertEqual(strcmp(links[index].value, value), 0);

        cells += (size_t)(links[index].end - links[index].start);
    }

    XCTAssertEqual(cells, strlen(value));

    hyperlink_clear(links, count);
    free_screen(screen);
}

@end
