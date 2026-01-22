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

#pragma mark - NSViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    Terminal *terminal = [[Terminal alloc] init];
    __weak typeof(self) weakSelf = self;

    terminal.renderBlock = ^(const render_t *ops, size_t count) {
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        [strongSelf.terminalView render:ops count:count];
    };

    terminal.updateBlock = ^(const screen_t *screen) {
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        [strongSelf.terminalView screen:screen];
    };

    terminal.titleBlock = ^(const char *title) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;

            if (!strongSelf) return;

            strongSelf.view.window.title = [NSString stringWithCString:title encoding:NSUTF8StringEncoding];
        });
    };

    terminal.bellBlock = ^() {
        NSBeep();
    };

    terminal.mouseBlock = ^(bool enabled) {
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        strongSelf.terminalView.trackingAreasEnabled = enabled;
    };

    terminal.exitBlock = ^(int status) {
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        strongSelf.terminalView.interactive = NO;
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

    CGFloat height = 60.0;
    NSRect frame = NSMakeRect(0, self.view.bounds.size.height - height, self.view.bounds.size.width, height);
    NSView *subview = [[NSView alloc] initWithFrame:frame];

    subview.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    subview.wantsLayer = YES;

    CAGradientLayer *gradient = [CAGradientLayer layer];

    gradient.colors = @[
        (id)[NSColor colorWithDeviceWhite:0.0 alpha:0.84].CGColor,
        (id)[NSColor colorWithDeviceWhite:0.0 alpha:0.0].CGColor,
    ];

    gradient.locations = @[@0.46, @1.0];
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

    NSWindow *window = self.view.window;

    [window makeFirstResponder:self.terminalView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateWindow:) name:NSWindowDidBecomeKeyNotification object:window];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateWindow:) name:NSWindowDidResignKeyNotification object:window];
}

- (void)viewWillDisappear {
    [super viewWillDisappear];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Private

- (void)updateWindow:(NSNotification *)notification {
    NSWindow *window = (NSWindow *)notification.object;

    [self.terminal focus:window.isKeyWindow];
}

@end
