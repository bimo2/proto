//
//  Terminal+UserDefaults.m
//  o1
//
//  Created by grok-code-fast-1 on 2025-10-27.
//

#import "Terminal+UserDefaults.h"

#include "screen.h"

@implementation Terminal (UserDefaults)

+ (NSUInteger)width {
    return screen_default_width;
}

+ (void)setWidth:(NSUInteger)width {
    screen_default_width = (uint32_t)width;
}

+ (NSUInteger)height {
    return screen_default_height;
}

+ (void)setHeight:(NSUInteger)height {
    screen_default_height = (uint32_t)height;
}

+ (NSUInteger)rows {
    return screen_default_rows;
}

+ (void)setRows:(NSUInteger)rows {
    screen_default_rows = (uint32_t)rows;
}

+ (NSUInteger)columns {
    return screen_default_columns;
}

+ (void)setColumns:(NSUInteger)columns {
    screen_default_columns = (uint32_t)columns;
}

@end
