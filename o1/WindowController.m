//
//  WindowController.m
//  o1
//
//  Created by grok-code-fast-1 on 2025-11-26.
//

#import "WindowController.h"

#import "ViewController.h"

@implementation WindowController

- (instancetype)init {
    NSRect frame = NSMakeRect(100, 250, 575, 375);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:NO];

    self = [super initWithWindow:window];

    if (self) {
        window.restorable = NO;
        window.title = @"github.com";
        window.titlebarAppearsTransparent = YES;
        window.backgroundColor = [NSColor colorWithDeviceWhite:0.0 alpha:0.94];

        NSToolbar *toolbar = [[NSToolbar alloc] init];

        toolbar.displayMode = NSToolbarDisplayModeIconOnly;
        window.toolbar = toolbar;
        window.toolbarStyle = NSWindowToolbarStyleUnified;

        ViewController *viewController = [[ViewController alloc] init];

        window.contentViewController = viewController;
        window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        [window setContentSize:frame.size];
    }

    return self;
}

@end
