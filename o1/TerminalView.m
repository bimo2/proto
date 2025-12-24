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

    self.buffer = [self.device newBufferWithLength:instanceCount * sizeof(cpu_glyph_instance_t) options:MTLResourceStorageModeShared];
    self.instanceCount = instanceCount;

    cpu_glyph_instance_t *instances = (cpu_glyph_instance_t *)self.buffer.contents;

    if (!instances) return;

    for (NSUInteger row = 0; row < self.rows; row++) {
        for (NSUInteger column = 0; column < self.columns; column++) {
            NSUInteger index = row * self.columns + column;

            [self update:&instances[index] row:row column:column codepoint:' ' attributes:NULL];
        }
    }
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
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:12 instanceCount:self.instanceCount];
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
}

- (void)update:(cpu_glyph_instance_t *)instance row:(NSUInteger)row column:(NSUInteger)column codepoint:(uint32_t)codepoint attributes:(const ansi_sgr_t *)attributes {
    if (!instance) return;

    if (codepoint == 0) codepoint = ' ';

    glyph_attributes_t glyphAttrs;

    memset(&glyphAttrs, 0, sizeof(glyphAttrs));

    uint32_t glyph = 0;
    BOOL hasGlyph = [self.typeset find:codepoint glyph:&glyph attributes:&glyphAttrs];

    if (!hasGlyph) [self.typeset find:' ' glyph:&glyph attributes:&glyphAttrs];

    uint32_t fg_packed = attributes ? attributes->fg_color : ANSI_COLOR_RESET;
    uint32_t bg_packed = attributes ? attributes->bg_color : ANSI_COLOR_RESET;
    simd_float4 fg_color = cpu_rgba_color(fg_packed, false);
    simd_float4 bg_color = cpu_rgba_color(bg_packed, true);

    if (attributes && (attributes->flags & ANSI_SGR_FLAG_INVERSE)) {
        simd_float4 reverse = fg_color;

        fg_color = bg_color;
        bg_color = reverse;
    }

    instance->glyph_id = glyph;
    instance->position = simd_make_float2((float)column, (float)(self.rows - 1 - row));
    instance->uv = simd_make_float4(glyphAttrs.uv[0], glyphAttrs.uv[1], glyphAttrs.uv[2], glyphAttrs.uv[3]);
    instance->size = simd_make_float2(glyphAttrs.width, glyphAttrs.height);
    instance->bearing = simd_make_float2(glyphAttrs.bearing_x, glyphAttrs.bearing_y);
    instance->fg_color = fg_color;
    instance->bg_color = bg_color;
}

- (void)applySpan:(const render_op_span_t *)span {
    cpu_glyph_instance_t *instances = (cpu_glyph_instance_t *)self.buffer.contents;

    if (!instances) return;

    NSUInteger row = (NSUInteger)span->row;

    if (row >= self.rows) return;

    for (NSUInteger i = 0; i < span->width; i++) {
        NSUInteger column = (NSUInteger)span->column + i;

        if (column >= self.columns) break;

        [self update:&instances[row * self.columns + column] row:row column:column codepoint:span->cells[i].codepoint attributes:&span->cells[i].attributes];
    }
}

- (void)applyScroll:(const render_op_scroll_t *)scroll {
    cpu_glyph_instance_t *instances = (cpu_glyph_instance_t *)self.buffer.contents;

    if (!instances) return;

    NSInteger top = MAX(0, scroll->top);
    NSInteger bottom = MIN((NSInteger)self.rows - 1, scroll->bottom);

    if (top > bottom || scroll->delta == 0) return;

    NSInteger height = bottom - top + 1;
    NSInteger shift = MIN(height, labs(scroll->delta));
    size_t size = self.columns * sizeof(cpu_glyph_instance_t);

    if (scroll->delta > 0) {
        for (NSInteger row = top; row <= bottom - shift; row++) memmove(instances + (row * self.columns), instances + ((row + shift) * self.columns), size);

        for (NSInteger row = bottom - shift + 1; row <= bottom; row++) {
            for (NSUInteger column = 0; column < self.columns; column++) {
                NSUInteger index = (NSUInteger)row * self.columns + column;

                [self update:&instances[index] row:row column:column codepoint:' ' attributes:NULL];
            }
        }
    } else {
        for (NSInteger row = bottom; row >= top + shift; row--) memmove(instances + (row * self.columns), instances + ((row - shift) * self.columns), size);

        for (NSInteger row = top; row < top + shift; row++) {
            for (NSUInteger column = 0; column < self.columns; column++) {
                NSUInteger index = (NSUInteger)row * self.columns + column;

                [self update:&instances[index] row:row column:column codepoint:' ' attributes:NULL];
            }
        }
    }
}

@end
