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

#pragma mark - Private

- (NSMenuItem *)app {
    NSString *name = NSProcessInfo.processInfo.processName;
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:name action:nil keyEquivalent:@""];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:name];

    item.submenu = appMenu;

    NSMenuItem *about = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"About %@", name] action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];

    [appMenu addItem:about];

    NSMenuItem *checkForUpdates = [[NSMenuItem alloc] initWithTitle:@"Check for Updates..." action:nil keyEquivalent:@""];

    checkForUpdates.image = [NSImage imageWithSystemSymbolName:@"arrow.trianglehead.2.clockwise.rotate.90" accessibilityDescription:nil];
    [appMenu addItem:checkForUpdates];
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *settings = [[NSMenuItem alloc] initWithTitle:@"Settings..." action:nil keyEquivalent:@","];

    settings.image = [NSImage imageWithSystemSymbolName:@"gear" accessibilityDescription:nil];
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

    newWindow.image = [NSImage imageWithSystemSymbolName:@"macwindow" accessibilityDescription:nil];
    [fileMenu addItem:newWindow];

    NSMenuItem *newCommand = [[NSMenuItem alloc] initWithTitle:@"New Command" action:nil keyEquivalent:@"n"];

    newCommand.image = [NSImage imageWithSystemSymbolName:@"pip.enter" accessibilityDescription:nil];
    [newCommand setKeyEquivalentModifierMask:NSEventModifierFlagShift | NSEventModifierFlagCommand];
    [fileMenu addItem:newCommand];
    [fileMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *close = [[NSMenuItem alloc] initWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"];

    [fileMenu addItem:close];
    [fileMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *reset = [[NSMenuItem alloc] initWithTitle:@"Reset" action:nil keyEquivalent:@"r"];

    reset.image = [NSImage imageWithSystemSymbolName:@"arrow.clockwise" accessibilityDescription:nil];
    [reset setKeyEquivalentModifierMask:NSEventModifierFlagOption | NSEventModifierFlagCommand];
    [fileMenu addItem:reset];
    [fileMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *share = [[NSMenuItem alloc] initWithTitle:@"Share..." action:nil keyEquivalent:@""];

    share.image = [NSImage imageWithSystemSymbolName:@"square.and.arrow.up" accessibilityDescription:nil];
    [fileMenu addItem:share];

    NSMenuItem *exportTxt = [[NSMenuItem alloc] initWithTitle:@"Export as TXT..." action:nil keyEquivalent:@""];

    exportTxt.image = [NSImage imageWithSystemSymbolName:@"text.document" accessibilityDescription:nil];
    [fileMenu addItem:exportTxt];
    [fileMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *print = [[NSMenuItem alloc] initWithTitle:@"Print..." action:@selector(print:) keyEquivalent:@"p"];

    [fileMenu addItem:print];

    return item;
}

- (NSMenuItem *)edit {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];

    item.submenu = editMenu;

    NSMenuItem *undo = [[NSMenuItem alloc] initWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];

    [editMenu addItem:undo];

    NSMenuItem *redo = [[NSMenuItem alloc] initWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"z"];

    [redo setKeyEquivalentModifierMask:NSEventModifierFlagShift | NSEventModifierFlagCommand];
    [editMenu addItem:redo];
    [editMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *cut = [[NSMenuItem alloc] initWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];

    [editMenu addItem:cut];

    NSMenuItem *copy = [[NSMenuItem alloc] initWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];

    [editMenu addItem:copy];

    NSMenuItem *paste = [[NSMenuItem alloc] initWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];

    [editMenu addItem:paste];

    NSMenuItem *selectAll = [[NSMenuItem alloc] initWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];

    [editMenu addItem:selectAll];
    [editMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *move = [[NSMenuItem alloc] initWithTitle:@"Move" action:nil keyEquivalent:@""];
    NSMenu *moveMenu = [[NSMenu alloc] initWithTitle:@"Move"];

    move.submenu = moveMenu;
    [editMenu addItem:move];

    NSMenuItem *moveLineStart = [[NSMenuItem alloc] initWithTitle:@"Line Start" action:nil keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSLeftArrowFunctionKey]];

    [moveMenu addItem:moveLineStart];

    NSMenuItem *moveLineEnd = [[NSMenuItem alloc] initWithTitle:@"Line End" action:nil keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSRightArrowFunctionKey]];

    [moveMenu addItem:moveLineEnd];
    [moveMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *movePreviousWord = [[NSMenuItem alloc] initWithTitle:@"Previous Word" action:nil keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSLeftArrowFunctionKey]];

    [movePreviousWord setKeyEquivalentModifierMask:NSEventModifierFlagOption | NSEventModifierFlagCommand];
    [moveMenu addItem:movePreviousWord];

    NSMenuItem *moveNextWord = [[NSMenuItem alloc] initWithTitle:@"Next Word" action:nil keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSRightArrowFunctionKey]];

    [moveNextWord setKeyEquivalentModifierMask:NSEventModifierFlagOption | NSEventModifierFlagCommand];
    [moveMenu addItem:moveNextWord];

    NSMenuItem *delete = [[NSMenuItem alloc] initWithTitle:@"Delete" action:nil keyEquivalent:@""];
    NSMenu *deleteMenu = [[NSMenu alloc] initWithTitle:@"Delete"];

    delete.submenu = deleteMenu;
    [editMenu addItem:delete];

    NSMenuItem *deleteLineStart = [[NSMenuItem alloc] initWithTitle:@"Line Start" action:nil keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSBackspaceCharacter]];

    [deleteMenu addItem:deleteLineStart];

    NSMenuItem *deleteLineEnd = [[NSMenuItem alloc] initWithTitle:@"Line End" action:nil keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSDeleteCharacter]];

    [deleteMenu addItem:deleteLineEnd];
    [deleteMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *deletePreviousWord = [[NSMenuItem alloc] initWithTitle:@"Previous Word" action:nil keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSBackspaceCharacter]];

    [deletePreviousWord setKeyEquivalentModifierMask:NSEventModifierFlagOption | NSEventModifierFlagCommand];
    [deleteMenu addItem:deletePreviousWord];

    NSMenuItem *deleteNextWord = [[NSMenuItem alloc] initWithTitle:@"Next Word" action:nil keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSDeleteCharacter]];

    [deleteNextWord setKeyEquivalentModifierMask:NSEventModifierFlagOption | NSEventModifierFlagCommand];
    [deleteMenu addItem:deleteNextWord];

    return item;
}

