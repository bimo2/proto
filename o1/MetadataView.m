//
//  MetadataView.m
//  o1
//
//  Created by grok-4.7-high-fast on 2026-10-04.
//

#import "MetadataView.h"

#import <math.h>

static const float kMetadataFontSize = 10.5f;
static const float kMetadataLabelSpacing = 20.0f;

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
    size_t bytes = self.screen ? screen_total_memory(self.screen) : 0;
    NSString *pidLabel = [NSString stringWithFormat:@"PID %ld", self.pid];
    NSString *memoryLabel = [NSString stringWithFormat:@"%lu bytes", (unsigned long)bytes];

    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName : [NSFont monospacedSystemFontOfSize:kMetadataFontSize weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName : [NSColor whiteColor],
    };

    NSSize pidSize = [pidLabel sizeWithAttributes:attributes];
    NSSize memorySize = [memoryLabel sizeWithAttributes:attributes];
    CGFloat originY = -NSWidth(self.bounds) / 2.0;
    CGFloat spacing = NSHeight(self.bounds) - pidSize.width - memorySize.width;
    CGContextRef context = [NSGraphicsContext currentContext].CGContext;

    CGContextSaveGState(context);
    CGContextTranslateCTM(context, NSMidX(self.bounds), NSMidY(self.bounds));
    CGContextRotateCTM(context, -M_PI_2);

    if (spacing >= kMetadataLabelSpacing) [pidLabel drawInRect:NSMakeRect(-NSHeight(self.bounds) / 2.0, originY, pidSize.width, pidSize.height) withAttributes:attributes];

    [memoryLabel drawInRect:NSMakeRect(NSHeight(self.bounds) / 2.0 - memorySize.width, originY, memorySize.width, memorySize.height) withAttributes:attributes];
    CGContextRestoreGState(context);
}

#pragma mark - Public

- (void)setPID:(NSInteger)pid {
    _pid = pid;
    [self setNeedsDisplay:YES];
}

- (void)setScreen:(screen_t *)screen {
    _screen = screen;
    [self setNeedsDisplay:YES];
}

@end
