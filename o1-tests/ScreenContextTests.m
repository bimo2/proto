//
//  ScreenContextTests.m
//  o1-tests
//
//  Created by grok-4 on 2025-11-06.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include "ansi.h"
#include "screen.h"
#include "screen_context.h"

#include <string.h>

static void test_response_callback(void *, const char *);
static void test_title_callback(void *, const char *);
static void test_bell_callback(void *);
static void test_mouse_callback(void *, bool);

@interface ScreenContextTests : XCTestCase

@property (nonatomic, strong) NSString *response;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, assign) NSUInteger bells;
@property (nonatomic, assign, getter=isMouseEnabled) BOOL mouseEnabled;

@end

@implementation ScreenContextTests

- (void)setUp {
    [super setUp];
    self.response = nil;
    self.title = nil;
    self.bells = 0;
    self.mouseEnabled = false;
    screen_default_offset = 0;
}

- (void)test_codepoint_dynamic {
    screen_context_t *context = init_screen_context();
    screen_t *screen = screen_context_current_screen(context);

    screen_context_set_codepoint(context, UNICODE_CODEPOINT_DYNAMIC);

    const uint8_t utf8[] = {0x41u};

    ansi_t text = {
        .event = ANSI_EVENT_TEXT,
        .text = {
            .bytes = utf8,
            .length = sizeof(utf8),
        },
    };

    screen_context_update(context, &text);
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, 0x0041u);

    const uint8_t utf16[] = {0xE2u, 0x82u, 0xACu};

    text.text.bytes = utf16;
    text.text.length = sizeof(utf16);
    screen_context_update(context, &text);
    XCTAssertEqual(screen_cell(screen, 0, 1)->codepoint, 0x20ACu);

    const uint8_t utf32[] = {0xF0u, 0x9Fu, 0x92u, 0xAFu};

    text.text.bytes = utf32;
    text.text.length = sizeof(utf32);
    screen_context_update(context, &text);
    XCTAssertEqual(screen_cell(screen, 0, 2)->codepoint, 0x1F4AFu);

    free_screen_context(context);
}

- (void)test_codepoint_utf8 {
    screen_context_t *context = init_screen_context();
    screen_t *screen = screen_context_current_screen(context);

    screen_context_set_codepoint(context, UNICODE_CODEPOINT_UTF8);

    const uint8_t utf8[] = {0x41u};

    ansi_t text = {
        .event = ANSI_EVENT_TEXT,
        .text = {
            .bytes = utf8,
            .length = sizeof(utf8),
        },
    };

    screen_context_update(context, &text);
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, 0x0041u);

    const uint8_t utf16[] = {0xE2u, 0x82u, 0xACu};

    text.text.bytes = utf16;
    text.text.length = sizeof(utf16);
    screen_context_update(context, &text);
    XCTAssertEqual(screen_cell(screen, 0, 1)->codepoint, 'U');
    XCTAssertEqual(screen_cell(screen, 0, 2)->codepoint, '+');
    XCTAssertEqual(screen_cell(screen, 0, 3)->codepoint, '2');
    XCTAssertEqual(screen_cell(screen, 0, 4)->codepoint, '0');
    XCTAssertEqual(screen_cell(screen, 0, 5)->codepoint, 'A');
    XCTAssertEqual(screen_cell(screen, 0, 6)->codepoint, 'C');

    free_screen_context(context);
}

- (void)test_codepoint_utf16 {
    screen_context_t *context = init_screen_context();
    screen_t *screen = screen_context_current_screen(context);

    screen_context_set_codepoint(context, UNICODE_CODEPOINT_UTF16);

    const uint8_t utf16[] = {0xE2u, 0x82u, 0xACu};

    ansi_t text = {
        .event = ANSI_EVENT_TEXT,
        .text = {
            .bytes = utf16,
            .length = sizeof(utf16),
        },
    };

    screen_context_update(context, &text);
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, 0x20ACu);

    const uint8_t utf32[] = {0xF0u, 0x9Fu, 0x92u, 0xAFu};

    text.text.bytes = utf32;
    text.text.length = sizeof(utf32);
    screen_context_update(context, &text);
    XCTAssertEqual(screen_cell(screen, 0, 1)->codepoint, 'U');
    XCTAssertEqual(screen_cell(screen, 0, 2)->codepoint, '+');
    XCTAssertEqual(screen_cell(screen, 0, 3)->codepoint, '1');
    XCTAssertEqual(screen_cell(screen, 0, 4)->codepoint, 'F');
    XCTAssertEqual(screen_cell(screen, 0, 5)->codepoint, '4');
    XCTAssertEqual(screen_cell(screen, 0, 6)->codepoint, 'A');
    XCTAssertEqual(screen_cell(screen, 0, 7)->codepoint, 'F');

    free_screen_context(context);
}

