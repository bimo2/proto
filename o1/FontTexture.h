//
//  FontTexture.h
//  o1
//
//  Created by claude-4.5-opus-high-thinking on 2025-12-04.
//

#import <AppKit/AppKit.h>

typedef struct glyph_attributes_t {
    float advance_x;
    float bearing_x;
    float bearing_y;
    float width;
    float height;
    float uv[4];
} glyph_attributes_t;

@interface FontTexture : NSObject

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, assign, readonly) CGFloat size;
@property (nonatomic, assign, readonly) NSFontWeight weight;
@property (nonatomic, assign, readonly) CGFloat scale;
@property (nonatomic, assign, readonly) CGFloat width;
@property (nonatomic, assign, readonly) CGFloat height;
@property (nonatomic, assign, readonly) NSUInteger count;
@property (nonatomic, copy, readonly) NSData *data;

- (instancetype)initWithName:(NSString *)name size:(CGFloat)size weight:(NSFontWeight)weight scale:(CGFloat)scale;

- (void)load:(NSError **)error;

- (BOOL)find:(uint32_t)codepoint glyph:(uint32_t *)glyph attributes:(glyph_attributes_t *)attributes;

@end
