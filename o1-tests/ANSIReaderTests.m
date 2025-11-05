//
//  ANSIReaderTests.m
//  o1-tests
//
//  Created by grok-4 on 2025-10-14.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include "ansi.h"
#include "ansi_reader.h"

#include <stdint.h>
#include <string.h>

static void test_callback(void *, ansi_t *);

@interface ANSIReaderTests : XCTestCase

@property (nonatomic, strong) NSMutableArray<NSValue *> *output;

@end

@implementation ANSIReaderTests

- (void)setUp {
    [super setUp];
    self.output = [NSMutableArray array];
}

- (void)test_osc_capacity {
    ansi_reader_t *reader = init_ansi_reader();
    __weak typeof(self) weakSelf = self;

    ansi_reader_set_callback(reader, test_callback, (__bridge void *)weakSelf);

    const char *input = "\x1b" "]8;;https://apple.com" "\x07";

    ansi_reader_set_osc_capacity(reader, 12);
    ansi_reader_feed(reader, (const uint8_t *)input, strlen(input));

    ansi_t ansi;

    [self.output[0] getValue:&ansi];
    XCTAssertEqual(strcmp(ansi.osc.payload, ";https://"), 0);

    free_ansi_reader(reader);
}

- (void)test_callback_unknown {
    ansi_reader_t *reader = init_ansi_reader();
    __weak typeof(self) weakSelf = self;

    ansi_reader_set_callback(reader, test_callback, (__bridge void *)weakSelf);

    const char *input = "\x1b" "Z";

    ansi_reader_feed(reader, (const uint8_t *)input, 2);
    XCTAssertEqual(self.output.count, 1);

    ansi_t ansi;

    [self.output[0] getValue:&ansi];
    XCTAssertEqual(ansi.event, ANSI_EVENT_UNKNOWN);
    XCTAssertEqual(ansi.unknown.length, 2);
    XCTAssertEqual(strncmp((const char *)ansi.unknown.bytes, "\x1b" "Z", 2), 0);

    free_ansi_reader(reader);
}

- (void)test_callback_text {
    ansi_reader_t *reader = init_ansi_reader();
    __weak typeof(self) weakSelf = self;

    ansi_reader_set_callback(reader, test_callback, (__bridge void *)weakSelf);

    const char *input = "testing";

    ansi_reader_feed(reader, (const uint8_t *)input, strlen(input));
    XCTAssertEqual(self.output.count, 1);

    ansi_t ansi;

    [self.output[0] getValue:&ansi];
    XCTAssertEqual(ansi.event, ANSI_EVENT_TEXT);
    XCTAssertEqual(ansi.text.length, 7);
    XCTAssertEqual(strncmp((const char *)ansi.text.bytes, "testing", 7), 0);

    free_ansi_reader(reader);
}

- (void)test_callback_esc {
    ansi_reader_t *reader = init_ansi_reader();
    __weak typeof(self) weakSelf = self;

    ansi_reader_set_callback(reader, test_callback, (__bridge void *)weakSelf);

    const char *input =
    "\x1b" "7"
    "\x1b" "8"
    "\x1b" "c"
    "\x1b" "H"
    "\x1b" "D"
    "\x1b" "M";

    ansi_reader_feed(reader, (const uint8_t *)input, strlen(input));
    XCTAssertEqual(self.output.count, 6);

    ansi_esc_event_t expected[] = {
        ANSI_ESC_DEC_SAVE_CURSOR,
        ANSI_ESC_DEC_RESTORE_CURSOR,
        ANSI_ESC_RESET,
        ANSI_ESC_TAB_SET,
        ANSI_ESC_IND,
        ANSI_ESC_RI,
    };

    for (NSUInteger i = 0; i < self.output.count; i++) {
        ansi_t ansi;

        [self.output[i] getValue:&ansi];
        XCTAssertEqual(ansi.event, ANSI_EVENT_ESC);
        XCTAssertEqual(ansi.esc.event, expected[i]);
    }

    free_ansi_reader(reader);
}

