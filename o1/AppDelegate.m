//
//  AppDelegate.m
//  o1
//
//  Created by grok-code-fast-1 on 2025-10-10.
//

#import "AppDelegate.h"

#import "MainMenu.h"
#import "ViewController.h"

@interface AppDelegate () <NSWindowDelegate, MainMenuDelegate>

@property (strong) NSMutableArray<NSWindow *> *windows;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    MainMenu *mainMenu = [[MainMenu alloc] init];

    [NSApp setMainMenu:mainMenu];
    [self window:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    // TODO
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)hasVisibleWindows {
    if (!hasVisibleWindows) [self window:nil];

    return YES;
}

- (NSMenu *)applicationDockMenu:(NSApplication *)sender {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Dock Menu"];

    [menu addItemWithTitle:@"New Window" action:@selector(window:) keyEquivalent:@"n"];

    return menu;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (void)windowWillEnterFullScreen:(NSNotification *)notification {
    if ([notification.object isKindOfClass:[NSWindow class]]) {
        NSWindow *window = (NSWindow *)notification.object;

        window.titlebarAppearsTransparent = NO;
        window.toolbarStyle = NSWindowToolbarStyleUnifiedCompact;
        window.appearance = nil;
    }
}

- (void)windowWillExitFullScreen:(NSNotification *)notification {
    if ([notification.object isKindOfClass:[NSWindow class]]) {
        NSWindow *window = (NSWindow *)notification.object;

        window.titlebarAppearsTransparent = YES;
        window.toolbarStyle = NSWindowToolbarStyleUnified;
        window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    }
}

- (void)window:(id)sender {
    if (!_windows) _windows = [NSMutableArray array];

    NSRect frame = NSMakeRect(100, 250, 575, 375);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:NO];

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
    window.delegate = self;
    [window setContentSize:frame.size];
    [window makeKeyAndOrderFront:nil];
    [self.windows addObject:window];
    [NSApp activateIgnoringOtherApps:YES];
}

@end
