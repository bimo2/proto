//
//  ViewController.m
//  o1
//
//  Created by grok-code-fast-1 on 2025-10-10.
//

#import "ViewController.h"

#import "Terminal.h"
#import "TerminalView.h"

#import <QuartzCore/QuartzCore.h>

#include "render.h"
#include "screen.h"

#include <dispatch/dispatch.h>

@interface ViewController ()

@property (nonatomic, strong) Terminal *terminal;
@property (nonatomic, strong) TerminalView *terminalView;
@property (nonatomic, strong) NSView *gradientView;

@end

@implementation ViewController

- (void)dealloc {
    [_terminal stop];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    Terminal *terminal = [[Terminal alloc] init];

    terminal.file = @"/bin/zsh";

    __weak typeof(self) weakSelf = self;

    terminal.renderBlock = ^(const render_t *ops, size_t count) {
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        [strongSelf.terminalView render:ops count:count];

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

    terminal.updateBlock = ^(screen_t *screen) {
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

    terminal.titleBlock = ^(const char *title) {
        NSLog(@"title: %s", title);
    };

    terminal.bellBlock = ^() {
        NSLog(@"bell");
    };

    terminal.exitBlock = ^(int status) {
        NSLog(@"exit: %d", status);
    };

    self.terminal = terminal;

    TerminalView *terminalView = [[TerminalView alloc] initWithFrame:self.view.bounds];

    terminalView.translatesAutoresizingMaskIntoConstraints = NO;
    terminalView.terminal = terminal;
    [self.view addSubview:terminalView];

    [NSLayoutConstraint activateConstraints:@[
        [terminalView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:2.0],
        [terminalView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-20.0],
        [terminalView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [terminalView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
    ]];

    self.terminalView = terminalView;

    CGFloat height = 80.0;
    NSRect frame = NSMakeRect(0, self.view.bounds.size.height - height, self.view.bounds.size.width, height);
    NSView *subview = [[NSView alloc] initWithFrame:frame];

    subview.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    subview.wantsLayer = YES;

    CAGradientLayer *gradient = [CAGradientLayer layer];

    gradient.colors = @[
        (id)[NSColor colorWithDeviceWhite:0.0 alpha:0.84].CGColor,
        (id)[NSColor colorWithDeviceWhite:0.0 alpha:0.0].CGColor,
    ];

    gradient.locations = @[@0.24, @1.0];
    gradient.startPoint = CGPointMake(0.5, 1.0);
    gradient.endPoint = CGPointMake(0.5, 0.0);
    gradient.frame = subview.bounds;
    subview.layer = gradient;
    [self.view addSubview:subview positioned:NSWindowAbove relativeTo:terminalView];
    self.gradientView = subview;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        NSError *error = nil;

        if (![strongSelf.terminal start:&error]) {
            NSLog(@"error: %@", error);

            return;
        }
    });
}

- (void)viewDidAppear {
    [super viewDidAppear];
    [self.view.window makeFirstResponder:self.terminalView];
}

@end
