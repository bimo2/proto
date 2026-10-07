//
//  MetadataView.m
//  o1
//
//  Created by grok-4.7-high-fast on 2026-10-04.
//

#import "MetadataView.h"

#include "include.h"

#include <math.h>

static const float kMetadataFontSize = 10.5f;
static const float kMetadataLabelSpacing = 20.0f;
static int fractional(double, int, int);

@interface MetadataView ()

@property (nonatomic, copy) NSDictionary<NSAttributedStringKey, id> *attributes;

@end

@implementation MetadataView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.wantsLayer = YES;
        self.clipsToBounds = YES;
        self.layer.backgroundColor = [NSColor clearColor].CGColor;

        _attributes = @{
            NSFontAttributeName : [NSFont monospacedSystemFontOfSize:kMetadataFontSize weight:NSFontWeightSemibold],
            NSForegroundColorAttributeName : [NSColor whiteColor],
        };
    }

    return self;
}

#pragma mark - NSView

- (BOOL)isOpaque {
    return NO;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSString *pidLabel = [NSString stringWithFormat:@"PID %ld", self.pid];
    NSString *memoryLabel = [NSString stringWithFormat:@"%ld / %@", (long)self.lines, [self formatMemory:self.bytes]];

    NSSize pidSize = [pidLabel sizeWithAttributes:self.attributes];
    NSSize memorySize = [memoryLabel sizeWithAttributes:self.attributes];
    CGFloat originY = -NSWidth(self.bounds) / 2.0;
    CGFloat spacing = NSHeight(self.bounds) - pidSize.width - memorySize.width;
    CGContextRef context = [NSGraphicsContext currentContext].CGContext;

    CGContextSaveGState(context);
    CGContextTranslateCTM(context, NSMidX(self.bounds), NSMidY(self.bounds));
    CGContextRotateCTM(context, -M_PI_2);

    if (spacing >= kMetadataLabelSpacing) [pidLabel drawInRect:NSMakeRect(-NSHeight(self.bounds) / 2.0, originY, pidSize.width, pidSize.height) withAttributes:self.attributes];

    [memoryLabel drawInRect:NSMakeRect(NSHeight(self.bounds) / 2.0 - memorySize.width, originY, memorySize.width, memorySize.height) withAttributes:self.attributes];
    CGContextRestoreGState(context);
}

#pragma mark - Public

- (void)setPID:(NSInteger)pid {
    _pid = pid;
    [self setNeedsDisplay:YES];
}

- (void)setLines:(NSUInteger)lines {
    _lines = lines;
    [self setNeedsDisplay:YES];
}

- (void)setBytes:(NSUInteger)bytes {
    _bytes = bytes;
    [self setNeedsDisplay:YES];
}

#pragma mark - Private

- (NSString *)formatMemory:(NSUInteger)bytes {
    double value;
    NSString *unit;

    if ((double)bytes >= 1.001 * _GB(1)) {
        value = (double)bytes / _GB(1);
        unit = @"GB";
    } else if ((double)bytes >= 1.001 * _MB(1)) {
        value = (double)bytes / _MB(1);
        unit = @"MB";
    } else {
        value = (double)bytes / _KB(1);
        unit = @"kB";
    }

    int points = fractional(value, 4, 3);
    double scale = pow(10.0, (double)points);
    double rounded = round(value * scale) / scale;

    points = fractional(rounded, 4, 3);

    return [NSString stringWithFormat:@"%.*f %@", points, rounded, unit];
}

@end

static int fractional(double value, int digits, int max_float) {
    if (value <= 0.0) return max_float;

    int magnitude = (int)floor(log10(value) + 1e-10);
    int points = digits - magnitude - 1;

    if (points < 0) points = 0;
    if (points > max_float) points = max_float;

    return points;
}
