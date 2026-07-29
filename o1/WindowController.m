//
//  WindowController.m
//  o1
//
//  Created by grok-code-fast-1 on 2025-11-26.
//

#import "WindowController.h"

#import "ViewController.h"

static NSToolbarItemIdentifier const kSearchItemIdentifier = @"SearchItem";

@interface WindowController ()

@property (nonatomic, strong) ViewController *viewController;

@end

@implementation WindowController

+ (NSRect)defaultContentRect {
    return NSMakeRect(100.0, 250.0, 575.0, 375.0);
}

- (instancetype)init {
    NSRect frame = [WindowController defaultContentRect];
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:NO];

    self = [super initWithWindow:window];

    if (self) {
        window.restorable = NO;
        window.titlebarAppearsTransparent = YES;
        window.backgroundColor = [NSColor colorWithDeviceWhite:0.0 alpha:0.94];

        NSToolbar *toolbar = [[NSToolbar alloc] init];

        toolbar.delegate = self;
        toolbar.displayMode = NSToolbarDisplayModeIconOnly;
        toolbar.allowsDisplayModeCustomization = NO;
        window.toolbar = toolbar;
        window.toolbarStyle = NSWindowToolbarStyleUnified;
        window.contentMinSize = NSMakeSize(200.0, 185.0);
        _viewController = [[ViewController alloc] init];
        window.contentViewController = _viewController;
        window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        [window setContentSize:frame.size];
    }

    return self;
}

#pragma mark - NSToolbarDelegate

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    if ([itemIdentifier isEqualToString:kSearchItemIdentifier]) {
        NSSearchToolbarItem *search = [[NSSearchToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        NSSearchField *searchField = search.searchField;

        searchField.delegate = self.viewController;
        search.enabled = NO;

        return search;
    }

    return nil;
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[
        NSToolbarFlexibleSpaceItemIdentifier,
        kSearchItemIdentifier,
    ];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return @[
        NSToolbarFlexibleSpaceItemIdentifier,
        kSearchItemIdentifier,
    ];
}

@end
