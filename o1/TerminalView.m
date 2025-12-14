//
//  TerminalView.m
//  o1
//
//  Created by gpt-5.1-high on 2025-11-26.
//

#import "TerminalView.h"

#import "FontTexture.h"

#include "render.h"
#include "shaders_cpu.h"

#include <string.h>

@interface TerminalView ()

@property (nonatomic, strong) FontTexture *typeset;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipeline;
@property (nonatomic, strong) id<MTLSamplerState> sampler;
@property (nonatomic, strong) id<MTLTexture> texture;
@property (nonatomic, strong) id<MTLBuffer> buffer;
@property (nonatomic, strong) NSMutableData *codepoints;
@property (nonatomic, assign) NSUInteger rows;
@property (nonatomic, assign) NSUInteger columns;
@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, assign) NSUInteger instanceCount;
@property (nonatomic, assign) CGFloat cellWidth;
@property (nonatomic, assign) CGFloat cellHeight;

@end

@implementation TerminalView

- (instancetype)initWithFrame:(NSRect)frame {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();

    NSAssert(device, @"metal device not supported");

    self = [super initWithFrame:frame device:device];

    if (self) {
        self.delegate = self;
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.wantsLayer = YES;
        self.layer.opaque = NO;
        self.framebufferOnly = NO;
        self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
        self.clearColor = MTLClearColorMake(0, 0, 0, 0);
        self.enableSetNeedsDisplay = NO;
        self.paused = NO;

        _commandQueue = [device newCommandQueue];

        id<MTLLibrary> library = [device newDefaultLibraryWithBundle:NSBundle.mainBundle error:nil];
        MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];

        pipelineDescriptor.vertexFunction = [library newFunctionWithName:@CPU_TERMINAL_VERTEX_SHADER];
        pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@CPU_TERMINAL_FRAGMENT_SHADER];
        pipelineDescriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat;
        pipelineDescriptor.colorAttachments[0].blendingEnabled = YES;
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

        _pipeline = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:nil];

        MTLSamplerDescriptor *samplerDescriptor = [[MTLSamplerDescriptor alloc] init];

        samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
        samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
        samplerDescriptor.sAddressMode = MTLSamplerAddressModeClampToEdge;
        samplerDescriptor.tAddressMode = MTLSamplerAddressModeClampToEdge;

        _sampler = [device newSamplerStateWithDescriptor:samplerDescriptor];
    }

    return self;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];

    if (!self.window) return;

    self.rows = 24;
    self.columns = 80;
    self.scale = self.window.screen.backingScaleFactor;
    self.drawableSize = CGSizeMake(self.bounds.size.width * self.scale, self.bounds.size.height * self.scale);
    self.typeset = [[FontTexture alloc] initWithName:@"" size:12 weight:NSFontWeightRegular scale:self.scale];
    [self.typeset load:nil];

    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm width:self.typeset.width height:self.typeset.height mipmapped:NO];

    self.texture = [self.device newTextureWithDescriptor:descriptor];

    MTLOrigin origin = MTLOriginMake(0, 0, 0);
    MTLSize size = MTLSizeMake(self.typeset.width, self.typeset.height, 1);
    MTLRegion region = {origin, size};

    [self.texture replaceRegion:region mipmapLevel:0 withBytes:self.typeset.data.bytes bytesPerRow:self.typeset.width];
    self.cellWidth = self.drawableSize.width / self.columns;
    self.cellHeight = self.drawableSize.height / self.rows;

    NSUInteger instanceCount = self.rows * self.columns;

    self.codepoints = [NSMutableData dataWithLength:instanceCount * sizeof(uint32_t)];
    self.buffer = [self.device newBufferWithLength:instanceCount * sizeof(cpu_glyph_instance_t) options:MTLResourceStorageModeShared];
    self.instanceCount = instanceCount;

    uint32_t *grid = (uint32_t *)self.codepoints.mutableBytes;

    if (grid) {
        for (size_t i = 0; i < instanceCount; i++) grid[i] = ' ';
    }

    [self updateInstances];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    self.cellWidth = size.width / self.columns;
    self.cellHeight = size.height / self.rows;
}

