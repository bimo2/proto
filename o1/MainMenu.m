//
//  MainMenu.m
//  o1
//
//  Created by grok-code-fast-1 on 2025-09-18.
//

#import "MainMenu.h"

@implementation MainMenu

- (instancetype)init {
    self = [super initWithTitle:@"Main Menu"];

    if (self) {
        [self addItem:[self appleMenu]];
        [self addItem:[self fileMenu]];
        [self addItem:[self editMenu]];
        [self addItem:[self viewMenu]];
        [self addItem:[self findMenu]];
        [self addItem:[self windowMenu]];
        [self addItem:[self helpMenu]];
    }

    return self;
}

- (NSMenuItem *)appleMenu {
    NSString *name = [NSProcessInfo.processInfo processName];
    NSMenuItem *appleItem = [[NSMenuItem alloc] initWithTitle:name action:nil keyEquivalent:@""];
    NSMenu *appleMenu = [[NSMenu alloc] initWithTitle:name];

    [appleItem setSubmenu:appleMenu];

    // about
    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"About %@", name] action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];

    [appleMenu addItem:aboutItem];
    [appleMenu addItem:[NSMenuItem separatorItem]];

    // settings
    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:@"Settings..." action:nil keyEquivalent:@","];

    [appleMenu addItem:settingsItem];
    [appleMenu addItem:[NSMenuItem separatorItem]];

    // services
    NSMenuItem *servicesItem = [[NSMenuItem alloc] initWithTitle:@"Services" action:nil keyEquivalent:@""];
    NSMenu *servicesMenu = [[NSMenu alloc] initWithTitle:@"Services"];

    [NSApp setServicesMenu:servicesMenu];
    [servicesItem setSubmenu:servicesMenu];
    [appleMenu addItem:servicesItem];
    [appleMenu addItem:[NSMenuItem separatorItem]];

    // hide
    NSMenuItem *hideItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Hide %@", name] action:@selector(hide:) keyEquivalent:@"h"];

    [appleMenu addItem:hideItem];

    // hide others
    NSMenuItem *hideOthersItem = [[NSMenuItem alloc] initWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];

    [hideOthersItem setKeyEquivalentModifierMask:NSEventModifierFlagOption | NSEventModifierFlagCommand];
    [appleMenu addItem:hideOthersItem];

    // show all
    NSMenuItem *showAllItem = [[NSMenuItem alloc] initWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];

    [appleMenu addItem:showAllItem];
    [appleMenu addItem:[NSMenuItem separatorItem]];

    // quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Quit %@", name] action:@selector(terminate:) keyEquivalent:@"q"];

    [appleMenu addItem:quitItem];

    return appleItem;
}

- (NSMenuItem *)fileMenu {
    NSMenuItem *fileItem = [[NSMenuItem alloc] initWithTitle:@"File" action:nil keyEquivalent:@""];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];

    [fileItem setSubmenu:fileMenu];

    // new window
    NSMenuItem *newWindowItem = [[NSMenuItem alloc] initWithTitle:@"New Window" action:nil keyEquivalent:@"n"];

    [fileMenu addItem:newWindowItem];
    [fileMenu addItem:[NSMenuItem separatorItem]];

    // close window
    NSMenuItem *closeItem = [[NSMenuItem alloc] initWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"];

    [fileMenu addItem:closeItem];

    return fileItem;
}

- (NSMenuItem *)editMenu {
    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];

    [editItem setSubmenu:editMenu];

    // copy
    NSMenuItem *copyItem = [[NSMenuItem alloc] initWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];

    [editMenu addItem:copyItem];

    // paste
    NSMenuItem *pasteItem = [[NSMenuItem alloc] initWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];

    [editMenu addItem:pasteItem];
    [editMenu addItem:[NSMenuItem separatorItem]];

    // select all
    NSMenuItem *selectAllItem = [[NSMenuItem alloc] initWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];

    [editMenu addItem:selectAllItem];

    return editItem;
}

