//
//  WindowController.m
//  o1
//
//  Created by grok-code-fast-1 on 2025-11-26.
//

#import "WindowController.h"

#import "ViewController.h"

static NSToolbarItemIdentifier const SearchItemIdentifier = @"SearchItem";

@interface WindowController ()

@property (nonatomic, strong) ViewController *viewController;

@end

@implementation WindowController

- (instancetype)init {
    NSRect frame = NSMakeRect(100, 250, 575, 375);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:NO];

    self = [super initWithWindow:window];

    if (self) {
        window.restorable = NO;
        window.title = @"github.com";
        window.titlebarAppearsTransparent = YES;
        window.backgroundColor = [NSColor colorWithDeviceWhite:0.0 alpha:0.94];

        NSToolbar *toolbar = [[NSToolbar alloc] init];

        toolbar.delegate = self;
        toolbar.displayMode = NSToolbarDisplayModeIconOnly;
        window.toolbar = toolbar;
        window.toolbarStyle = NSWindowToolbarStyleUnified;
        _viewController = [[ViewController alloc] init];
        window.contentViewController = _viewController;
        window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        [window setContentSize:frame.size];
    }

    return self;
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    if ([itemIdentifier isEqualToString:SearchItemIdentifier]) {
        NSSearchToolbarItem *search = [[NSSearchToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        NSSearchField *searchField = search.searchField;

        searchField.delegate = self.viewController;

        return search;
    }

    return nil;
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[
        NSToolbarFlexibleSpaceItemIdentifier,
        SearchItemIdentifier,
    ];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return @[
        NSToolbarFlexibleSpaceItemIdentifier,
        SearchItemIdentifier,
    ];
}

@end