- (void)test_codepoint_utf32 {
    screen_context_t *context = init_screen_context();
    screen_t *screen = screen_context_current_screen(context);

    screen_context_set_codepoint(context, UNICODE_CODEPOINT_UTF32);

    const uint8_t utf32[] = {0xF0u, 0x9Fu, 0x92u, 0xAFu};

    ansi_t text = {
        .event = ANSI_EVENT_TEXT,
        .text = {
            .bytes = utf32,
            .length = sizeof(utf32),
        },
    };

    screen_context_update(context, &text);
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, 0x1F4AFu);

    free_screen_context(context);
}

- (void)test_update_text {
    screen_context_t *context = init_screen_context();
    screen_t *screen = screen_context_current_screen(context);
    const uint8_t bytes[] = {'X', 'Y', 'Z'};

    ansi_t ansi = {
        .event = ANSI_EVENT_TEXT,
        .text = {
            .bytes = bytes,
            .length = sizeof(bytes),
        },
    };

    screen_context_update(context, &ansi);
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, 'X');
    XCTAssertEqual(screen_cell(screen, 0, 1)->codepoint, 'Y');
    XCTAssertEqual(screen_cell(screen, 0, 2)->codepoint, 'Z');

    ansi_t repeat = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .parameters = {2},
            .parameters_count = 1,
            .event = ANSI_CSI_REP,
        },
    };

    screen_context_update(context, &repeat);
    XCTAssertEqual(screen_cell(screen, 0, 3)->codepoint, 'Z');
    XCTAssertEqual(screen_cell(screen, 0, 4)->codepoint, 'Z');
    XCTAssertEqual(screen_cell(screen, 0, 5)->codepoint, ' ');

    free_screen_context(context);
}

- (void)test_update_tabs {
    screen_context_t *context = init_screen_context();
    screen_t *screen = screen_context_current_screen(context);

    screen_move_cursor_absolute(screen, 1, 4);

    ansi_t tab_set = {
        .event = ANSI_EVENT_ESC,
        .esc = {
            .event = ANSI_ESC_TAB_SET,
        },
    };

    screen_context_update(context, &tab_set);
    screen_move_cursor_absolute(screen, 1, 1);

    const uint8_t byte = '\t';

    ansi_t tab = {
        .event = ANSI_EVENT_TEXT,
        .text = {
            .bytes = &byte,
            .length = sizeof(byte),
        },
    };

    screen_context_update(context, &tab);
    XCTAssertEqual(screen_cursor(screen)->column, 3);

    ansi_t clear = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .parameters = {0},
            .parameters_count = 1,
            .event = ANSI_CSI_TBC,
        },
    };

    screen_context_update(context, &clear);
    screen_move_cursor_absolute(screen, 1, 1);
    screen_context_update(context, &tab);
    XCTAssertEqual(screen_cursor(screen)->column, 8);

    clear.csi.parameters[0] = 2;
    screen_context_update(context, &clear);
    screen_context_update(context, &tab);
    XCTAssertEqual(screen_cursor(screen)->column, screen_default_columns - 1);

    free_screen_context(context);
}

