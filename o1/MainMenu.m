//
//  MainMenu.m
//  o1
//
//  Created by composer-1 on 2025-11-23.
//

#import "MainMenu.h"

#import "AppDelegate.h"

@implementation MainMenu

- (instancetype)init {
    self = [super initWithTitle:@"Main Menu"];

    if (self) {
        [self addItem:[self app]];
        [self addItem:[self file]];
        [self addItem:[self edit]];
        [self addItem:[self view]];
        [self addItem:[self find]];
        [self addItem:[self window]];
        [self addItem:[self help]];
    }

    return self;
}

- (NSMenuItem *)app {
    NSString *name = NSProcessInfo.processInfo.processName;
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:name action:nil keyEquivalent:@""];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:name];

    item.submenu = appMenu;

    NSMenuItem *about = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"About %@", name] action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];

    [appMenu addItem:about];
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *settings = [[NSMenuItem alloc] initWithTitle:@"Settings..." action:nil keyEquivalent:@","];

    [appMenu addItem:settings];
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *services = [[NSMenuItem alloc] initWithTitle:@"Services" action:nil keyEquivalent:@""];
    NSMenu *servicesMenu = [[NSMenu alloc] initWithTitle:@"Services"];

    [NSApp setServicesMenu:servicesMenu];
    services.submenu = servicesMenu;
    [appMenu addItem:services];
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *hide = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Hide %@", name] action:@selector(hide:) keyEquivalent:@"h"];

    [appMenu addItem:hide];

    NSMenuItem *hideOthers = [[NSMenuItem alloc] initWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];

    [hideOthers setKeyEquivalentModifierMask:NSEventModifierFlagOption | NSEventModifierFlagCommand];
    [appMenu addItem:hideOthers];

    NSMenuItem *showAll = [[NSMenuItem alloc] initWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];

    [appMenu addItem:showAll];
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Quit %@", name] action:@selector(terminate:) keyEquivalent:@"q"];

    [appMenu addItem:quit];

    return item;
}

- (NSMenuItem *)file {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"File" action:nil keyEquivalent:@""];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];

    item.submenu = fileMenu;

    NSMenuItem *newWindow = [[NSMenuItem alloc] initWithTitle:@"New Window" action:@selector(window:) keyEquivalent:@"n"];

    [fileMenu addItem:newWindow];
    [fileMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *close = [[NSMenuItem alloc] initWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"];

    [fileMenu addItem:close];

    return item;
}

- (NSMenuItem *)edit {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];

    item.submenu = editMenu;

    NSMenuItem *copy = [[NSMenuItem alloc] initWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];

    [editMenu addItem:copy];

    NSMenuItem *paste = [[NSMenuItem alloc] initWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];

    [editMenu addItem:paste];

    NSMenuItem *selectAll = [[NSMenuItem alloc] initWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];

    [editMenu addItem:selectAll];

    return item;
}

- (NSMenuItem *)view {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"View" action:nil keyEquivalent:@""];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];

    item.submenu = viewMenu;

    return item;
}

- (NSMenuItem *)find {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Find" action:nil keyEquivalent:@""];
    NSMenu *findMenu = [[NSMenu alloc] initWithTitle:@"Find"];

    item.submenu = findMenu;

    NSMenuItem *find = [[NSMenuItem alloc] initWithTitle:@"Find..." action:@selector(performFindPanelAction:) keyEquivalent:@"f"];

    [find setTag:1];
    [findMenu addItem:find];

    NSMenuItem *findNext = [[NSMenuItem alloc] initWithTitle:@"Find Next" action:@selector(performFindPanelAction:) keyEquivalent:@"g"];

    [findNext setTag:2];
    [findMenu addItem:findNext];

    NSMenuItem *findPrevious = [[NSMenuItem alloc] initWithTitle:@"Find Previous" action:@selector(performFindPanelAction:) keyEquivalent:@"g"];

    [findPrevious setKeyEquivalentModifierMask:NSEventModifierFlagShift | NSEventModifierFlagCommand];
    [findPrevious setTag:3];
    [findMenu addItem:findPrevious];
    [findMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *useSelectionForFind = [[NSMenuItem alloc] initWithTitle:@"Use Selection for Find" action:@selector(performFindPanelAction:) keyEquivalent:@"e"];

    [useSelectionForFind setTag:7];
    [findMenu addItem:useSelectionForFind];

    NSMenuItem *jumpToSelection = [[NSMenuItem alloc] initWithTitle:@"Jump to Selection" action:@selector(centerSelectionInVisibleArea:) keyEquivalent:@"j"];

    [findMenu addItem:jumpToSelection];

    return item;
}

- (NSMenuItem *)window {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Window" action:nil keyEquivalent:@""];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];

    [NSApp setWindowsMenu:windowMenu];
    item.submenu = windowMenu;

    NSMenuItem *minimize = [[NSMenuItem alloc] initWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];

    [windowMenu addItem:minimize];

    NSMenuItem *zoom = [[NSMenuItem alloc] initWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];

    [windowMenu addItem:zoom];
    [windowMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *bringAllToFront = [[NSMenuItem alloc] initWithTitle:@"Bring All to Front" action:@selector(arrangeInFront:) keyEquivalent:@""];

    [windowMenu addItem:bringAllToFront];

    return item;
}

- (NSMenuItem *)help {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Help" action:nil keyEquivalent:@""];
    NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];

    [NSApp setHelpMenu:helpMenu];
    item.submenu = helpMenu;

    return item;
}

@end
