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

- (NSApplicationPresentationOptions)window:(NSWindow *)window willUseFullScreenPresentationOptions:(NSApplicationPresentationOptions)proposedOptions {
    return NSApplicationPresentationFullScreen | NSApplicationPresentationAutoHideMenuBar | NSApplicationPresentationAutoHideToolbar;
}

#pragma mark - Public

- (void)window:(id)sender {
    if (!_windowControllers) _windowControllers = [NSMutableArray array];

    WindowController *windowController = [[WindowController alloc] init];
    NSWindow *window = windowController.window;

    if (self.windowControllers.count > 0) {
        NSPoint origin = NSMakePoint(100.0, 250.0);
        NSUInteger slot = (self.windowControllers.count - 1) % 3;
        CGFloat dx;
        CGFloat dy;

        switch (slot) {
            case 0:
                dx = 150.0 + (CGFloat)arc4random_uniform(101);
                dy = 75.0 + (CGFloat)arc4random_uniform(101);

                break;
            case 1:
                dx = 75.0 + (CGFloat)arc4random_uniform(101);
                dy = -(25.0 + (CGFloat)arc4random_uniform(101));

                break;
            default:
                dx = 25.0 + (CGFloat)arc4random_uniform(101);
                dy = 25.0 + (CGFloat)arc4random_uniform(101);

                break;
        }

        [window setFrameOrigin:NSMakePoint(origin.x + dx, origin.y + dy)];
    }

    window.delegate = self;
    [windowController showWindow:nil];
    [self.windowControllers addObject:windowController];
    [NSApp activate];
}

@end