- (void)test_update_cursor {
    screen_context_t *context = init_screen_context();
    screen_context_set_grid(context, 5, 5);
    screen_t *screen = screen_context_current_screen(context);

    screen_move_cursor_absolute(screen, 2, 3);

    ansi_t save = {
        .event = ANSI_EVENT_ESC,
        .esc = {
            .event = ANSI_ESC_DEC_SAVE_CURSOR,
        },
    };

    screen_context_update(context, &save);
    screen_move_cursor_absolute(screen, 1, 1);

    ansi_t restore = {
        .event = ANSI_EVENT_ESC,
        .esc = {
            .event = ANSI_ESC_DEC_RESTORE_CURSOR,
        },
    };

    screen_context_update(context, &restore);
    XCTAssertEqual(screen_cursor(screen)->row, 1);
    XCTAssertEqual(screen_cursor(screen)->column, 2);

    ansi_t position = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .parameters = {3, 4},
            .parameters_count = 2,
            .event = ANSI_CSI_CUP,
        },
    };

    screen_context_update(context, &position);
    XCTAssertEqual(screen_cursor(screen)->row, 2);
    XCTAssertEqual(screen_cursor(screen)->column, 3);

    ansi_t up = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .parameters = {2},
            .parameters_count = 1,
            .event = ANSI_CSI_CUU,
        },
    };

    screen_context_update(context, &up);
    XCTAssertEqual(screen_cursor(screen)->row, 0);
    XCTAssertEqual(screen_cursor(screen)->column, 3);

    ansi_t back = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .parameters = {1},
            .parameters_count = 1,
            .event = ANSI_CSI_CUB,
        },
    };

    screen_context_update(context, &back);
    XCTAssertEqual(screen_cursor(screen)->row, 0);
    XCTAssertEqual(screen_cursor(screen)->column, 2);

    ansi_t next = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .parameters = {2},
            .parameters_count = 1,
            .event = ANSI_CSI_CNL,
        },
    };

    screen_context_update(context, &next);
    XCTAssertEqual(screen_cursor(screen)->row, 2);
    XCTAssertEqual(screen_cursor(screen)->column, 0);

    ansi_t previous = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .parameters = {1},
            .parameters_count = 1,
            .event = ANSI_CSI_CPL,
        },
    };

    screen_context_update(context, &previous);
    XCTAssertEqual(screen_cursor(screen)->row, 1);
    XCTAssertEqual(screen_cursor(screen)->column, 0);

    ansi_t horizontal = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .parameters = {3},
            .parameters_count = 1,
            .event = ANSI_CSI_CHA,
        },
    };

    screen_context_update(context, &horizontal);
    XCTAssertEqual(screen_cursor(screen)->row, 1);
    XCTAssertEqual(screen_cursor(screen)->column, 2);

    free_screen_context(context);
}

- (void)test_update_display {
    screen_context_t *context = init_screen_context();
    screen_t *screen = screen_context_current_screen(context);

    screen_set_cell(screen, 0, 0, 'X', NULL);
    screen_set_cell(screen, 0, 1, 'X', NULL);
    screen_set_cell(screen, 1, 0, 'X', NULL);
    screen_set_cell(screen, 1, 4, 'X', NULL);
    screen_set_cell(screen, 2, 2, 'X', NULL);
    screen_move_cursor_absolute(screen, 2, 3);

    ansi_t line = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .parameters = {0},
            .parameters_count = 1,
            .event = ANSI_CSI_EL,
        },
    };

    screen_context_update(context, &line);
    XCTAssertEqual(screen_cell(screen, 1, 2)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 1, 3)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 1, 4)->codepoint, ' ');

    screen_set_cell(screen, 0, 4, 'X', NULL);
    screen_set_cell(screen, 1, 1, 'X', NULL);

    ansi_t display = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .parameters = {1},
            .parameters_count = 1,
            .event = ANSI_CSI_ED,
        },
    };

    screen_context_update(context, &display);
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 0, 4)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 1, 0)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 1, 1)->codepoint, ' ');

    ansi_t dec_display = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .parameters = {2},
            .parameters_count = 1,
            .event = ANSI_CSI_DECSED,
        },
    };

    screen_context_update(context, &dec_display);

    for (int i = 0; i < screen_default_rows; i++) {
        for (int j = 0; j < screen_default_columns; j++) XCTAssertEqual(screen_cell(screen, i, j)->codepoint, ' ');
    }

    screen_set_cell(screen, 2, 0, 'X', NULL);
    screen_move_cursor_absolute(screen, 3, 3);

    ansi_t dec_line = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .parameters = {2},
            .parameters_count = 1,
            .event = ANSI_CSI_DECSEL,
        },
    };

    screen_context_update(context, &dec_line);

    for (int j = 0; j < screen_default_columns; j++) XCTAssertEqual(screen_cell(screen, 2, j)->codepoint, ' ');

    free_screen_context(context);
}