- (void)drawInMTKView:(MTKView *)view {
    MTLRenderPassDescriptor *descriptor = view.currentRenderPassDescriptor;

    if (!descriptor) return;
    if (!self.buffer) return;

    id<MTLCommandBuffer> buffer = [self.commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:descriptor];

    [encoder setRenderPipelineState:self.pipeline];

    cpu_grid_uniforms_t uniforms = {
        .viewport_size = simd_make_float2((float)self.drawableSize.width, (float)self.drawableSize.height),
        .cell_size = simd_make_float2((float)self.cellWidth, (float)self.cellHeight)
    };

    [encoder setVertexBytes:&uniforms length:sizeof(uniforms) atIndex:0];
    [encoder setVertexBuffer:self.buffer offset:0 atIndex:1];
    [encoder setFragmentTexture:self.texture atIndex:0];
    [encoder setFragmentSamplerState:self.sampler atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6 instanceCount:self.instanceCount];
    [encoder endEncoding];
    [buffer presentDrawable:view.currentDrawable];
    [buffer commit];
}

- (void)render:(const render_t *)ops count:(size_t)count {
    if (!ops || count < 1) return;

    for (size_t i = 0; i < count; i++) {
        const render_t *diff = &ops[i];

        switch (diff->op) {
            case RENDER_OP_SPAN:
                [self applySpan:&diff->span];

                break;
            case RENDER_OP_SCROLL:
                [self applyScroll:&diff->scroll];

                break;
            default:
                break;
        }
    }

    [self updateInstances];
}

- (void)updateInstances {
    cpu_glyph_instance_t *instances = (cpu_glyph_instance_t *)self.buffer.contents;
    uint32_t *grid = (uint32_t *)self.codepoints.mutableBytes;

    if (!instances || !grid) return;

    for (NSUInteger row = 0; row < self.rows; row++) {
        for (NSUInteger column = 0; column < self.columns; column++) {
            NSUInteger index = row * self.columns + column;
            uint32_t codepoint = grid[index];

            if (codepoint == 0) codepoint = ' ';

            cpu_glyph_instance_t instance;
            glyph_attributes_t attributes;

            memset(&instance, 0, sizeof(typeof(instance)));
            memset(&attributes, 0, sizeof(typeof(attributes)));

            uint32_t glyph = 0;
            BOOL hasGlyph = [self.typeset find:codepoint glyph:&glyph attributes:&attributes];

            if (!hasGlyph) [self.typeset find:' ' glyph:&glyph attributes:&attributes];

            instance.glyph_id = glyph;
            instance.position = simd_make_float2((float)column, (float)(self.rows - 1 - row));
            instance.uv = simd_make_float4(attributes.uv[0], attributes.uv[1], attributes.uv[2], attributes.uv[3]);
            instance.size = simd_make_float2(attributes.width, attributes.height);
            instance.bearing = simd_make_float2(attributes.bearing_x, attributes.bearing_y);
            instance.fg_color = simd_make_float4(1.0f, 1.0f, 1.0f, 1.0f);
            instance.bg_color = simd_make_float4(0.0f, 0.0f, 0.0f, 1.0f);
            instances[index] = instance;
        }
    }
}

- (void)applySpan:(const render_op_span_t *)span {
    uint32_t *grid = (uint32_t *)self.codepoints.mutableBytes;

    if (!grid) return;

    NSUInteger row = (NSUInteger)span->row;

    if (row >= self.rows) return;

    for (NSUInteger i = 0; i < span->width; i++) {
        NSUInteger column = (NSUInteger)span->column + i;

        if (column >= self.columns) break;

        uint32_t codepoint = span->cells[i].codepoint;

        if (codepoint == 0) codepoint = ' ';

        grid[row * self.columns + column] = codepoint;
    }
}

- (void)applyScroll:(const render_op_scroll_t *)scroll {
    uint32_t *grid = (uint32_t *)self.codepoints.mutableBytes;

    if (!grid) return;

    NSInteger top = MAX(0, scroll->top);
    NSInteger bottom = MIN((NSInteger)self.rows - 1, scroll->bottom);

    if (top > bottom || scroll->delta == 0) return;

    NSInteger height = bottom - top + 1;
    NSInteger shift = MIN(height, labs(scroll->delta));
    size_t width = self.columns * sizeof(uint32_t);

    if (scroll->delta > 0) {
        for (NSInteger row = top; row <= bottom - shift; row++) memmove(grid + (row * self.columns), grid + ((row + shift) * self.columns), width);
        for (NSInteger row = bottom - shift + 1; row <= bottom; row++) memset(grid + (row * self.columns), 0, width);
    } else {
        for (NSInteger row = bottom; row >= top + shift; row--) memmove(grid + (row * self.columns), grid + ((row - shift) * self.columns), width);
        for (NSInteger row = top; row < top + shift; row++) memset(grid + (row * self.columns), 0, width);
    }
}

@end