- (NSMenuItem *)view {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"View" action:nil keyEquivalent:@""];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];

    item.submenu = viewMenu;

    NSMenuItem *larger = [[NSMenuItem alloc] initWithTitle:@"Larger" action:nil keyEquivalent:@"+"];

    larger.image = [NSImage imageWithSystemSymbolName:@"textformat.size.larger" accessibilityDescription:nil];
    [viewMenu addItem:larger];

    NSMenuItem *smaller = [[NSMenuItem alloc] initWithTitle:@"Smaller" action:nil keyEquivalent:@"-"];

    smaller.image = [NSImage imageWithSystemSymbolName:@"textformat.size.smaller" accessibilityDescription:nil];
    [viewMenu addItem:smaller];
    [viewMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *scrollToTop = [[NSMenuItem alloc] initWithTitle:@"Scroll to Top" action:nil keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSHomeFunctionKey]];

    [viewMenu addItem:scrollToTop];

    NSMenuItem *scrollToBottom = [[NSMenuItem alloc] initWithTitle:@"Scroll to Bottom" action:nil keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSEndFunctionKey]];

    [viewMenu addItem:scrollToBottom];
    [viewMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *pageUp = [[NSMenuItem alloc] initWithTitle:@"Page Up" action:nil keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSPageUpFunctionKey]];

    [viewMenu addItem:pageUp];

    NSMenuItem *pageDown = [[NSMenuItem alloc] initWithTitle:@"Page Down" action:nil keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSPageDownFunctionKey]];

    [viewMenu addItem:pageDown];
    [viewMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *lineUp = [[NSMenuItem alloc] initWithTitle:@"Line Up" action:nil keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSPageUpFunctionKey]];

    [lineUp setKeyEquivalentModifierMask:NSEventModifierFlagOption | NSEventModifierFlagCommand];
    [viewMenu addItem:lineUp];

    NSMenuItem *lineDown = [[NSMenuItem alloc] initWithTitle:@"Line Down" action:nil keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSPageDownFunctionKey]];

    [lineDown setKeyEquivalentModifierMask:NSEventModifierFlagOption | NSEventModifierFlagCommand];
    [viewMenu addItem:lineDown];
    [viewMenu addItem:[NSMenuItem separatorItem]];

    return item;
}

- (NSMenuItem *)find {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Find" action:nil keyEquivalent:@""];
    NSMenu *findMenu = [[NSMenu alloc] initWithTitle:@"Find"];

    item.submenu = findMenu;

    NSMenuItem *find = [[NSMenuItem alloc] initWithTitle:@"Find..." action:@selector(performFindPanelAction:) keyEquivalent:@"f"];

    find.image = [NSImage imageWithSystemSymbolName:@"magnifyingglass" accessibilityDescription:nil];
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

    useSelectionForFind.image = [NSImage imageWithSystemSymbolName:@"text.magnifyingglass" accessibilityDescription:nil];
    [useSelectionForFind setTag:7];
    [findMenu addItem:useSelectionForFind];

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

    NSMenuItem *keepInFront = [[NSMenuItem alloc] initWithTitle:@"Keep in Front" action:nil keyEquivalent:@""];

    keepInFront.state = NSControlStateValueOff;
    keepInFront.image = [NSImage imageWithSystemSymbolName:@"square.3.layers.3d.top.filled" accessibilityDescription:nil];
    [windowMenu addItem:keepInFront];

    return item;
}

- (NSMenuItem *)help {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Help" action:nil keyEquivalent:@""];
    NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];

    [NSApp setHelpMenu:helpMenu];
    item.submenu = helpMenu;

    NSMenuItem *license = [[NSMenuItem alloc] initWithTitle:@"License" action:nil keyEquivalent:@""];

    license.image = [NSImage imageWithSystemSymbolName:@"c.circle" accessibilityDescription:nil];
    [helpMenu addItem:license];

    NSMenuItem *changelog = [[NSMenuItem alloc] initWithTitle:@"Changelog" action:nil keyEquivalent:@""];

    changelog.image = [NSImage imageWithSystemSymbolName:@"list.dash" accessibilityDescription:nil];
    [helpMenu addItem:changelog];

    return item;
}

- (void)undo:(id)sender {
    // TODO
}

- (void)redo:(id)sender {
    // TODO
}

@end
