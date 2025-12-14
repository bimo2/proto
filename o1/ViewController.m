//
//  ViewController.m
//  o1
//
//  Created by grok-code-fast-1 on 2025-10-10.
//

#import "ViewController.h"

#import "Terminal.h"
#import "TerminalView.h"

#include "render.h"
#include "screen.h"

#include <dispatch/dispatch.h>

@interface ViewController ()

@property (nonatomic, strong) Terminal *terminal;

@end

@implementation ViewController

- (void)dealloc {
    [_terminal stop];
}

- (void)loadView {
    NSRect frame = NSMakeRect(0, 0, 575, 375);
    TerminalView *terminalView = [[TerminalView alloc] initWithFrame:frame];

    self.view = terminalView;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.terminal = [[Terminal alloc] init];
    self.terminal.file = @"/bin/zsh";

    __weak typeof(self) weakSelf = self;

    self.terminal.renderBlock = ^(const render_t *ops, size_t count) {
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        [(TerminalView *)strongSelf.view render:ops count:count];

        for (size_t i = 0; i < count; i++) {
            const render_t *diff = &ops[i];

            switch (diff->op) {
                case RENDER_OP_SPAN: {
                    NSMutableString *text = [NSMutableString stringWithCapacity:diff->span.width];

                    for (int32_t i = 0; i < diff->span.width; i++) {
                        uint32_t codepoint = diff->span.cells[i].codepoint;

                        if (codepoint == 0) codepoint = ' ';

                        if (codepoint <= 0xFFFFu) {
                            [text appendFormat:@"%C", (unichar)codepoint];
                        } else {
                            [text appendString:@"?"];
                        }
                    }

                    NSLog(@"render: (span row = %d, column = %d width = %zu)\n\"%@\"", diff->span.row, diff->span.column, diff->span.width, text);

                    break;
                }
                case RENDER_OP_SCROLL:
                    NSLog(@"render: (scroll top = %d, bottom = %d, change = %d)", diff->scroll.top, diff->scroll.bottom, diff->scroll.delta);

                    break;
            }
        }
    };

    self.terminal.updateBlock = ^(screen_t *screen) {
        int32_t rows = screen_rows(screen);
        int32_t columns = screen_columns(screen);
        screen_cursor_t *cursor = screen_cursor(screen);
        NSMutableString *grid = [NSMutableString stringWithCapacity:rows * (columns + 1)];

        for (int32_t row = 0; row < rows; row++) {
            for (int32_t column = 0; column < columns; column++) {
                if (cursor->row == row && cursor->column == column) {
                    [grid appendString:@"|"];

                    continue;
                }

                screen_cell_t *cell = screen_cell(screen, row, column);

                if (cell) {
                    if (cell->codepoint == 0) {
                        [grid appendString:@" "];
                    } else {
                        [grid appendFormat:@"%C", (unichar)cell->codepoint];
                    }
                } else {
                    [grid appendString:@"?"];
                }
            }

            [grid appendString:@"\n"];
        }

        NSLog(@"update:\n%@", grid);
    };

    self.terminal.titleBlock = ^(const char *title) {
        NSLog(@"title: %s", title);
    };

    self.terminal.bellBlock = ^() {
        NSLog(@"bell");
    };

    self.terminal.exitBlock = ^(int status) {
        NSLog(@"exit: %d", status);
    };

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        NSError *error = nil;

        if (![strongSelf.terminal start:&error]) {
            NSLog(@"error: %@", error);

            return;
        }

        usleep(100 * 1000);

        NSString *string = @"ls -l\n";
        NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];

        [strongSelf.terminal write:data];
        usleep(500 * 1000);
        [strongSelf.terminal stop];
    });
}

@end
