//
//  UnicodeTests.m
//  o1-tests
//
//  Created by grok-4 on 2025-11-17.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include "unicode.h"

@interface UnicodeTests : XCTestCase

@end

@implementation UnicodeTests

- (void)test_codepoint_width {
    XCTAssertEqual(unicode_codepoint_width('A'), 1);
    XCTAssertEqual(unicode_codepoint_width(0x0301), 0);
    XCTAssertEqual(unicode_codepoint_width(0x00A0), 1);
    XCTAssertEqual(unicode_codepoint_width(0x0391), 1);
    XCTAssertEqual(unicode_codepoint_width(0x3042), 2);
    XCTAssertEqual(unicode_codepoint_width(0x2318), 2);
}

- (void)test_codepoint_utf8 {
    uint32_t codepoint = 0;
    const uint8_t ascii[] = {'A'};

    XCTAssertEqual(unicode_decode_utf8(ascii, sizeof(ascii), &codepoint), 1);
    XCTAssertEqual(codepoint, 'A');

    const uint8_t wide_east_asian[] = {0xE3, 0x81, 0x82};

    XCTAssertEqual(unicode_decode_utf8(wide_east_asian, sizeof(wide_east_asian), &codepoint), 3);
    XCTAssertEqual(codepoint, 0x3042);

    const uint8_t emoji[] = {0xF0, 0x9F, 0x92, 0xAF};

    XCTAssertEqual(unicode_decode_utf8(emoji, sizeof(emoji), &codepoint), 4);
    XCTAssertEqual(codepoint, 0x1F4AF);

    const uint8_t incomplete[] = {0xE4};

    codepoint = '?';
    XCTAssertEqual(unicode_decode_utf8(incomplete, sizeof(incomplete), &codepoint), 0);
    XCTAssertEqual(codepoint, '?');

    const uint8_t invalid[] = {0xE4, 0x00, 0xAD};

    XCTAssertEqual(unicode_decode_utf8(invalid, sizeof(invalid), &codepoint), 1);
    XCTAssertEqual(codepoint, UNICODE_REPLACEMENT);
}

@end
