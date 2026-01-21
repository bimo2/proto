//
//  Terminal+UserDefaults.m
//  o1
//
//  Created by grok-code-fast-1 on 2025-10-27.
//

#import "Terminal+UserDefaults.h"

#include "screen.h"
#include "shaders_cpu.h"
#include "unicode.h"

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

+ (NSUInteger)offset {
    return screen_default_offset;
}

+ (void)setOffset:(NSUInteger)offset {
    screen_default_offset = (uint32_t)offset;
}

+ (NSUInteger)codepoint {
    return (NSUInteger)unicode_default_codepoint;
}

+ (void)setCodepoint:(NSUInteger)codepoint {
    unicode_codepoint_t scalar = (unicode_codepoint_t)codepoint;

    switch (scalar) {
        case UNICODE_CODEPOINT_UTF8:
        case UNICODE_CODEPOINT_UTF16:
        case UNICODE_CODEPOINT_UTF32:
            unicode_default_codepoint = scalar;

            break;
        case UNICODE_CODEPOINT_DYNAMIC:
            unicode_default_codepoint = UNICODE_CODEPOINT_UTF32;

            break;
    }
}

+ (BOOL)monochrome {
    return cpu_default_monochrome;
}

+ (void)setMonochrome:(BOOL)monochrome {
    cpu_default_monochrome = (bool)monochrome;
}

+ (NSDictionary<NSNumber *, NSColor *> *)colors {
    NSMutableDictionary *indexed = [NSMutableDictionary dictionary];

    for (int i = 0; i < CPU_USER_COLOR_LENGTH; i++) {
        simd_float3 rgb = cpu_default_colors[i];
        CGFloat components[] = {rgb.x, rgb.y, rgb.z, 1.0};

        indexed[@(i)] = [NSColor colorWithColorSpace:NSColorSpace.sRGBColorSpace components:components count:4];
    }

    return [indexed copy];
}

+ (void)setColors:(NSDictionary<NSNumber *, NSColor *> *)colors {
    [colors enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSColor *value, BOOL *stop) {
        NSColor *color = [value colorUsingColorSpace:NSColorSpace.sRGBColorSpace];

        if (!color) return;

        float red = (float)color.redComponent;
        float green = (float)color.greenComponent;
        float blue = (float)color.blueComponent;

        cpu_default_colors[key.intValue] = simd_make_float3(red, green, blue);
    }];
}

@end
