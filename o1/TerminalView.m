//
//  TerminalView.m
//  o1
//
//  Created by gpt-5.1-high on 2025-11-26.
//

#import "TerminalView.h"

#import "FontTexture.h"

#include "ansi.h"
#include "render.h"
#include "shaders_cpu.h"

#include <math.h>
#include <string.h>

@interface TerminalView ()

@property (nonatomic, strong) NSMutableDictionary<NSNumber *, FontTexture *> *typesets;
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
@property (nonatomic, assign) CGFloat textBaseline;
@property (nonatomic, assign) CGFloat queuedOffset;

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
        self.enableSetNeedsDisplay = YES;
        self.paused = YES;
        _typesets = [NSMutableDictionary dictionary];
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

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    CGFloat scale = self.window.screen.backingScaleFactor;

    if (scale > 0 && self.scale != scale) [self setup:scale];

    NSUInteger rows = floor((double)size.height / (double)self.cellHeight);
    NSUInteger columns = floor((double)size.width / (double)self.cellWidth);

    if (rows < 1) rows = 1;
    if (columns < 1) columns = 1;

    if (rows != self.rows || columns != self.columns) {
        self.rows = rows;
        self.columns = columns;

        NSUInteger instanceCount = self.rows * self.columns;

        self.buffer = [self.device newBufferWithLength:instanceCount * sizeof(cpu_glyph_instance_t) options:MTLResourceStorageModeShared];
        self.instanceCount = instanceCount;
        [self.terminal layout:NSMakeSize(size.width, size.height) rows:rows columns:columns];
    }
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
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:CPU_TERMINAL_VERTEX_COUNT instanceCount:self.instanceCount];
    [encoder endEncoding];
    [buffer presentDrawable:view.currentDrawable];
    [buffer commit];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)keyDown:(NSEvent *)event {
    if (!self.terminal || event.modifierFlags & NSEventModifierFlagCommand) {
        [super keyDown:event];

        return;
    }

    if (event.charactersIgnoringModifiers.length == 1) {
        unichar key = [event.charactersIgnoringModifiers characterAtIndex:0];

        switch (key) {
            case NSDeleteFunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_DELETE flags:event.modifierFlags];

                return;
            case NSInsertFunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_INSERT flags:event.modifierFlags];

                return;
            case NSUpArrowFunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_UP flags:event.modifierFlags];

                return;
            case NSDownArrowFunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_DOWN flags:event.modifierFlags];

                return;
            case NSLeftArrowFunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_LEFT flags:event.modifierFlags];

                return;
            case NSRightArrowFunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_RIGHT flags:event.modifierFlags];

                return;
            case NSHomeFunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_HOME flags:event.modifierFlags];

                return;
            case NSEndFunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_END flags:event.modifierFlags];

                return;
            case NSPageUpFunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_PAGE_UP flags:event.modifierFlags];

                return;
            case NSPageDownFunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_PAGE_DOWN flags:event.modifierFlags];

                return;
            case NSF1FunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_F1 flags:event.modifierFlags];

                return;
            case NSF2FunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_F2 flags:event.modifierFlags];

                return;
            case NSF3FunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_F3 flags:event.modifierFlags];

                return;
            case NSF4FunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_F4 flags:event.modifierFlags];

                return;
            case NSF5FunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_F5 flags:event.modifierFlags];

                return;
            case NSF6FunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_F6 flags:event.modifierFlags];

                return;
            case NSF7FunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_F7 flags:event.modifierFlags];

                return;
            case NSF8FunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_F8 flags:event.modifierFlags];

                return;
            case NSF9FunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_F9 flags:event.modifierFlags];

                return;
            case NSF10FunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_F10 flags:event.modifierFlags];

                return;
            case NSF11FunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_F11 flags:event.modifierFlags];

                return;
            case NSF12FunctionKey:
                [self.terminal keyboard:ANSI_KEYBOARD_F12 flags:event.modifierFlags];

                return;
        }

        if (event.modifierFlags & NSEventModifierFlagControl) {
            uint8_t byte = 0x00u;

            if (ansi_control(key, &byte)) {
                [self.terminal write:[NSData dataWithBytes:&byte length:1]];

                return;
            }
        }

        switch (key) {
            case 0x1B:
                [self.terminal keyboard:ANSI_KEYBOARD_ESCAPE flags:event.modifierFlags];

                return;
            case NSEnterCharacter:
            case NSNewlineCharacter:
            case NSCarriageReturnCharacter:
                [self.terminal keyboard:ANSI_KEYBOARD_ENTER flags:event.modifierFlags];

                return;
            case NSTabCharacter:
                [self.terminal keyboard:ANSI_KEYBOARD_TAB flags:event.modifierFlags];

                return;
            case NSBackTabCharacter:
                [self.terminal keyboard:ANSI_KEYBOARD_BACKTAB flags:event.modifierFlags];

                return;
            case NSBackspaceCharacter:
            case NSDeleteCharacter:
                [self.terminal keyboard:ANSI_KEYBOARD_BACKSPACE flags:event.modifierFlags];

                return;
        }
    }

    [self interpretKeyEvents:@[event]];
}

