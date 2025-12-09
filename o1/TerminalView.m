//
//  TerminalView.m
//  o1
//
//  Created by gpt-5.1-high on 2025-11-26.
//

#import "TerminalView.h"

#import "FontTexture.h"

#include "shaders_cpu.h"

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
@property (nonatomic, assign) CGFloat unitWidth;
@property (nonatomic, assign) CGFloat unitHeight;

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
        self.clearColor = MTLClearColorMake(0,0,0,0);
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
    self.typeset = [[FontTexture alloc] initWithName:@"SF Mono" size:12 weight:NSFontWeightRegular scale:self.scale];
    [self.typeset load];

    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm width:self.typeset.width height:self.typeset.height mipmapped:NO];

    self.texture = [self.device newTextureWithDescriptor:descriptor];

    MTLOrigin origin = MTLOriginMake(0, 0, 0);
    MTLSize size = MTLSizeMake(self.typeset.width, self.typeset.height, 1);
    MTLRegion region = {origin, size};

    [self.texture replaceRegion:region mipmapLevel:0 withBytes:self.typeset.data.bytes bytesPerRow:self.typeset.width];
    self.unitWidth = self.drawableSize.width / self.columns;
    self.unitHeight = self.drawableSize.height / self.rows;
    [self test];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    self.unitWidth = size.width / self.columns;
    self.unitHeight = size.height / self.rows;
}

- (void)drawInMTKView:(MTKView *)view {
    MTLRenderPassDescriptor *descriptor = view.currentRenderPassDescriptor;

    if (!descriptor) return;

    id<MTLCommandBuffer> buffer = [self.commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:descriptor];

    [encoder setRenderPipelineState:self.pipeline];

    cpu_grid_uniforms_t uniforms = {
        .viewport_size = simd_make_float2((float)self.drawableSize.width, (float)self.drawableSize.height),
        .unit_size = simd_make_float2((float)self.unitWidth, (float)self.unitHeight)
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

- (void)test {
    NSMutableData *data = [NSMutableData data];
    NSArray<NSNumber *> *keys = self.typeset.attributes.allKeys;
    NSUInteger total = keys.count;

    for (NSUInteger i = 0; i < self.rows; i++) {
        for (NSUInteger j = 0; j < self.columns; j++) {
            uint32_t glyph_id = keys[arc4random_uniform((uint32_t)total)].unsignedIntValue;
            glyph_attributes_t attributes;
            NSValue *value = self.typeset.attributes[@(glyph_id)];

            [value getValue:&attributes];

            cpu_glyph_instance_t instance;

            instance.glyph_id = glyph_id;
            instance.position = simd_make_float2((float)j, (float)i);
            instance.uv = simd_make_float4(attributes.uv[0], attributes.uv[1], attributes.uv[2], attributes.uv[3]);
            instance.size = simd_make_float2(attributes.width, attributes.height);
            instance.bearing = simd_make_float2(attributes.bearing_x, attributes.bearing_y);
            instance.fg_color = simd_make_float4(1.0f, 1.0f, 1.0f, 1.0f);
            instance.bg_color = simd_make_float4(0.0f, 0.0f, 0.0f, 1.0f);
            [data appendBytes:&instance length:sizeof(instance)];
        }
    }

    self.buffer = [self.device newBufferWithBytes:data.bytes length:data.length options:MTLResourceStorageModeShared];
    self.instanceCount = self.rows * self.columns;
}

@end
