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
    XCTAssertEqual(unicode_codepoint_width(0x0041u), 1);
    XCTAssertEqual(unicode_codepoint_width(0x0301u), 0);
    XCTAssertEqual(unicode_codepoint_width(0x200Du), 0);
    XCTAssertEqual(unicode_codepoint_width(0x00A0u), 1);
    XCTAssertEqual(unicode_codepoint_width(0x0391u), 1);
    XCTAssertEqual(unicode_codepoint_width(0x3042u), 2);
    XCTAssertEqual(unicode_codepoint_width(0x2318u), 1);
    XCTAssertEqual(unicode_codepoint_width(0x1F4AFu), 2);
    XCTAssertEqual(unicode_codepoint_width(0x2713u), 1);
    XCTAssertEqual(unicode_codepoint_width(0xFFFDu), 1);
    XCTAssertEqual(unicode_codepoint_width(0xFFFCu), 1);
}

- (void)test_codepoint_utf8 {
    uint32_t codepoint = 0;
    const uint8_t ascii[] = {0x41u};

    XCTAssertEqual(unicode_decode_utf8(ascii, sizeof(ascii), &codepoint), 1);
    XCTAssertEqual(codepoint, 'A');

    const uint8_t wide_east_asian[] = {0xE3u, 0x81u, 0x82u};

    XCTAssertEqual(unicode_decode_utf8(wide_east_asian, sizeof(wide_east_asian), &codepoint), 3);
    XCTAssertEqual(codepoint, 0x3042u);

    const uint8_t emoji[] = {0xF0u, 0x9Fu, 0x92u, 0xAFu};

    XCTAssertEqual(unicode_decode_utf8(emoji, sizeof(emoji), &codepoint), 4);
    XCTAssertEqual(codepoint, 0x1F4AFu);

    const uint8_t incomplete[] = {0xE4u};

    codepoint = '?';
    XCTAssertEqual(unicode_decode_utf8(incomplete, sizeof(incomplete), &codepoint), 0);
    XCTAssertEqual(codepoint, '?');

    const uint8_t invalid[] = {0xE4u, 0x00u, 0xADu};

    XCTAssertEqual(unicode_decode_utf8(invalid, sizeof(invalid), &codepoint), 1);
    XCTAssertEqual(codepoint, UNICODE_REPLACEMENT);
}

- (void)test_codepoint_support {
    XCTAssertTrue(unicode_codepoint_supported(0x0041u, UNICODE_CODEPOINT_UTF8));
    XCTAssertTrue(unicode_codepoint_supported(0x0000u, UNICODE_CODEPOINT_UTF8));
    XCTAssertFalse(unicode_codepoint_supported(0x00A0u, UNICODE_CODEPOINT_UTF8));
    XCTAssertFalse(unicode_codepoint_supported(0x3042u, UNICODE_CODEPOINT_UTF8));
    XCTAssertFalse(unicode_codepoint_supported(0x1F4AFu, UNICODE_CODEPOINT_UTF8));
    XCTAssertTrue(unicode_codepoint_supported(0x00A0u, UNICODE_CODEPOINT_UTF16));
    XCTAssertTrue(unicode_codepoint_supported(0x3042u, UNICODE_CODEPOINT_UTF16));
    XCTAssertFalse(unicode_codepoint_supported(0xD800u, UNICODE_CODEPOINT_UTF16));
    XCTAssertFalse(unicode_codepoint_supported(0x1F4AFu, UNICODE_CODEPOINT_UTF16));
    XCTAssertFalse(unicode_codepoint_supported(0xD800u, UNICODE_CODEPOINT_UTF32));
    XCTAssertTrue(unicode_codepoint_supported(0x1F4AFu, UNICODE_CODEPOINT_UTF32));
    XCTAssertFalse(unicode_codepoint_supported(0x110000u, UNICODE_CODEPOINT_UTF32));
}

@end
