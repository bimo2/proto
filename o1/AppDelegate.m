//
//  AppDelegate.m
//  o1
//
//  Created by grok-code-fast-1 on 2025-10-10.
//

#import "AppDelegate.h"

#import "MainMenu.h"
#import "ViewController.h"

@interface AppDelegate ()

@property (strong) NSWindow *window;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSRect frame = NSMakeRect(0, 0, 575, 375);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView;

    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:NO];

    _window = window;
    _window.restorable = NO;
    _window.titleVisibility = NSWindowTitleHidden;
    _window.titlebarAppearsTransparent = YES;
    _window.backgroundColor = [NSColor colorWithDeviceWhite:0.0 alpha:0.94];
    _window.toolbar = [[NSToolbar alloc] init];;
    _window.toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    _window.toolbarStyle = NSWindowToolbarStyleUnified;

    ViewController *viewController = [[ViewController alloc] init];

    _window.contentViewController = viewController;
    [_window setContentSize:frame.size];
    [_window makeKeyAndOrderFront:nil];

    MainMenu *mainMenu = [[MainMenu alloc] init];

    [NSApp setMainMenu:mainMenu];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    // TODO
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

@end
