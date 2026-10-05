//
//  MetadataView.m
//  o1
//
//  Created by grok-4.7-high-fast on 2026-10-04.
//

#import "MetadataView.h"

#import <math.h>

static const float kMetadataFontSize = 10.5f;

@implementation MetadataView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.wantsLayer = YES;
        self.clipsToBounds = YES;
        self.layer.backgroundColor = NSColor.clearColor.CGColor;
    }

    return self;
}

#pragma mark - NSView

- (BOOL)isOpaque {
    return NO;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSString *label = [NSString stringWithFormat:@"PID %ld", self.pid];

    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName : [NSFont monospacedSystemFontOfSize:kMetadataFontSize weight:NSFontWeightBold],
        NSForegroundColorAttributeName : [NSColor whiteColor],
    };

    NSSize size = [label sizeWithAttributes:attributes];
    CGFloat originX = -NSHeight(self.bounds) / 2.0;
    CGFloat originY = -NSWidth(self.bounds) / 2.0;
    CGContextRef context = [NSGraphicsContext currentContext].CGContext;

    CGContextSaveGState(context);
    CGContextTranslateCTM(context, NSMidX(self.bounds), NSMidY(self.bounds));
    CGContextRotateCTM(context, -M_PI_2);
    [label drawInRect:NSMakeRect(originX, originY, size.width, size.height) withAttributes:attributes];
    CGContextRestoreGState(context);
}

#pragma mark - Public

- (void)setPID:(NSInteger)pid {
    _pid = pid;
    [self setNeedsDisplay:YES];
}

@end