- (void)test_update_scroll {
    screen_context_t *context = init_screen_context();
    screen_t *screen = screen_context_current_screen(context);

    for (int i = 0; i < 5; i++) screen_set_cell(screen, i, 0, '0' + i, NULL);

    ansi_t up = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .parameters = {2},
            .parameters_count = 1,
            .event = ANSI_CSI_SU,
        },
    };

    screen_context_update(context, &up);
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, '2');
    XCTAssertEqual(screen_cell(screen, 1, 0)->codepoint, '3');
    XCTAssertEqual(screen_cell(screen, 2, 0)->codepoint, '4');
    XCTAssertEqual(screen_cell(screen, 3, 0)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 4, 0)->codepoint, ' ');

    ansi_t down = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .parameters = {1},
            .parameters_count = 1,
            .event = ANSI_CSI_SD,
        },
    };

    screen_context_update(context, &down);
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 1, 0)->codepoint, '2');

    ansi_t index = {
        .event = ANSI_EVENT_ESC,
        .esc = {
            .event = ANSI_ESC_IND,
        },
    };

    screen_context_update(context, &index);
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 1, 0)->codepoint, '2');

    ansi_t reverse_index = {
        .event = ANSI_EVENT_ESC,
        .esc = {
            .event = ANSI_ESC_RI,
        },
    };

    screen_context_update(context, &reverse_index);
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 1, 0)->codepoint, '2');

    ansi_t margin = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .parameters = {2, 4},
            .parameters_count = 2,
            .event = ANSI_CSI_DECSTBM,
        },
    };

    screen_context_update(context, &margin);

    for (int i = 0; i < 5; i++) screen_set_cell(screen, i, 0, 'A' + i, NULL);

    screen_context_update(context, &up);
    XCTAssertEqual(screen_cell(screen, 0, 0)->codepoint, 'A');
    XCTAssertEqual(screen_cell(screen, 1, 0)->codepoint, 'D');
    XCTAssertEqual(screen_cell(screen, 2, 0)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 3, 0)->codepoint, ' ');
    XCTAssertEqual(screen_cell(screen, 4, 0)->codepoint, 'E');

    free_screen_context(context);
}

