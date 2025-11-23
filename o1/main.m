//
//  main.m
//  o1
//
//  Created by grok-code-fast-1 on 2025-10-10.
//

#include "AppDelegate.h"

#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];

        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
    }

    return EXIT_SUCCESS;
}
