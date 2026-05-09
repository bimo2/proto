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

static const float kTerminalTopPadding = 2.0f;
static const float kTerminalBottomPadding = 20.0f;
static const float kTerminalHorizontalPadding = 16.0f;
static const float kGradientStop = 60.0f;

@interface ViewController ()

@property (nonatomic, strong) Terminal *terminal;
@property (nonatomic, strong) TerminalView *terminalView;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;

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
        [terminalView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:kTerminalTopPadding],
        [terminalView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-kTerminalBottomPadding],
        [terminalView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kTerminalHorizontalPadding],
        [terminalView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kTerminalHorizontalPadding],
    ]];

    self.terminalView = terminalView;

    CAGradientLayer *layer = [CAGradientLayer layer];

    layer.colors = @[
        (id)[NSColor clearColor].CGColor,
        (id)[NSColor colorWithDeviceWhite:0.0 alpha:0.04].CGColor,
        (id)[NSColor colorWithDeviceWhite:0.0 alpha:0.16].CGColor,
        (id)[NSColor colorWithDeviceWhite:0.0 alpha:0.36].CGColor,
        (id)[NSColor colorWithDeviceWhite:0.0 alpha:0.64].CGColor,
        (id)[NSColor blackColor].CGColor,
        (id)[NSColor blackColor].CGColor,
    ];

    layer.startPoint = CGPointMake(0.5, 1.0);
    layer.endPoint = CGPointMake(0.5, 0.0);
    terminalView.layer.mask = layer;
    self.gradientLayer = layer;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        NSError *error = nil;

        if (![strongSelf.terminal start:&error]) {
            // TODO

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

- (void)viewDidLayout {
    [super viewDidLayout];
    [self updateGradientLayer];
}

#pragma mark - Private

- (void)updateGradientLayer {
    if (self.view.window.styleMask & NSWindowStyleMaskFullScreen) {
        self.terminalView.layer.mask = nil;

        return;
    }

    self.terminalView.layer.mask = self.gradientLayer;

    NSRect bounds = self.terminalView.bounds;
    CGFloat stop = MIN(kGradientStop / bounds.size.height, 1.0);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.gradientLayer.frame = bounds;

    self.gradientLayer.locations = @[
        @0.0,
        @(stop * 0.2),
        @(stop * 0.4),
        @(stop * 0.6),
        @(stop * 0.8),
        @(stop),
        @1.0,
    ];

    [CATransaction commit];
}

- (void)updateWindow:(NSNotification *)notification {
    NSWindow *window = (NSWindow *)notification.object;

    [self.terminal focus:window.isKeyWindow];
}

@end
