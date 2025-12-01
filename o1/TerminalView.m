//
//  TerminalView.m
//  o1
//
//  Created by gpt-5.1-high on 2025-11-26.
//

#import "TerminalView.h"

@interface TerminalView ()

@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;

@end

@implementation TerminalView

- (instancetype)initWithFrame:(NSRect)frameRect {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();

    NSAssert(device, @"metal device not supported");

    self = [super initWithFrame:frameRect device:device];

    if (self) {
        _commandQueue = [device newCommandQueue];
        self.delegate = self;
        self.clearColor = MTLClearColorMake(0, 0, 0, 0);
        self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
        self.layer.opaque = NO;
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.paused = NO;
        self.enableSetNeedsDisplay = NO;
    }

    return self;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // TODO
}

- (void)drawInMTKView:(MTKView *)view {
    MTLRenderPassDescriptor *descriptor = view.currentRenderPassDescriptor;

    if (!descriptor) return;

    id<MTLCommandBuffer> buffer = [self.commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:descriptor];

    [encoder endEncoding];
    [buffer presentDrawable:view.currentDrawable];
    [buffer commit];
}

@end