- (NSMenuItem *)viewMenu {
    NSMenuItem *viewItem = [[NSMenuItem alloc] initWithTitle:@"View" action:nil keyEquivalent:@""];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];

    [viewItem setSubmenu:viewMenu];

    return viewItem;
}

- (NSMenuItem *)findMenu {
    NSMenuItem *findItem = [[NSMenuItem alloc] initWithTitle:@"Find" action:nil keyEquivalent:@""];
    NSMenu *findMenu = [[NSMenu alloc] initWithTitle:@"Find"];

    [findItem setSubmenu:findMenu];

    // find
    NSMenuItem *searchItem = [[NSMenuItem alloc] initWithTitle:@"Find..." action:@selector(performFindPanelAction:) keyEquivalent:@"f"];

    [searchItem setTag:1];
    [findMenu addItem:searchItem];

    // find next
    NSMenuItem *searchNextItem = [[NSMenuItem alloc] initWithTitle:@"Find Next" action:@selector(performFindPanelAction:) keyEquivalent:@"g"];

    [searchNextItem setTag:2];
    [findMenu addItem:searchNextItem];

    // find previous
    NSMenuItem *searchPreviousItem = [[NSMenuItem alloc] initWithTitle:@"Find Previous" action:@selector(performFindPanelAction:) keyEquivalent:@"G"];

    [searchPreviousItem setKeyEquivalentModifierMask:NSEventModifierFlagShift | NSEventModifierFlagCommand];
    [searchPreviousItem setTag:3];
    [findMenu addItem:searchPreviousItem];
    [findMenu addItem:[NSMenuItem separatorItem]];

    // use selection for find
    NSMenuItem *useSelectionForSearchItem = [[NSMenuItem alloc] initWithTitle:@"Use Selection for Find" action:@selector(performFindPanelAction:) keyEquivalent:@"e"];

    [useSelectionForSearchItem setTag:7];
    [findMenu addItem:useSelectionForSearchItem];

    // jump to selection
    NSMenuItem *jumpToSelectionItem = [[NSMenuItem alloc] initWithTitle:@"Jump to Selection" action:@selector(centerSelectionInVisibleArea:) keyEquivalent:@"j"];

    [findMenu addItem:jumpToSelectionItem];

    return findItem;
}

- (NSMenuItem *)windowMenu {
    NSMenuItem *windowItem = [[NSMenuItem alloc] initWithTitle:@"Window" action:nil keyEquivalent:@""];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];

    [NSApp setWindowsMenu:windowMenu];
    [windowItem setSubmenu:windowMenu];

    // minimize
    NSMenuItem *minimizeItem = [[NSMenuItem alloc] initWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];

    [windowMenu addItem:minimizeItem];

    // zoom
    NSMenuItem *zoomItem = [[NSMenuItem alloc] initWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];

    [windowMenu addItem:zoomItem];
    [windowMenu addItem:[NSMenuItem separatorItem]];

    // bring all to front
    NSMenuItem *bringAllToFrontItem = [[NSMenuItem alloc] initWithTitle:@"Bring All to Front" action:@selector(arrangeInFront:) keyEquivalent:@""];

    [windowMenu addItem:bringAllToFrontItem];

    return windowItem;
}

- (NSMenuItem *)helpMenu {
    NSMenuItem *helpItem = [[NSMenuItem alloc] initWithTitle:@"Help" action:nil keyEquivalent:@""];
    NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];

    [NSApp setHelpMenu:helpMenu];
    [helpItem setSubmenu:helpMenu];

    // welcome
    NSMenuItem *welcomeItem = [[NSMenuItem alloc] initWithTitle:@"Welcome" action:nil keyEquivalent:@""];

    [helpMenu addItem:welcomeItem];

    // release notes
    NSMenuItem *releaseNotesItem = [[NSMenuItem alloc] initWithTitle:@"Release Notes" action:nil keyEquivalent:@""];

    [helpMenu addItem:releaseNotesItem];

    // report bug
    NSMenuItem *reportBugItem = [[NSMenuItem alloc] initWithTitle:@"Report Bug..." action:nil keyEquivalent:@""];

    [helpMenu addItem:reportBugItem];

    return helpItem;
}

@end
