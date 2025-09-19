//
//  AppDelegate.m
//  o1
//
//  Created by Bimal Bhagrath on 2025-09-17.
//

#import "AppDelegate.h"
#import "MainMenu.h"

@interface AppDelegate ()

@property (strong) NSWindow *window;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSRect frame = NSMakeRect(100, 200, 560, 400);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView;

    self.window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:NO];
    self.window.restorable = NO;
    self.window.titleVisibility = NSWindowTitleHidden;
    self.window.titlebarAppearsTransparent = YES;
    self.window.backgroundColor = [NSColor colorWithDeviceWhite:0.0 alpha:0.92];
    self.window.toolbar = [[NSToolbar alloc] init];
    self.window.toolbarStyle = NSWindowToolbarStyleUnified;
    self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenNone;
    [self.window setContentSize:frame.size];
    [self.window makeKeyAndOrderFront:nil];

    NSMenu *mainMenu = [[MainMenu alloc] init];

    [NSApp setMainMenu:mainMenu];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)applicationWillTerminate:(NSNotification *)notification {}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

@end
