//
//  AppDelegate.m
//  o1
//
//  Created by grok-code-fast-1 on 2025-10-10.
//

#import "AppDelegate.h"

#import "MainMenu.h"
#import "WindowController.h"

#include "screen.h"

@interface AppDelegate ()

@property (nonatomic, strong) NSMutableArray<NSWindowController *> *windowControllers;

@end

@implementation AppDelegate

+ (void)configure {
    screen_default_offset = 2;
}

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setMainMenu:[[MainMenu alloc] init]];
    [AppDelegate configure];
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

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification {
    NSWindow *window = (NSWindow *)notification.object;

    for (NSInteger i = 0; i < self.windowControllers.count; i++) {
        if (self.windowControllers[i].window == window) {
            [self.windowControllers removeObjectAtIndex:i];

            break;
        }
    }
}

- (void)windowWillEnterFullScreen:(NSNotification *)notification {
    NSWindow *window = (NSWindow *)notification.object;

    window.titlebarAppearsTransparent = NO;
    window.appearance = nil;
}

- (void)windowWillExitFullScreen:(NSNotification *)notification {
    NSWindow *window = (NSWindow *)notification.object;

    window.titlebarAppearsTransparent = YES;
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
}

#pragma mark - Public

- (void)window:(id)sender {
    if (!_windowControllers) _windowControllers = [NSMutableArray array];

    WindowController *windowController = [[WindowController alloc] init];

    windowController.window.delegate = self;
    [windowController showWindow:nil];
    [self.windowControllers addObject:windowController];
    [NSApp activate];
}

@end