- (void)test_update_mode {
    screen_context_t *context = init_screen_context();
    screen_t *screen = screen_context_current_screen(context);
    __weak typeof(self) weakSelf = self;

    screen_context_set_mouse_callback(context, test_mouse_callback, (__bridge void *)weakSelf);

    ansi_t insert = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .event = ANSI_CSI_SM,
            .mode = ANSI_MODE_INSERT,
        },
    };

    screen_context_update(context, &insert);
    XCTAssertTrue(screen_insert_mode(screen));

    insert.csi.event = ANSI_CSI_RM;
    screen_context_update(context, &insert);
    XCTAssertFalse(screen_insert_mode(screen));

    ansi_t dec_set = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .event = ANSI_CSI_DECSET,
        },
    };

    dec_set.csi.dec_mode = ANSI_DEC_MODE_ORIGIN;
    screen_context_update(context, &dec_set);
    XCTAssertTrue(screen_origin_mode(screen));

    dec_set.csi.dec_mode = ANSI_DEC_MODE_AUTO_WRAP;
    screen_context_update(context, &dec_set);
    XCTAssertTrue(screen_auto_wrap(screen));

    dec_set.csi.dec_mode = ANSI_DEC_MODE_CURSOR_BLINK;
    screen_context_update(context, &dec_set);
    XCTAssertTrue(screen_cursor(screen)->blink);

    dec_set.csi.dec_mode = ANSI_DEC_MODE_CURSOR_VISIBLE;
    screen_context_update(context, &dec_set);
    XCTAssertTrue(screen_cursor(screen)->visible);

    dec_set.csi.dec_mode = ANSI_DEC_MODE_CURSOR_KEYS;
    screen_context_update(context, &dec_set);
    XCTAssertTrue(screen_context_cursor_keys(context));

    dec_set.csi.dec_mode = ANSI_DEC_MODE_MOUSE_X10;
    screen_context_update(context, &dec_set);
    XCTAssertEqual(screen_context_mouse_mode(context), SCREEN_CONTEXT_MOUSE_X10);
    XCTAssertFalse(self.isMouseEnabled);

    dec_set.csi.dec_mode = ANSI_DEC_MODE_MOUSE_NORMAL;
    screen_context_update(context, &dec_set);
    XCTAssertEqual(screen_context_mouse_mode(context), SCREEN_CONTEXT_MOUSE_NORMAL);
    XCTAssertTrue(self.isMouseEnabled);

    dec_set.csi.dec_mode = ANSI_DEC_MODE_MOUSE_ALL;
    screen_context_update(context, &dec_set);
    XCTAssertEqual(screen_context_mouse_mode(context), SCREEN_CONTEXT_MOUSE_ALL);
    XCTAssertTrue(self.isMouseEnabled);

    dec_set.csi.dec_mode = ANSI_DEC_MODE_FOCUS_REPORTING;
    screen_context_update(context, &dec_set);
    XCTAssertTrue(screen_context_focus_reporting(context));

    dec_set.csi.dec_mode = ANSI_DEC_MODE_MOUSE_SGR;
    screen_context_update(context, &dec_set);
    XCTAssertTrue(screen_context_mouse_sgr(context));

    dec_set.csi.dec_mode = ANSI_DEC_MODE_BRACKETED_PASTE;
    screen_context_update(context, &dec_set);
    XCTAssertTrue(screen_context_bracketed_paste(context));

    screen_move_cursor_absolute(screen, 2, 3);
    XCTAssertEqual(screen_cursor(screen)->row, 1);
    XCTAssertEqual(screen_cursor(screen)->column, 2);

    dec_set.csi.dec_mode = ANSI_DEC_MODE_ALTERNATE_SCREEN_SAVE_CURSOR;
    screen_context_update(context, &dec_set);
    XCTAssertTrue(screen_context_current_screen(context) != screen);

    ansi_t dec_reset = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .event = ANSI_CSI_DECRST,
        },
    };

    dec_reset.csi.dec_mode = ANSI_DEC_MODE_ALTERNATE_SCREEN_SAVE_CURSOR;
    screen_context_update(context, &dec_reset);
    XCTAssertTrue(screen_context_current_screen(context) == screen);
    XCTAssertEqual(screen_cursor(screen)->row, 1);
    XCTAssertEqual(screen_cursor(screen)->column, 2);

    dec_reset.csi.dec_mode = ANSI_DEC_MODE_ORIGIN;
    screen_context_update(context, &dec_reset);
    XCTAssertFalse(screen_origin_mode(screen));

    dec_reset.csi.dec_mode = ANSI_DEC_MODE_AUTO_WRAP;
    screen_context_update(context, &dec_reset);
    XCTAssertFalse(screen_auto_wrap(screen));

    dec_reset.csi.dec_mode = ANSI_DEC_MODE_CURSOR_BLINK;
    screen_context_update(context, &dec_reset);
    XCTAssertFalse(screen_cursor(screen)->blink);

    dec_reset.csi.dec_mode = ANSI_DEC_MODE_CURSOR_VISIBLE;
    screen_context_update(context, &dec_reset);
    XCTAssertFalse(screen_cursor(screen)->visible);

    dec_reset.csi.dec_mode = ANSI_DEC_MODE_MOUSE_NORMAL;
    screen_context_update(context, &dec_reset);
    XCTAssertEqual(screen_context_mouse_mode(context), SCREEN_CONTEXT_MOUSE_NONE);
    XCTAssertFalse(self.isMouseEnabled);

    dec_reset.csi.dec_mode = ANSI_DEC_MODE_MOUSE_ALL;
    screen_context_update(context, &dec_reset);
    XCTAssertEqual(screen_context_mouse_mode(context), SCREEN_CONTEXT_MOUSE_NONE);
    XCTAssertFalse(self.isMouseEnabled);

    dec_reset.csi.dec_mode = ANSI_DEC_MODE_FOCUS_REPORTING;
    screen_context_update(context, &dec_reset);
    XCTAssertFalse(screen_context_focus_reporting(context));

    dec_reset.csi.dec_mode = ANSI_DEC_MODE_MOUSE_SGR;
    screen_context_update(context, &dec_reset);
    XCTAssertFalse(screen_context_mouse_sgr(context));

    dec_reset.csi.dec_mode = ANSI_DEC_MODE_BRACKETED_PASTE;
    screen_context_update(context, &dec_reset);
    XCTAssertFalse(screen_context_bracketed_paste(context));

    dec_reset.csi.dec_mode = ANSI_DEC_MODE_CURSOR_KEYS;
    screen_context_update(context, &dec_reset);
    XCTAssertFalse(screen_context_cursor_keys(context));

    free_screen_context(context);
}