- (void)test_callback_csi {
    ansi_reader_t *reader = init_ansi_reader();
    __weak typeof(self) weakSelf = self;

    ansi_reader_set_callback(reader, test_callback, (__bridge void *)weakSelf);

    const char *input =
    "\x1b" "[q"
    "\x1b" "[1A"
    "\x1b" "[1B"
    "\x1b" "[1C"
    "\x1b" "[1D"
    "\x1b" "[1E"
    "\x1b" "[1F"
    "\x1b" "[1G"
    "\x1b" "[1;1H"
    "\x1b" "[1;1f"
    "\x1b" "[1J"
    "\x1b" "[1K"
    "\x1b" "[?1J"
    "\x1b" "[?1K"
    "\x1b" "[1S"
    "\x1b" "[1T"
    "\x1b" "[1;2r"
    "\x1b" "[1m"
    "\x1b" "[1h"
    "\x1b" "[1l"
    "\x1b" "[?1h"
    "\x1b" "[?1l"
    "\x1b" "[1n"
    "\x1b" "[?1n"
    "\x1b" "[1c"
    "\x1b" "[1b"
    "\x1b" "[1g"
    "\x1b" "[1I"
    "\x1b" "[1O"
    "\x1b" "[200~"
    "\x1b" "[201~";

    ansi_reader_feed(reader, (const uint8_t *)input, strlen(input));
    XCTAssertEqual(self.output.count, 31);

    for (NSUInteger i = 0; i < self.output.count; i++) {
        ansi_t ansi;

        [self.output[i] getValue:&ansi];
        XCTAssertEqual(ansi.event, ANSI_EVENT_CSI);
        XCTAssertEqual(ansi.csi.event, (ansi_csi_event_t)i);
    }

    free_ansi_reader(reader);
}

- (void)test_callback_sgr {
    ansi_reader_t *reader = init_ansi_reader();
    __weak typeof(self) weakSelf = self;

    ansi_reader_set_callback(reader, test_callback, (__bridge void *)weakSelf);

    const char *input =
    "\x1b" "[0m"
    "\x1b" "[1m"
    "\x1b" "[3m"
    "\x1b" "[4m"
    "\x1b" "[38;5;7m"
    "\x1b" "[48;2;0;10;20m"
    "\x1b" "[39m"
    "\x1b" "[49m";

    ansi_reader_feed(reader, (const uint8_t *)input, strlen(input));
    XCTAssertEqual(self.output.count, 8);

    ansi_sgr_t expected[] = {
        {ANSI_SGR_FLAG_NONE, ANSI_COLOR_RESET, ANSI_COLOR_RESET},
        {ANSI_SGR_FLAG_BOLD, ANSI_COLOR_RESET, ANSI_COLOR_RESET},
        {ANSI_SGR_FLAG_ITALIC, ANSI_COLOR_RESET, ANSI_COLOR_RESET},
        {ANSI_SGR_FLAG_UNDERLINE, ANSI_COLOR_RESET, ANSI_COLOR_RESET},
        {ANSI_SGR_FLAG_NONE, ansi_color_pack_indexed(7), ANSI_COLOR_RESET},
        {ANSI_SGR_FLAG_NONE, ANSI_COLOR_RESET, ansi_color_pack_rgb(0, 10, 20)},
        {ANSI_SGR_FLAG_NONE, ANSI_COLOR_RESET, ANSI_COLOR_RESET},
        {ANSI_SGR_FLAG_NONE, ANSI_COLOR_RESET, ANSI_COLOR_RESET},
    };

    for (NSUInteger i = 0; i < self.output.count; i++) {
        ansi_t ansi;

        [self.output[i] getValue:&ansi];
        XCTAssertEqual(ansi.event, ANSI_EVENT_CSI);
        XCTAssertEqual(ansi.csi.event, ANSI_CSI_SGR);
        XCTAssertEqual(ansi.csi.attributes.flags, expected[i].flags);
        XCTAssertEqual(ansi.csi.attributes.fg_color, expected[i].fg_color);
        XCTAssertEqual(ansi.csi.attributes.bg_color, expected[i].bg_color);
    }

    free_ansi_reader(reader);
}

