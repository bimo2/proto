//
//  ViewController.m
//  o1
//
//  Created by grok-code-fast-1 on 2025-10-10.
//

#import "ViewController.h"
#import "Terminal.h"

#include "screen.h"

@interface ViewController ()

@property (strong) Terminal *terminal;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    __weak typeof(self) weakSelf = self;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        strongSelf.terminal = [[Terminal alloc] init];
        strongSelf.terminal.file = @"/bin/cat";

        strongSelf.terminal.updateBlock = ^(screen_t *screen) {
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

        strongSelf.terminal.titleBlock = ^(const char *title) {
            NSLog(@"title: %s", title);
        };

        strongSelf.terminal.bellBlock = ^() {
            NSLog(@"bell");
        };

        strongSelf.terminal.exitBlock = ^(int status) {
            NSLog(@"exit: %d", status);
        };

        NSError *error = nil;

        if (![strongSelf.terminal start:&error]) {
            NSLog(@"error: %@", error);

            return;
        }

        usleep(100 * 1000);

        NSString *string = @"hello, world!";
        NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];

        [strongSelf.terminal write:data];
        usleep(500 * 1000);
        [strongSelf.terminal stop];
    });
}

- (void)dealloc {
    [self.terminal stop];
}

@end
