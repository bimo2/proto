//
//  AppDelegate.m
//  o1
//
//  Created by grok-code-fast-1 on 2025-10-10.
//

#import "AppDelegate.h"

#import "MainMenu.h"
#import "ViewController.h"

@interface AppDelegate () <MainMenuDelegate>

@property (strong) NSMutableArray<NSWindow *> *windows;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self window:nil];

    MainMenu *mainMenu = [[MainMenu alloc] init];

    [NSApp setMainMenu:mainMenu];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    // TODO
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)hasVisibleWindows {
    if (!hasVisibleWindows) [self window:nil];

    return YES;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (void)window:(id)sender {
    if (!_windows) _windows = [NSMutableArray array];

    NSRect frame = NSMakeRect(100, 250, 575, 375);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:NO];

    window.restorable = NO;
    window.titleVisibility = NSWindowTitleHidden;
    window.titlebarAppearsTransparent = YES;
    window.backgroundColor = [NSColor colorWithDeviceWhite:0.0 alpha:0.94];

    NSToolbar *toolbar = [[NSToolbar alloc] init];

    toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    window.toolbar = toolbar;
    window.toolbarStyle = NSWindowToolbarStyleUnified;

    ViewController *viewController = [[ViewController alloc] init];

    window.contentViewController = viewController;
    [window setContentSize:frame.size];
    [window makeKeyAndOrderFront:nil];
    [self.windows addObject:window];
}

@end
