//
//  TerminalView.m
//  o1
//
//  Created by gpt-5.1-high on 2025-11-26.
//

#import "TerminalView.h"

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

@interface TerminalView ()

@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) MTLClearColor clearColor;

@end

@implementation TerminalView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];

    if (self) {
        _device = MTLCreateSystemDefaultDevice();
        NSAssert(_device, @"metal device not supported");

        _commandQueue = [_device newCommandQueue];
        _clearColor = MTLClearColorMake(0, 0, 0, 0);
        self.wantsLayer = YES;
        self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self updateDrawableSize];
    }

    return self;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self updateDrawableSize];
}

- (void)viewDidChangeBackingProperties {
    [super viewDidChangeBackingProperties];
    [self updateDrawableSize];
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self updateDrawableSize];
}

- (CALayer *)makeBackingLayer {
    CAMetalLayer *layer = [CAMetalLayer layer];

    layer.device = self.device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.framebufferOnly = YES;
    layer.opaque = NO;
    layer.backgroundColor = nil;
    layer.contentsGravity = kCAGravityResize;
    layer.needsDisplayOnBoundsChange = YES;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);

    layer.colorspace = colorSpace;
    CGColorSpaceRelease(colorSpace);

    return layer;
}

- (BOOL)wantsUpdateLayer {
    return YES;
}

- (void)updateLayer {
    CAMetalLayer *layer = (CAMetalLayer *)self.layer;

    if (!layer || !self.commandQueue) return;

    id<CAMetalDrawable> drawable = layer.nextDrawable;

    if (!drawable) return;

    MTLRenderPassDescriptor *descriptor = [MTLRenderPassDescriptor renderPassDescriptor];

    descriptor.colorAttachments[0].texture = drawable.texture;
    descriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    descriptor.colorAttachments[0].clearColor = _clearColor;

    id<MTLCommandBuffer> buffer = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:descriptor];

    [encoder endEncoding];
    [buffer presentDrawable:drawable];
    [buffer commit];
}

- (void)updateDrawableSize {
    CAMetalLayer *layer = (CAMetalLayer *)self.layer;

    if (!layer) return;

    CGFloat scale = self.window.backingScaleFactor;
    CGSize bounds = self.bounds.size;

    layer.contentsScale = scale;
    layer.drawableSize = CGSizeMake(bounds.width * scale, bounds.height * scale);
}

@end
