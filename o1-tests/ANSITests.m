//
//  ANSITests.m
//  o1-tests
//
//  Created by grok-4 on 2025-10-29.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include "ansi.h"

#include <stddef.h>
#include <stdint.h>
#include <string.h>

@interface ANSITests : XCTestCase

@end

@implementation ANSITests

- (void)test_color_indexed {
    int unpacked = -1;
    uint32_t color = ansi_color_pack_indexed(40);
    ansi_color_t kind = ansi_color_unpack(color, &unpacked, NULL, NULL, NULL);

    XCTAssertEqual(kind, ANSI_COLOR_INDEXED);
    XCTAssertEqual(unpacked, 40);
}

- (void)test_color_rgb {
    uint8_t red = 0;
    uint8_t green = 0;
    uint8_t blue = 0;
    uint32_t color = ansi_color_pack_rgb(0, 10, 20);
    ansi_color_t kind = ansi_color_unpack(color, NULL, &red, &green, &blue);

    XCTAssertEqual(kind, ANSI_COLOR_RGB);
    XCTAssertEqual(red, 0);
    XCTAssertEqual(green, 10);
    XCTAssertEqual(blue, 20);
}

- (void)test_mouse_x10 {
    uint8_t bytes[64];
    size_t length = ansi_mouse_x10(ANSI_MOUSE_LEFT, ANSI_MOUSE_EVENT_DOWN, 0, 10, 20, false, bytes, sizeof(bytes));

    XCTAssertEqual(length, 6);
    XCTAssertEqual(bytes[0], 0x1B);
    XCTAssertEqual(bytes[1], '[');
    XCTAssertEqual(bytes[2], 'M');
    XCTAssertEqual(bytes[3], 0);
    XCTAssertEqual(bytes[4], 10 + 32);
    XCTAssertEqual(bytes[5], 20 + 32);

    size_t zero = ansi_mouse_x10(ANSI_MOUSE_LEFT, ANSI_MOUSE_EVENT_UP, 0, 10, 20, false, bytes, sizeof(bytes));

    XCTAssertEqual(zero, 0);
}

- (void)test_mouse_normal {
    uint8_t bytes[64];
    size_t length = ansi_mouse_normal(ANSI_MOUSE_LEFT, ANSI_MOUSE_EVENT_DRAG, 0, 10, 20, false, bytes, sizeof(bytes));

    XCTAssertEqual(length, 6);
    XCTAssertEqual(bytes[0], 0x1B);
    XCTAssertEqual(bytes[1], '[');
    XCTAssertEqual(bytes[2], 'M');
    XCTAssertEqual(bytes[3], 0 | 32);
    XCTAssertEqual(bytes[4], 10 + 32);
    XCTAssertEqual(bytes[5], 20 + 32);

    size_t zero = ansi_mouse_normal(ANSI_MOUSE_LEFT, ANSI_MOUSE_EVENT_MOVE, 0, 10, 20, false, bytes, sizeof(bytes));

    XCTAssertEqual(zero, 0);
}

- (void)test_mouse_allSGR {
    uint8_t bytes[64];
    size_t length;

    uint8_t down[] = "\x1b[<0;10;20M";

    length = ansi_mouse_all(ANSI_MOUSE_LEFT, ANSI_MOUSE_EVENT_DOWN, 0, 10, 20, true, bytes, sizeof(bytes));
    XCTAssertEqual(length, sizeof(down) - 1);
    XCTAssertEqual(memcmp(bytes, down, sizeof(down) - 1), 0);

    uint8_t up[] = "\x1b[<3;10;20m";

    length = ansi_mouse_all(ANSI_MOUSE_LEFT, ANSI_MOUSE_EVENT_UP, 0, 10, 20, true, bytes, sizeof(bytes));
    XCTAssertEqual(length, sizeof(up) - 1);
    XCTAssertEqual(memcmp(bytes, up, sizeof(up) - 1), 0);

    uint8_t flag[] = "\x1b[<8;10;20M";

    length = ansi_mouse_all(ANSI_MOUSE_LEFT, ANSI_MOUSE_EVENT_DOWN, ANSI_MOUSE_MODIFIER_FLAG_OPTION, 10, 20, true, bytes, sizeof(bytes));
    XCTAssertEqual(length, sizeof(flag) - 1);
    XCTAssertEqual(memcmp(bytes, flag, sizeof(flag) - 1), 0);

    uint8_t wheel[] = "\x1b[<64;10;20M";

    length = ansi_mouse_all(ANSI_MOUSE_WHEEL_UP, ANSI_MOUSE_EVENT_DOWN, 0, 10, 20, true, bytes, sizeof(bytes));
    XCTAssertEqual(length, sizeof(wheel) - 1);
    XCTAssertEqual(memcmp(bytes, wheel, sizeof(wheel) - 1), 0);

    size_t zero = ansi_mouse_all(ANSI_MOUSE_WHEEL_UP, ANSI_MOUSE_EVENT_UP, 0, 10, 20, true, bytes, sizeof(bytes));

    XCTAssertEqual(zero, 0);
}

@end