- (void)test_update_device {
    screen_context_t *context = init_screen_context();
    screen_t *screen = screen_context_current_screen(context);
    __weak typeof(self) weakSelf = self;

    screen_context_set_response_callback(context, test_response_callback, (__bridge void *)weakSelf);

    ansi_t status = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .dec_private = false,
            .parameters = {5},
            .parameters_count = 1,
            .event = ANSI_CSI_DSR,
        },
    };

    screen_context_update(context, &status);
    XCTAssertEqualObjects(self.response, @"\x1b[0n");

    screen_move_cursor_absolute(screen, 2, 4);
    status.csi.dec_private = true;
    status.csi.parameters[0] = 6;
    status.csi.event = ANSI_CSI_DECDSR;
    screen_context_update(context, &status);
    XCTAssertEqualObjects(self.response, @"\x1b[2;4R");

    ansi_t attributes = {
        .event = ANSI_EVENT_CSI,
        .csi = {
            .event = ANSI_CSI_DA,
        },
    };

    screen_context_update(context, &attributes);
    XCTAssertEqualObjects(self.response, @"\x1b[?1;2c");

    free_screen_context(context);
}

- (void)test_update_title {
    screen_context_t *context = init_screen_context();
    __weak typeof(self) weakSelf = self;

    screen_context_set_title_callback(context, test_title_callback, (__bridge void *)weakSelf);

    ansi_t title = {
        .event = ANSI_EVENT_OSC,
        .osc = {
            .payload = "o1",
            .event = ANSI_OSC_SET_TITLE,
        },
    };

    screen_context_update(context, &title);
    XCTAssertEqual(strcmp(screen_context_title(context), "o1"), 0);
    XCTAssertEqualObjects(self.title, @"o1");

    free_screen_context(context);
}

- (void)test_update_hyperlink {
    screen_context_t *context = init_screen_context();
    screen_t *screen = screen_context_current_screen(context);

    ansi_t hyperlink = {
        .event = ANSI_EVENT_OSC,
        .osc = {
            .payload = "test=1;https://apple.com",
            .event = ANSI_OSC_HYPERLINK,
        },
    };

    screen_context_update(context, &hyperlink);
    XCTAssertNotEqual(screen_link_id(screen), 0);
    XCTAssertEqual(strcmp(screen_link_url(screen, screen_link_id(screen)), "https://apple.com"), 0);

    hyperlink.osc.payload = NULL;
    screen_context_update(context, &hyperlink);
    XCTAssertEqual(screen_link_id(screen), 0);

    free_screen_context(context);
}

- (void)test_update_bell {
    screen_context_t *context = init_screen_context();
    __weak typeof(self) weakSelf = self;

    screen_context_set_bell_callback(context, test_bell_callback, (__bridge void *)weakSelf);

    ansi_t bell = {
        .event = ANSI_EVENT_BELL,
    };

    screen_context_update(context, &bell);
    XCTAssertEqual(self.bells, 1);

    free_screen_context(context);
}

@end

static void test_response_callback(void *user_data, const char *response) {
    ScreenContextTests *self = (__bridge ScreenContextTests *)user_data;

    if (!self) return;

    __strong ScreenContextTests *strongSelf = self;

    strongSelf.response = [NSString stringWithUTF8String:response];
}

static void test_title_callback(void *user_data, const char *title) {
    ScreenContextTests *self = (__bridge ScreenContextTests *)user_data;

    if (!self) return;

    __strong ScreenContextTests *strongSelf = self;

    strongSelf.title = [NSString stringWithUTF8String:title];
}

static void test_bell_callback(void *user_data) {
    ScreenContextTests *self = (__bridge ScreenContextTests *)user_data;

    if (!self) return;

    __strong ScreenContextTests *strongSelf = self;

    strongSelf.bells++;
}

static void test_mouse_callback(void *user_data, bool enabled) {
    ScreenContextTests *self = (__bridge ScreenContextTests *)user_data;

    if (!self) return;

    __strong ScreenContextTests *strongSelf = self;

    strongSelf.mouseEnabled = enabled;
}
