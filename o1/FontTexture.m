//
//  FontTexture.m
//  o1
//
//  Created by claude-4.5-opus-high-thinking on 2025-12-04.
//

#import "FontTexture.h"

#import "NSError+Reporting.h"

#import <CoreText/CoreText.h>

@interface FontTexture ()

@property (nonatomic, assign) CTFontRef font;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *codepoints;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSValue *> *attributes;
@property (nonatomic, copy, readwrite) NSData *data;

@end

@implementation FontTexture

- (instancetype)initWithName:(NSString *)name size:(CGFloat)size weight:(NSFontWeight)weight scale:(CGFloat)scale {
    self = [super init];

    if (self) {
        _name = name;
        _size = size;
        _weight = weight;
        _scale = scale;
        _width = 2048;
        _height = 2048;

        NSFontDescriptor *descriptor = [NSFontDescriptor fontDescriptorWithFontAttributes:@{
            NSFontFamilyAttribute: _name ?: @"",
            NSFontTraitsAttribute: @{ NSFontWeightTrait: @(_weight) }
        }];

        CGFloat displaySize = _size * _scale;
        NSFont *font = [NSFont fontWithDescriptor:descriptor size:displaySize];

        if (!font) font = [NSFont monospacedSystemFontOfSize:displaySize weight:_weight];

        _font = CFRetain((__bridge CTFontRef)font);
        _data = [NSData data];
        _attributes = [NSMutableDictionary dictionary];
        _codepoints = [NSMutableDictionary dictionary];
    }

    return self;
}

- (void)dealloc {
    if (_font) CFRelease(_font);
}

#pragma mark - Public

- (void)load:(__autoreleasing NSError **)error {
    [self.attributes removeAllObjects];
    [self.codepoints removeAllObjects];

    NSMutableIndexSet *allGlyphs = [NSMutableIndexSet indexSet];

    for (uint32_t codepoint = 0; codepoint <= 0xFFFFu; codepoint++) {
        UniChar index = codepoint;
        CGGlyph glyph = 0;

        if (CTFontGetGlyphsForCharacters(self.font, &index, &glyph, 1) && glyph != 0) {
            [allGlyphs addIndex:glyph];
            self.codepoints[@(codepoint)] = @(glyph);
        }
    }

    NSMutableData *data = [NSMutableData dataWithLength:self.width * self.height];
    NSUInteger padding = 1;
    __block NSUInteger x = padding;
    __block NSUInteger y = padding;
    __block NSUInteger rowHeight = 0;
    __block NSError *blockError = nil;

    [allGlyphs enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
        CGGlyph glyph = index;
        CGRect bbox = CGRectZero;

        CTFontGetBoundingRectsForGlyphs(self.font, kCTFontOrientationHorizontal, &glyph, &bbox, 1);
        bbox = CGRectInset(bbox, -1.0, -1.0);
        bbox = CGRectIntegral(bbox);

        CGSize advance = CGSizeZero;

        CTFontGetAdvancesForGlyphs(self.font, kCTFontOrientationHorizontal, &glyph, &advance, 1);

        size_t width = (size_t)MAX(0.0, bbox.size.width);
        size_t height = (size_t)MAX(0.0, bbox.size.height);

        if (width == 0 || height == 0) {
            glyph_attributes_t glyph_attributes = {
                .advance_x = advance.width,
                .bearing_x = bbox.origin.x,
                .bearing_y = bbox.origin.y,
                .width = (float)width,
                .height = (float)height,
                .uv = {0.0f, 0.0f, 0.0f, 0.0f},
            };

            self.attributes[@(glyph)] = [NSValue valueWithBytes:&glyph_attributes objCType:@encode(typeof(glyph_attributes))];

            return;
        }

        if (x + width + padding >= self.width) {
            x = padding;
            y += rowHeight + padding;
            rowHeight = 0;
        }

        if (y + height + padding > self.height) {
            blockError = NSErrorLog(ERANGE, @"texture image size exceeded");
            *stop = YES;

            return;
        }

        NSMutableData *glyphData = [NSMutableData dataWithLength:width * height];
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
        CGContextRef context = CGBitmapContextCreate(glyphData.mutableBytes, width, height, 8, width, colorSpace, (CGBitmapInfo)kCGImageAlphaNone);

        CGColorSpaceRelease(colorSpace);
        CGContextSetGrayFillColor(context, 1.0, 1.0);

        CGPoint origin = CGPointMake(-bbox.origin.x, -bbox.origin.y);

        CTFontDrawGlyphs(self.font, &glyph, &origin, 1, context);
        CGContextRelease(context);

        for (size_t i = 0; i < height; i++) {
            uint8_t *source = glyphData.mutableBytes + i * width;
            uint8_t *dest = data.mutableBytes + (y + i) * (size_t)self.width + x;

            memcpy(dest, source, width);
        }

        glyph_attributes_t glyph_attributes = {
            .advance_x = advance.width,
            .bearing_x = bbox.origin.x,
            .bearing_y = bbox.origin.y,
            .width = (float)width,
            .height = (float)height,
            .uv = {
                (float)x / (float)self.width,
                (float)(y + height) / (float)self.height,
                (float)(x + width) / (float)self.width,
                (float)y / (float)self.height,
            },
        };

        self.attributes[@(glyph)] = [NSValue valueWithBytes:&glyph_attributes objCType:@encode(typeof(glyph_attributes))];
        x += width + padding;
        rowHeight = MAX(rowHeight, height);
    }];

    if (blockError && error) *error = [blockError copy];

    self.data = data;
}

- (BOOL)find:(uint32_t)codepoint glyph:(uint32_t *)glyph attributes:(glyph_attributes_t *)attributes {
    NSNumber *glyphNumber = self.codepoints[@(codepoint)];

    if (!glyphNumber) return NO;
    if (glyph) *glyph = (uint32_t)glyphNumber.unsignedIntValue;

    NSValue *value = self.attributes[glyphNumber];

    if (!value) return NO;
    if (attributes) [value getValue:attributes];

    return YES;
}

@end