- (void)insertText:(id)text {
    NSString *string = nil;

    if ([text isKindOfClass:[NSAttributedString class]]) {
        string = [(NSAttributedString *)text string];
    } else if ([text isKindOfClass:[NSString class]]) {
        string = (NSString *)text;
    }

    if (string.length < 1) return;

    [self.terminal write:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)insertNewline:(id)sender {
    [self.terminal keyboard:ANSI_KEYBOARD_ENTER flags:0];
}

- (void)insertLineBreak:(id)sender {
    [self.terminal keyboard:ANSI_KEYBOARD_ENTER flags:0];
}

- (void)insertTab:(id)sender {
    [self.terminal keyboard:ANSI_KEYBOARD_TAB flags:0];
}

- (void)insertBacktab:(id)sender {
    [self.terminal keyboard:ANSI_KEYBOARD_BACKTAB flags:0];
}

- (void)deleteBackward:(id)sender {
    [self.terminal keyboard:ANSI_KEYBOARD_BACKSPACE flags:0];
}

- (void)deleteForward:(id)sender {
    [self.terminal keyboard:ANSI_KEYBOARD_DELETE flags:0];
}

- (void)moveUp:(id)sender {
    [self.terminal keyboard:ANSI_KEYBOARD_UP flags:0];
}

- (void)moveDown:(id)sender {
    [self.terminal keyboard:ANSI_KEYBOARD_DOWN flags:0];
}

- (void)moveLeft:(id)sender {
    [self.terminal keyboard:ANSI_KEYBOARD_LEFT flags:0];
}

- (void)moveRight:(id)sender {
    [self.terminal keyboard:ANSI_KEYBOARD_RIGHT flags:0];
}

- (void)moveToBeginningOfLine:(id)sender {
    [self.terminal keyboard:ANSI_KEYBOARD_HOME flags:0];
}

- (void)moveToBeginningOfParagraph:(id)sender {
    [self.terminal keyboard:ANSI_KEYBOARD_HOME flags:0];
}

- (void)moveToEndOfLine:(id)sender {
    [self.terminal keyboard:ANSI_KEYBOARD_END flags:0];
}

- (void)moveToEndOfParagraph:(id)sender {
    [self.terminal keyboard:ANSI_KEYBOARD_END flags:0];
}

- (void)scrollPageUp:(id)sender {
    [self.terminal keyboard:ANSI_KEYBOARD_PAGE_UP flags:0];
}

- (void)scrollPageDown:(id)sender {
    [self.terminal keyboard:ANSI_KEYBOARD_PAGE_DOWN flags:0];
}

- (void)scrollWheel:(NSEvent *)event {
    CGFloat delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY;
    CGFloat lines = event.hasPreciseScrollingDeltas && self.cellHeight > 0.0 ? (delta / self.cellHeight) : delta;
    CGFloat speed = 3.5;

    self.queuedOffset += lines * speed;

    NSInteger offset = trunc(self.queuedOffset);

    if (offset != 0) {
        self.queuedOffset -= offset;
        [self.terminal scroll:offset];
    }
}

- (void)paste:(id)sender {
    NSString *string = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];

    if (string.length < 1) return;

    [self.terminal paste:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)render:(const render_t *)ops count:(size_t)count {
    if (!ops || count < 1) return;

    for (size_t i = 0; i < count; i++) {
        const render_t *diff = &ops[i];

        switch (diff->op) {
            case RENDER_OP_SPAN:
                [self span:&diff->span];

                break;
            case RENDER_OP_SCROLL:
                [self scroll:&diff->scroll];

                break;
        }
    }

    [self setNeedsDisplay:YES];
}

- (void)setup:(CGFloat)scale {
    self.scale = scale;

    FontTexture *fontRegular = [[FontTexture alloc] initWithName:@"" size:12 weight:NSFontWeightRegular scale:self.scale];

    [fontRegular load:nil];
    self.typesets[@(CPU_FONT_INDEX_REGULAR)] = fontRegular;

    FontTexture *fontBold = [[FontTexture alloc] initWithName:@"" size:12 weight:NSFontWeightBold scale:self.scale];

    [fontBold load:nil];
    self.typesets[@(CPU_FONT_INDEX_BOLD)] = fontBold;

    NSUInteger fontWidth = (NSUInteger)fontRegular.width;
    NSUInteger fontHeight = (NSUInteger)fontRegular.height;
    MTLTextureDescriptor *descriptor = [[MTLTextureDescriptor alloc] init];

    descriptor.pixelFormat = MTLPixelFormatR8Unorm;
    descriptor.width = fontWidth;
    descriptor.height = fontHeight;
    descriptor.mipmapLevelCount = 1;
    descriptor.textureType = MTLTextureType2DArray;
    descriptor.arrayLength = 2;
    descriptor.usage = MTLTextureUsageShaderRead;
    self.texture = [self.device newTextureWithDescriptor:descriptor];

    MTLOrigin textureOrigin = MTLOriginMake(0, 0, 0);
    MTLSize textureSize = MTLSizeMake(fontWidth, fontHeight, 1);
    MTLRegion region = {textureOrigin, textureSize};
    size_t row_bytes = (size_t)fontWidth;
    size_t image_bytes = (size_t)(fontWidth * fontHeight);

    [self.texture replaceRegion:region mipmapLevel:0 slice:CPU_FONT_INDEX_REGULAR withBytes:fontRegular.data.bytes bytesPerRow:row_bytes bytesPerImage:image_bytes];
    [self.texture replaceRegion:region mipmapLevel:0 slice:CPU_FONT_INDEX_BOLD withBytes:fontBold.data.bytes bytesPerRow:row_bytes bytesPerImage:image_bytes];

    static const uint32_t samples[] = {'/', '0', '1', '5', '@', 'M', 'W', 'X', '_', 'd', 'g', 'i', 'j', 'q', 'y', '|'};
    float max_advance_x = 0.0f;
    float max_above_baseline = 0.0f;
    float max_below_baseline = 0.0f;

    for (size_t i = 0; i < sizeof(samples) / sizeof(samples[0]); i++) {
        glyph_attributes_t glyph_attributes;

        memset(&glyph_attributes, 0, sizeof(glyph_attributes));

        if (![fontRegular find:samples[i] glyph:NULL attributes:&glyph_attributes]) continue;

        max_advance_x = MAX(max_advance_x, glyph_attributes.advance_x);
        max_above_baseline = MAX(max_above_baseline, glyph_attributes.bearing_y + glyph_attributes.height);
        max_below_baseline = MAX(max_below_baseline, -glyph_attributes.bearing_y);
    }

    float pad_x = 0.0f;
    float pad_top = 4.0f;
    float pad_bottom = 2.0f;

    self.cellWidth = MAX(1.0, max_advance_x + pad_x);
    self.cellHeight = MAX(1.0, max_below_baseline + pad_bottom + max_above_baseline + pad_top);
    self.textBaseline = MAX(0.0, max_below_baseline + pad_bottom);
}

- (void)update:(cpu_glyph_instance_t *)instance row:(NSUInteger)row column:(NSUInteger)column codepoint:(uint32_t)codepoint attributes:(const ansi_sgr_t *)attributes {
    if (!instance) return;

    if (codepoint == 0) codepoint = ' ';

    uint32_t font = attributes && (attributes->flags & ANSI_SGR_FLAG_BOLD) ? CPU_FONT_INDEX_BOLD : CPU_FONT_INDEX_REGULAR;
    FontTexture *typeset = self.typesets[@(font)];

    if (!typeset) return;

    glyph_attributes_t glyph_attributes;

    memset(&glyph_attributes, 0, sizeof(glyph_attributes));

    uint32_t glyph = 0;
    BOOL hasGlyph = [typeset find:codepoint glyph:&glyph attributes:&glyph_attributes];

    if (!hasGlyph) [typeset find:' ' glyph:&glyph attributes:&glyph_attributes];

    uint32_t fg_packed = attributes ? attributes->fg_color : ANSI_COLOR_RESET;
    uint32_t bg_packed = attributes ? attributes->bg_color : ANSI_COLOR_RESET;
    simd_float4 fg_color = cpu_rgba_color(fg_packed, false);
    simd_float4 bg_color = cpu_rgba_color(bg_packed, true);

    if (attributes && (attributes->flags & ANSI_SGR_FLAG_INVERSE)) {
        simd_float4 reverse = fg_color;

        fg_color = bg_color;
        fg_color.w = 1.0f;
        bg_color = reverse;
    }

    instance->glyph_id = glyph;
    instance->font_index = font;
    instance->position = simd_make_float2((float)column, (float)(self.rows - 1 - row));
    instance->uv = simd_make_float4(glyph_attributes.uv[0], glyph_attributes.uv[1], glyph_attributes.uv[2], glyph_attributes.uv[3]);
    instance->size = simd_make_float2(glyph_attributes.width, glyph_attributes.height);

    float x_offset = 0.0f;

    if (glyph_attributes.advance_x > 0.0f) x_offset = MAX(0.0f, ((float)self.cellWidth - glyph_attributes.advance_x) * 0.5f);

    instance->bearing = simd_make_float2(glyph_attributes.bearing_x + x_offset, glyph_attributes.bearing_y + (float)self.textBaseline);
    instance->fg_color = fg_color;
    instance->bg_color = bg_color;
}

- (void)span:(const render_op_span_t *)span {
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

- (void)scroll:(const render_op_scroll_t *)scroll {
    cpu_glyph_instance_t *instances = (cpu_glyph_instance_t *)self.buffer.contents;

    if (!instances) return;

    NSInteger top = MAX(0, scroll->top);
    NSInteger bottom = MIN((NSInteger)self.rows - 1, scroll->bottom);

    if (top > bottom || scroll->delta == 0) return;

    NSInteger height = bottom - top + 1;
    NSInteger shift = MIN(height, labs(scroll->delta));
    size_t size = self.columns * sizeof(cpu_glyph_instance_t);

    if (scroll->delta > 0) {
        for (NSInteger row = bottom; row >= top + shift; row--) memmove(instances + (row * self.columns), instances + ((row - shift) * self.columns), size);

        for (NSInteger row = top + shift; row <= bottom; row++) {
            for (NSUInteger column = 0; column < self.columns; column++) {
                NSUInteger index = (NSUInteger)row * self.columns + column;

                instances[index].position = simd_make_float2((float)column, (float)(self.rows - 1 - (NSUInteger)row));
            }
        }

        for (NSInteger row = top; row < top + shift; row++) {
            for (NSUInteger column = 0; column < self.columns; column++) {
                NSUInteger index = (NSUInteger)row * self.columns + column;

                [self update:&instances[index] row:row column:column codepoint:' ' attributes:NULL];
            }
        }
    } else {
        for (NSInteger row = top; row <= bottom - shift; row++) memmove(instances + (row * self.columns), instances + ((row + shift) * self.columns), size);

        for (NSInteger row = top; row <= bottom - shift; row++) {
            for (NSUInteger column = 0; column < self.columns; column++) {
                NSUInteger index = (NSUInteger)row * self.columns + column;

                instances[index].position = simd_make_float2((float)column, (float)(self.rows - 1 - (NSUInteger)row));
            }
        }

        for (NSInteger row = bottom - shift + 1; row <= bottom; row++) {
            for (NSUInteger column = 0; column < self.columns; column++) {
                NSUInteger index = (NSUInteger)row * self.columns + column;

                [self update:&instances[index] row:row column:column codepoint:' ' attributes:NULL];
            }
        }
    }
}

@end