- (void)test_callback_mode {
    ansi_reader_t *reader = init_ansi_reader();
    __weak typeof(self) weakSelf = self;

    ansi_reader_set_callback(reader, test_callback, (__bridge void *)weakSelf);

    const char *input =
    "\x1b" "[4h"
    "\x1b" "[4l";

    ansi_reader_feed(reader, (const uint8_t *)input, strlen(input));
    XCTAssertEqual(self.output.count, 2);

    ansi_t ansi;

    [self.output[0] getValue:&ansi];
    XCTAssertEqual(ansi.event, ANSI_EVENT_CSI);
    XCTAssertEqual(ansi.csi.event, ANSI_CSI_SM);
    XCTAssertFalse(ansi.csi.dec_private);
    XCTAssertEqual(ansi.csi.mode, ANSI_MODE_INSERT);

    [self.output[1] getValue:&ansi];
    XCTAssertEqual(ansi.event, ANSI_EVENT_CSI);
    XCTAssertEqual(ansi.csi.event, ANSI_CSI_RM);
    XCTAssertFalse(ansi.csi.dec_private);
    XCTAssertEqual(ansi.csi.mode, ANSI_MODE_INSERT);

    free_ansi_reader(reader);
}

- (void)test_callback_decMode {
    ansi_reader_t *reader = init_ansi_reader();
    __weak typeof(self) weakSelf = self;

    ansi_reader_set_callback(reader, test_callback, (__bridge void *)weakSelf);

    const char *input =
    "\x1b" "[?6h"
    "\x1b" "[?1h"
    "\x1b" "[?7h"
    "\x1b" "[?12h"
    "\x1b" "[?25h"
    "\x1b" "[?1000h"
    "\x1b" "[?1002h"
    "\x1b" "[?1003h"
    "\x1b" "[?1004h"
    "\x1b" "[?1006h"
    "\x1b" "[?2004h"
    "\x1b" "[?1047h"
    "\x1b" "[?1048h"
    "\x1b" "[?1049h"
    "\x1b" "[?999h"
    "\x1b" "[?6l"
    "\x1b" "[?1l"
    "\x1b" "[?7l"
    "\x1b" "[?12l"
    "\x1b" "[?25l"
    "\x1b" "[?1000l"
    "\x1b" "[?1002l"
    "\x1b" "[?1003l"
    "\x1b" "[?1004l"
    "\x1b" "[?1006l"
    "\x1b" "[?2004l"
    "\x1b" "[?1047l"
    "\x1b" "[?1048l"
    "\x1b" "[?1049l"
    "\x1b" "[?999l";

    ansi_reader_feed(reader, (const uint8_t *)input, strlen(input));
    XCTAssertEqual(self.output.count, 30);

    ansi_dec_mode_t expected[] = {
        ANSI_DEC_MODE_ORIGIN,
        ANSI_DEC_MODE_CURSOR_KEYS,
        ANSI_DEC_MODE_AUTO_WRAP,
        ANSI_DEC_MODE_CURSOR_BLINK,
        ANSI_DEC_MODE_CURSOR_VISIBLE,
        ANSI_DEC_MODE_MOUSE_X10,
        ANSI_DEC_MODE_MOUSE_NORMAL,
        ANSI_DEC_MODE_MOUSE_ALL,
        ANSI_DEC_MODE_FOCUS_REPORTING,
        ANSI_DEC_MODE_MOUSE_SGR,
        ANSI_DEC_MODE_BRACKETED_PASTE,
        ANSI_DEC_MODE_ALTERNATE_SCREEN,
        ANSI_DEC_MODE_SAVE_CURSOR,
        ANSI_DEC_MODE_ALTERNATE_SCREEN_SAVE_CURSOR,
        ANSI_DEC_MODE_UNKNOWN,
        ANSI_DEC_MODE_ORIGIN,
        ANSI_DEC_MODE_CURSOR_KEYS,
        ANSI_DEC_MODE_AUTO_WRAP,
        ANSI_DEC_MODE_CURSOR_BLINK,
        ANSI_DEC_MODE_CURSOR_VISIBLE,
        ANSI_DEC_MODE_MOUSE_X10,
        ANSI_DEC_MODE_MOUSE_NORMAL,
        ANSI_DEC_MODE_MOUSE_ALL,
        ANSI_DEC_MODE_FOCUS_REPORTING,
        ANSI_DEC_MODE_MOUSE_SGR,
        ANSI_DEC_MODE_BRACKETED_PASTE,
        ANSI_DEC_MODE_ALTERNATE_SCREEN,
        ANSI_DEC_MODE_SAVE_CURSOR,
        ANSI_DEC_MODE_ALTERNATE_SCREEN_SAVE_CURSOR,
        ANSI_DEC_MODE_UNKNOWN,
    };

    for (NSUInteger i = 0; i < self.output.count; i++) {
        ansi_t ansi;

        [self.output[i] getValue:&ansi];
        XCTAssertEqual(ansi.event, ANSI_EVENT_CSI);
        XCTAssertTrue(ansi.csi.dec_private);

        if (i < (self.output.count / 2)) {
            XCTAssertEqual(ansi.csi.event, ANSI_CSI_DECSET);
        } else {
            XCTAssertEqual(ansi.csi.event, ANSI_CSI_DECRST);
        }

        XCTAssertEqual(ansi.csi.dec_mode, expected[i]);
    }

    free_ansi_reader(reader);
}

