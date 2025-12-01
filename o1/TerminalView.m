//
//  TerminalView.m
//  o1
//
//  Created by gpt-5.1-high on 2025-11-26.
//

#import "TerminalView.h"

#import "Terminal+UserDefaults.h"

#include "shaders_cpu.h"

@interface TerminalView ()

@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, assign) NSUInteger rows;
@property (nonatomic, assign) NSUInteger columns;
@property (nonatomic, assign) CGFloat cellWidth;
@property (nonatomic, assign) CGFloat cellHeight;

@end

@implementation TerminalView

- (instancetype)initWithFrame:(NSRect)frameRect {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();

    NSAssert(device, @"metal device not supported");

    self = [super initWithFrame:frameRect device:device];

    if (self) {
        self.delegate = self;
        self.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
        self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
        self.layer.opaque = NO;
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.paused = NO;
        self.enableSetNeedsDisplay = NO;
        _commandQueue = [device newCommandQueue];

        NSError *error = nil;
        id<MTLLibrary> library = [device newDefaultLibraryWithBundle:NSBundle.mainBundle error:&error];

        NSAssert(library, @"failed to load metal library: %@", error);

        id<MTLFunction> vertexFunction = [library newFunctionWithName:@CPU_DOT_VERTEX_SHADER];
        id<MTLFunction> fragmentFunction = [library newFunctionWithName:@CPU_DOT_FRAGMENT_SHADER];
        MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];

        descriptor.vertexFunction = vertexFunction;
        descriptor.fragmentFunction = fragmentFunction;
        descriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat;
        descriptor.colorAttachments[0].blendingEnabled = YES;
        descriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        _pipelineState = [device newRenderPipelineStateWithDescriptor:descriptor error:&error];
        NSAssert(_pipelineState, @"failed to create render pipeline: %@", error);

        _rows = [Terminal rows];
        _columns = [Terminal columns];
        [self updateCellSize];
    }

    return self;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    [self updateCellSize];
}

- (void)drawInMTKView:(MTKView *)view {
    MTLRenderPassDescriptor *descriptor = view.currentRenderPassDescriptor;

    if (!descriptor) return;

    id<MTLCommandBuffer> buffer = [self.commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:descriptor];

    if (self.rows > 0 && self.columns > 0) {
        [encoder setRenderPipelineState:self.pipelineState];

        cpu_grid_uniforms_t uniforms = {
            .viewport_size = simd_make_float2((float)self.bounds.size.width, (float)self.bounds.size.height),
            .cell_size = simd_make_float2((float)self.cellWidth, (float)self.cellHeight),
            .grid_size = simd_make_uint2((uint32_t)self.columns, (uint32_t)self.rows),
            .dot_size = 2.0f,
        };

        [encoder setVertexBytes:&uniforms length:sizeof(uniforms) atIndex:0];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6 instanceCount:self.rows * self.columns];
    }

    [encoder endEncoding];
    [buffer presentDrawable:view.currentDrawable];
    [buffer commit];
}

- (void)updateCellSize {
    CGSize size = self.bounds.size;

    if (size.width > 0 && size.height > 0 && self.rows > 0 && self.columns > 0) {
        self.cellWidth = size.width / self.columns;
        self.cellHeight = size.height / self.rows;
    }
}

@end