- (void)test_callback_osc {
    ansi_reader_t *reader = init_ansi_reader();
    __weak typeof(self) weakSelf = self;

    ansi_reader_set_callback(reader, test_callback, (__bridge void *)weakSelf);

    const char *input =
    "\x1b" "]999;unknown" "\x07"
    "\x1b" "]0;title" "\x07"
    "\x1b" "]2;title" "\x1b" "\\"
    "\x1b" "]8;;https://apple.com" "\x07"
    "\x1b" "]52;c;YmFzZTY0Cg==" "\x07";

    ansi_reader_feed(reader, (const uint8_t *)input, strlen(input));
    XCTAssertEqual(self.output.count, 5);

    ansi_osc_event_t expected[] = {
        ANSI_OSC_KIND_UNKNOWN,
        ANSI_OSC_SET_TITLE,
        ANSI_OSC_SET_TITLE,
        ANSI_OSC_HYPERLINK,
        ANSI_OSC_CLIPBOARD,
    };

    for (NSUInteger i = 0; i < self.output.count; i++) {
        ansi_t ansi;

        [self.output[i] getValue:&ansi];
        XCTAssertEqual(ansi.event, ANSI_EVENT_OSC);
        XCTAssertEqual(ansi.osc.event, expected[i]);
    }

    free_ansi_reader(reader);
}

- (void)test_callback_bell {
    ansi_reader_t *reader = init_ansi_reader();
    __weak typeof(self) weakSelf = self;

    ansi_reader_set_callback(reader, test_callback, (__bridge void *)weakSelf);

    const char *input = "\x07";

    ansi_reader_feed(reader, (const uint8_t *)input, 1);
    XCTAssertEqual(self.output.count, 1);

    ansi_t ansi;

    [self.output[0] getValue:&ansi];
    XCTAssertEqual(ansi.event, ANSI_EVENT_BELL);

    free_ansi_reader(reader);
}

- (void)test_utf8_incomplete {
    ansi_reader_t *reader = init_ansi_reader();
    __weak typeof(self) weakSelf = self;

    ansi_reader_set_callback(reader, test_callback, (__bridge void *)weakSelf);

    const uint8_t partial[] = {0xE2};

    ansi_reader_feed(reader, partial, 1);
    XCTAssertEqual(self.output.count, 0);

    const uint8_t rest[] = {0x82, 0xAC, '1', 0x07};

    ansi_reader_feed(reader, rest, 4);
    XCTAssertEqual(self.output.count, 3);

    ansi_t ansi;

    [self.output[0] getValue:&ansi];
    XCTAssertEqual(ansi.event, ANSI_EVENT_TEXT);
    XCTAssertEqual(ansi.text.length, 3);
    XCTAssertEqual(memcmp(ansi.text.bytes, "€", 3), 0);

    [self.output[1] getValue:&ansi];
    XCTAssertEqual(ansi.event, ANSI_EVENT_TEXT);
    XCTAssertEqual(ansi.text.length, 1);
    XCTAssertEqual(memcmp(ansi.text.bytes, "1", 1), 0);

    [self.output[2] getValue:&ansi];
    XCTAssertEqual(ansi.event, ANSI_EVENT_BELL);

    free_ansi_reader(reader);
}

@end

static void test_callback(void *user_data, ansi_t *ansi) {
    ANSIReaderTests *self = (__bridge ANSIReaderTests *)user_data;

    if (!self) return;

    NSValue *value = [NSValue value:ansi withObjCType:@encode(ansi_t)];
    __strong ANSIReaderTests *strongSelf = self;

    [strongSelf.output addObject:value];
}
