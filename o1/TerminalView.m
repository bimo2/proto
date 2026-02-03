//
//  TerminalView.m
//  o1
//
//  Created by gpt-5.1-high on 2025-11-26.
//

#import "TerminalView.h"

#import "FontTexture.h"

#import <QuartzCore/QuartzCore.h>

#include "ansi.h"
#include "render.h"
#include "shaders_cpu.h"
#include "unicode.h"

#include <dispatch/dispatch.h>
#include <math.h>
#include <string.h>

typedef struct {
    int32_t row;
    int32_t column;
} location_t;

static location_t location(int32_t row, int32_t column);

@interface TerminalView () {
    screen_t *screen;
    cpu_cursor_uniforms_t next_cursor;
    dispatch_source_t blink_timer;
    dispatch_source_t blink_pause_timer;
    location_t selection_start;
    location_t selection_end;
    dispatch_source_t selection_timer;
}

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
@property (nonatomic, strong) NSTrackingArea *trackingArea;
@property (nonatomic, assign, getter=shouldDrawCursor) BOOL drawCursor;
@property (nonatomic, assign, getter=isCursorBlinkEnabled) BOOL cursorBlinkEnabled;
@property (nonatomic, assign) NSUInteger cursorBlinkPhase;
@property (nonatomic, assign, getter=isCursorBlinkPaused) BOOL cursorBlinkPaused;
@property (nonatomic, assign) NSPoint anchor;
@property (nonatomic, assign, getter=isSelectPending) BOOL selectPending;
@property (nonatomic, assign, getter=shouldSelect) BOOL select;
@property (nonatomic, assign, getter=isSelecting) BOOL selecting;
@property (readonly, getter=hasSelection) BOOL selection;
@property (nonatomic, strong) CAShapeLayer *selectionLayer;
@property (nonatomic, assign) NSPoint selectionAutoScrollPoint;
@property (nonatomic, assign) NSInteger selectionAutoScrollDirection;

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
        selection_start = location(-1, -1);
        selection_end = location(-1, -1);
        _interactive = YES;
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
        _cursorBlinkPhase = 1;
        next_cursor.padding = 0.02f;
        next_cursor.style = CPU_CURSOR_STYLE_BLOCK;

        CAShapeLayer *sublayer = [CAShapeLayer layer];

        sublayer.fillColor = [NSColor selectedTextBackgroundColor].CGColor;
        sublayer.opacity = 0.28;
        sublayer.frame = self.bounds;
        [self.layer addSublayer:sublayer];
        _selectionLayer = sublayer;
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopCursorBlinkTimer];
    [self stopCursorBlinkPauseTimer];
    [self stopSelectionTimer];
}

#pragma mark - NSView

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (self.window) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateWindow:) name:NSWindowDidBecomeKeyNotification object:self.window];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateWindow:) name:NSWindowDidResignKeyNotification object:self.window];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateWindow:) name:NSApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateWindow:) name:NSApplicationDidResignActiveNotification object:nil];
    [self updateNextCursor];
    [self setNeedsDisplay:YES];
}

- (void)layout {
    [super layout];
    [self updateSelectionLayer];
    [self.window invalidateCursorRectsForView:self];
}

- (void)viewDidEndLiveResize {
    [self.terminal layout:self.drawableSize rows:self.rows columns:self.columns update:YES];
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];

    if (self.trackingArea) {
        [self removeTrackingArea:self.trackingArea];
        self.trackingArea = nil;
        self.window.acceptsMouseMovedEvents = NO;
    }

    if (self.isTrackingAreasEnabled) {
        self.window.acceptsMouseMovedEvents = YES;

        NSTrackingAreaOptions options = NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect;

        self.trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:options owner:self userInfo:nil];
        [self addTrackingArea:self.trackingArea];
    }
}

- (void)resetCursorRects {
    [super resetCursorRects];
    [self addCursorRect:[self cursorRect] cursor:[NSCursor IBeamCursor]];
}

#pragma mark - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    CGFloat scale = self.window.screen.backingScaleFactor;
    BOOL updateLayout = NO;

    if (scale > 0 && self.scale != scale) {
        [self setup:scale];
        updateLayout = YES;
    }

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
        [self.terminal layout:NSMakeSize(size.width, size.height) rows:rows columns:columns update:updateLayout];
    }

    [self updateSelectionLayer];
    [self.window invalidateCursorRectsForView:self];
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
        .cell_size = simd_make_float2((float)self.cellWidth, (float)self.cellHeight),
        .monochrome = cpu_default_monochrome,
    };

    [encoder setVertexBuffer:self.buffer offset:0 atIndex:0];
    [encoder setVertexBytes:&uniforms length:sizeof(cpu_grid_uniforms_t) atIndex:1];
    [encoder setVertexBytes:&next_cursor length:sizeof(cpu_cursor_uniforms_t) atIndex:2];
    [encoder setFragmentBytes:&uniforms length:sizeof(cpu_grid_uniforms_t) atIndex:0];
    [encoder setFragmentBytes:&next_cursor length:sizeof(cpu_cursor_uniforms_t) atIndex:1];
    [encoder setFragmentTexture:self.texture atIndex:0];
    [encoder setFragmentSamplerState:self.sampler atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:CPU_TERMINAL_VERTEX_COUNT instanceCount:self.instanceCount];
    [encoder endEncoding];
    [buffer presentDrawable:view.currentDrawable];
    [buffer commit];
}

#pragma mark - NSResponder

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)keyDown:(NSEvent *)event {
    if (self.hasSelection && !(event.modifierFlags & NSEventModifierFlagCommand)) [self clearSelection];

    if (!self.terminal || event.modifierFlags & NSEventModifierFlagCommand) {
        [super keyDown:event];

        return;
    }

    [self skipCursorBlink];

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
    if (self.hasSelection) [self clearSelection];

    self.queuedOffset = 0;
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

- (void)mouseDown:(NSEvent *)event {
    if ([self updateSelection:event]) return;

    [self mouse:event button:ANSI_MOUSE_LEFT action:ANSI_MOUSE_EVENT_DOWN];
}

- (void)mouseUp:(NSEvent *)event {
    if ([self endSelection:event]) return;

    [self mouse:event button:ANSI_MOUSE_LEFT action:ANSI_MOUSE_EVENT_UP];
}

- (void)rightMouseDown:(NSEvent *)event {
    [self mouse:event button:ANSI_MOUSE_RIGHT action:ANSI_MOUSE_EVENT_DOWN];
}

- (void)rightMouseUp:(NSEvent *)event {
    [self mouse:event button:ANSI_MOUSE_RIGHT action:ANSI_MOUSE_EVENT_UP];
}

- (void)otherMouseDown:(NSEvent *)event {
    [self mouse:event button:ANSI_MOUSE_MIDDLE action:ANSI_MOUSE_EVENT_DOWN];
}

- (void)otherMouseUp:(NSEvent *)event {
    [self mouse:event button:ANSI_MOUSE_MIDDLE action:ANSI_MOUSE_EVENT_UP];
}

- (void)mouseDragged:(NSEvent *)event {
    if ([self updateSelection:event]) return;

    [self mouse:event button:ANSI_MOUSE_LEFT action:ANSI_MOUSE_EVENT_DRAG];
}

- (void)rightMouseDragged:(NSEvent *)event {
    [self mouse:event button:ANSI_MOUSE_RIGHT action:ANSI_MOUSE_EVENT_DRAG];
}

- (void)otherMouseDragged:(NSEvent *)event {
    [self mouse:event button:ANSI_MOUSE_MIDDLE action:ANSI_MOUSE_EVENT_DRAG];
}

- (void)mouseMoved:(NSEvent *)event {
    [self mouse:event button:ANSI_MOUSE_RELEASE action:ANSI_MOUSE_EVENT_MOVE];
}

- (void)scrollWheel:(NSEvent *)event {
    CGFloat delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY;
    CGFloat lines = event.hasPreciseScrollingDeltas && self.cellHeight > 0.0 ? (delta / self.cellHeight) : delta;
    CGFloat speed = 3.5;

    self.queuedOffset += lines * speed;

    NSInteger offset = trunc(self.queuedOffset);

    if (offset != 0) {
        self.queuedOffset -= offset;

        if (self.isTrackingAreasEnabled) {
            ansi_mouse_t button = offset > 0 ? ANSI_MOUSE_WHEEL_UP : ANSI_MOUSE_WHEEL_DOWN;

            for (NSInteger i = 0; i < labs(offset); i++) [self mouse:event button:button action:ANSI_MOUSE_EVENT_DOWN];
        } else {
            [self.terminal scroll:offset];
        }
    }

    if (fabs(self.queuedOffset) < 0.1) self.queuedOffset = 0;
}

- (void)paste:(id)sender {
    NSString *string = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];

    if (string.length < 1) return;
    if (self.hasSelection) [self clearSelection];

    [self skipCursorBlink];
    [self.terminal paste:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)copy:(id)sender {
    NSString *text = [self selectedText];

    if (text.length < 1) return;

    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:text forType:NSPasteboardTypeString];
}

- (void)selectAll:(id)sender {
    if (!screen) return;

    selection_start = location(0, 0);
    selection_end = location(screen_total_rows(screen) - 1, (int32_t)self.columns - 1);
    [self updateSelectionLayer];
}

#pragma mark - Public

- (void)setInteractive:(BOOL)interactive {
    _interactive = interactive;
    [self updateNextCursor];
    [self setNeedsDisplay:YES];
}

- (void)setTrackingAreasEnabled:(BOOL)trackingAreasEnabled {
    _trackingAreasEnabled = trackingAreasEnabled;
    [self updateTrackingAreas];

    if (self.hasSelection && trackingAreasEnabled) [self clearSelection];

    if (trackingAreasEnabled) {
        self.selectionAutoScrollDirection = 0;
        [self stopSelectionTimer];
    }
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

- (void)screen:(const screen_t *)screen {
    if (!screen) return;

    self->screen = (screen_t *)screen;
    [self updateNextCursor];
    [self updateSelectionLayer];
    [self setNeedsDisplay:YES];
}

#pragma mark - Private

- (BOOL)hasSelection {
    return selection_start.row > -1 && selection_start.column > -1 && selection_end.row > -1 && selection_end.column > -1;
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

        memset(&glyph_attributes, 0, sizeof(glyph_attributes_t));

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

- (void)updateWindow:(NSNotification *)notification {
    [self updateNextCursor];
    [self setNeedsDisplay:YES];
}

- (void)updateInstance:(cpu_glyph_instance_t *)instance row:(NSUInteger)row column:(NSUInteger)column codepoint:(uint32_t)codepoint attributes:(const ansi_sgr_t *)attributes {
    if (!instance) return;

    if (codepoint == 0) codepoint = ' ';

    uint32_t font = attributes && (attributes->flags & ANSI_SGR_FLAG_BOLD) ? CPU_FONT_INDEX_BOLD : CPU_FONT_INDEX_REGULAR;
    FontTexture *typeset = self.typesets[@(font)];

    if (!typeset) return;

    glyph_attributes_t glyph_attributes;

    memset(&glyph_attributes, 0, sizeof(glyph_attributes_t));

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

        [self updateInstance:&instances[row * self.columns + column] row:row column:column codepoint:span->cells[i].codepoint attributes:&span->cells[i].attributes];
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

                [self updateInstance:&instances[index] row:row column:column codepoint:' ' attributes:NULL];
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

                [self updateInstance:&instances[index] row:row column:column codepoint:' ' attributes:NULL];
            }
        }
    }
}

- (void)mouse:(NSEvent *)event button:(ansi_mouse_t)button action:(ansi_mouse_event_t)action {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    NSRect rect = [self cursorRect];

    if (!NSPointInRect(point, rect) || !isfinite(point.x) || !isfinite(point.y)) return;

    NSInteger visibleRows = (NSInteger)self.rows - (NSInteger)screen_default_offset;

    if (visibleRows < 1) return;

    CGFloat x = MAX(0.0, MIN(point.x - rect.origin.x * self.scale, rect.size.width * self.scale - 1.0));
    CGFloat y = MAX(0.0, MIN(point.y - rect.origin.y * self.scale, rect.size.height * self.scale - 1.0));
    NSUInteger row = (NSUInteger)floor(((rect.size.height * self.scale) - 1.0 - y) / self.cellHeight) + 1;
    NSUInteger column = (NSUInteger)floor(x / self.cellWidth) + 1;

    [self.terminal mouse:button event:action flags:event.modifierFlags row:MAX(1, MIN((NSUInteger)visibleRows, row)) column:MAX(1, MIN(self.columns, column))];
}

- (void)startCursorBlinkTimer {
    if (blink_timer) return;

    blink_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());

    uint64_t interval = (uint64_t)(0.5 * NSEC_PER_SEC);

    dispatch_source_set_timer(blink_timer, dispatch_time(DISPATCH_TIME_NOW, interval), interval, (uint64_t)(0.05 * NSEC_PER_SEC));

    __weak typeof(self) weakSelf = self;

    dispatch_source_set_event_handler(blink_timer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf || strongSelf.isCursorBlinkPaused) return;

        strongSelf.cursorBlinkPhase = strongSelf.cursorBlinkPhase > 0 ? 0 : 1;
        strongSelf->next_cursor.visible = (uint32_t)(strongSelf.shouldDrawCursor && strongSelf.cursorBlinkPhase);
        [strongSelf setNeedsDisplay:YES];
    });

    dispatch_resume(blink_timer);
}

- (void)stopCursorBlinkTimer {
    if (!blink_timer) return;

    dispatch_source_cancel(blink_timer);
    blink_timer = NULL;
    self.cursorBlinkPhase = 1;
}

- (void)restartCursorBlinkPauseTimer {
    [self stopCursorBlinkPauseTimer];

    blink_pause_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());

    dispatch_source_set_timer(blink_pause_timer, DISPATCH_TIME_NOW, DISPATCH_TIME_FOREVER, (uint64_t)(0.5 * NSEC_PER_SEC));

    __weak typeof(self) weakSelf = self;

    dispatch_source_set_event_handler(blink_pause_timer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        [strongSelf stopCursorBlinkPauseTimer];
        strongSelf.cursorBlinkPaused = NO;
        strongSelf.cursorBlinkPhase = 1;

        if (strongSelf.isCursorBlinkEnabled) [strongSelf startCursorBlinkTimer];

        [strongSelf setNeedsDisplay:YES];
    });

    dispatch_resume(blink_pause_timer);
}

- (void)stopCursorBlinkPauseTimer {
    if (!blink_pause_timer) return;

    dispatch_source_cancel(blink_pause_timer);
    blink_pause_timer = NULL;
}

- (void)skipCursorBlink {
    if (!self.isCursorBlinkEnabled) return;

    self.cursorBlinkPaused = YES;
    self.cursorBlinkPhase = 1;
    [self stopCursorBlinkTimer];
    next_cursor.visible = (uint32_t)self.shouldDrawCursor;
    [self restartCursorBlinkPauseTimer];
}

- (void)updateNextCursor {
    if (!screen || !self.isInteractive) {
        next_cursor.cell = simd_make_uint2(0, 0);
        next_cursor.visible = 0;
        next_cursor.style = CPU_CURSOR_STYLE_BLOCK;
        self.drawCursor = NO;
        [self stopCursorBlinkTimer];
        [self stopCursorBlinkPauseTimer];

        return;
    }

    screen_cursor_t *cursor = screen_cursor(screen);
    BOOL drawCursor = cursor->visible;
    int32_t row = cursor->row + screen_viewport_offset(screen);

    if (row < 0 || row >= (int32_t)self.rows) drawCursor = NO;
    if (cursor->column < 0 || cursor->column >= (int32_t)self.columns) drawCursor = NO;

    if (drawCursor) {
        next_cursor.cell = simd_make_uint2((uint32_t)cursor->column, (uint32_t)((int32_t)self.rows - 1 - row));
    } else {
        next_cursor.cell = simd_make_uint2(0, 0);
    }

    self.drawCursor = drawCursor;

    BOOL active = NSApp.isActive && self.window && self.window.isKeyWindow;

    next_cursor.style = active ? CPU_CURSOR_STYLE_BLOCK : CPU_CURSOR_STYLE_BLOCK_OUTLINE;

    if (!active) {
        next_cursor.visible = (uint32_t)drawCursor;
        self.cursorBlinkPaused = NO;
        self.cursorBlinkPhase = 1;
        [self stopCursorBlinkTimer];
        [self stopCursorBlinkPauseTimer];
        self.cursorBlinkEnabled = cursor->blink;

        return;
    }

    if (cursor->blink && self.isCursorBlinkPaused) {
        next_cursor.visible = (uint32_t)drawCursor;
    } else {
        next_cursor.visible = (uint32_t)(drawCursor && (!cursor->blink || self.cursorBlinkPhase > 0));
    }

    if (self.isCursorBlinkEnabled != cursor->blink) {
        self.cursorBlinkEnabled = cursor->blink;

        if (!cursor->blink) {
            self.cursorBlinkPaused = NO;
            [self stopCursorBlinkTimer];
            [self stopCursorBlinkPauseTimer];
        }
    }

    if (self.isCursorBlinkEnabled && !self.isCursorBlinkPaused) [self startCursorBlinkTimer];
}

- (NSRect)cursorRect {
    CGFloat cellWidth = self.cellWidth / self.scale;
    CGFloat cellHeight = self.cellHeight / self.scale;

    if (cellWidth <= 0.0 || cellHeight <= 0.0) return NSZeroRect;

    CGFloat width = (CGFloat)self.columns * cellWidth;
    CGFloat height = MAX(0, (CGFloat)self.rows - (CGFloat)screen_default_offset) * cellHeight;
    NSRect rect = NSMakeRect(0.0, 0.0, width, height);

    if (rect.size.width > self.bounds.size.width) rect.size.width = self.bounds.size.width;
    if (rect.size.height > self.bounds.size.height) rect.size.height = self.bounds.size.height;

    if (rect.origin.x < self.bounds.origin.x) {
        rect.size.width -= self.bounds.origin.x - rect.origin.x;
        rect.origin.x = self.bounds.origin.x;
    }

    if (rect.origin.y < self.bounds.origin.y) {
        rect.size.height -= self.bounds.origin.y - rect.origin.y;
        rect.origin.y = self.bounds.origin.y;
    }

    return rect;
}

- (NSPoint)ibeamPoint:(NSPoint)point {
    NSCursor *cursor = [NSCursor IBeamCursor];

    if (!cursor.image) return point;

    NSPoint delta = NSMakePoint(cursor.image.size.width * 0.5 - cursor.hotSpot.x, cursor.image.size.height * 0.5 - cursor.hotSpot.y);

    point.x += delta.x;
    point.y += delta.y;

    return point;
}

- (void)startSelectionTimer {
    if (selection_timer) return;

    selection_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());

    uint64_t interval = (uint64_t)(1.0 / 60.0 * NSEC_PER_SEC);

    dispatch_source_set_timer(selection_timer, dispatch_time(DISPATCH_TIME_NOW, interval), interval, (uint64_t)(0.01 * NSEC_PER_SEC));

    __weak typeof(self) weakSelf = self;

    dispatch_source_set_event_handler(selection_timer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        if (!strongSelf->screen || !strongSelf.isSelecting || strongSelf.selectionAutoScrollDirection == 0) {
            [strongSelf stopSelectionTimer];

            return;
        }

        [strongSelf.terminal scroll:strongSelf.selectionAutoScrollDirection];

        location_t end = strongSelf->selection_end;
        int32_t total = screen_total_rows(strongSelf->screen);

        end.row -= (int32_t)strongSelf.selectionAutoScrollDirection;

        if (end.row < 0) end.row = 0;
        if (total > 0 && end.row >= total) end.row = total - 1;

        NSRect rect = [strongSelf cursorRect];
        NSPoint point = [strongSelf ibeamPoint:[strongSelf convertPoint:strongSelf.selectionAutoScrollPoint fromView:nil]];
        CGFloat localX = MAX(0.0, point.x - rect.origin.x);

        if (localX > rect.size.width - 0.0001) localX = MAX(0.0, rect.size.width - 0.0001);

        CGFloat cellWidth = strongSelf.cellWidth / strongSelf.scale;
        NSInteger column = cellWidth > 0.0 ? (NSInteger)floor(localX / cellWidth) : 0;

        if (column < 0) column = 0;
        if (column >= (NSInteger)strongSelf.columns) column = (NSInteger)strongSelf.columns - 1;

        if (end.row > -1 && column > -1) {
            const screen_cell_t *cells = screen_absolute_row(strongSelf->screen, (int32_t)end.row, NULL, NULL);

            if (cells && column > 0 && cells[column].width == 0) column--;
        }

        end.column = (int32_t)column;
        strongSelf->selection_end = end;
        [strongSelf updateSelectionLayer];
    });

    dispatch_resume(selection_timer);
}

- (void)stopSelectionTimer {
    if (!selection_timer) return;

    dispatch_source_cancel(selection_timer);
    selection_timer = NULL;
}

- (BOOL)select:(NSEvent *)event cell:(location_t *)cell direction:(NSInteger *)direction {
    if (!screen || !cell || !direction) return NO;

    NSRect rect = [self cursorRect];
    NSPoint point = [self ibeamPoint:[self convertPoint:event.locationInWindow fromView:nil]];
    BOOL allowOutside = event.type == NSEventTypeLeftMouseDragged;

    if (!allowOutside && !NSPointInRect(point, rect)) return NO;
    if (!isfinite(point.x) || !isfinite(point.y)) return NO;

    *direction = 0;

    if (allowOutside) {
        if (point.y < NSMinY(rect)) {
            *direction = -1;
        } else if (point.y > NSMaxY(rect)) {
            *direction = 1;
        }
    }

    if (point.x < NSMinX(rect)) point.x = NSMinX(rect);
    if (point.y < NSMinY(rect)) point.y = NSMinY(rect);
    if (point.x > NSMaxX(rect) - 0.0001) point.x = NSMaxX(rect) - 0.0001;
    if (point.y > NSMaxY(rect) - 0.0001) point.y = NSMaxY(rect) - 0.0001;

    CGFloat cellWidth = self.cellWidth / self.scale;
    CGFloat cellHeight = self.cellHeight / self.scale;

    if (cellWidth <= 0.0 || cellHeight <= 0.0) return NO;

    CGFloat localX = point.x - rect.origin.x;
    CGFloat localY = point.y - rect.origin.y;
    NSInteger row = cellHeight > 0.0 ? (NSInteger)floor((rect.size.height - 0.0001 - localY) / cellHeight) : 0;
    NSInteger column = cellWidth > 0.0 ? (NSInteger)floor(localX / cellWidth) : 0;
    NSInteger visibleRows = (NSInteger)self.rows - (NSInteger)screen_default_offset;

    if (visibleRows < 1) return NO;
    if (row < 0) row = 0;
    if (row >= visibleRows) row = visibleRows - 1;
    if (column < 0) column = 0;
    if (column >= self.columns) column = (NSInteger)self.columns - 1;

    row += (NSInteger)screen_default_offset;

    int32_t index = screen_viewport_index(screen) + (int32_t)row;
    const screen_cell_t *cells = screen_absolute_row(screen, index, NULL, NULL);

    if (cells && column > 0 && cells[column].width == 0) column--;

    *cell = location(index, (int32_t)column);

    return YES;
}

- (void)selection:(location_t *)start end:(location_t *)end {
    if (!self.hasSelection) {
        if (start) *start = location(-1, -1);
        if (end) *end = location(-1, -1);

        return;
    }

    BOOL inverse = (self->selection_start.row > self->selection_end.row) || (self->selection_start.row == self->selection_end.row && self->selection_start.column > self->selection_end.column);

    if (inverse) {
        if (start) *start = self->selection_end;
        if (end) *end = self->selection_start;
    } else {
        if (start) *start = self->selection_start;
        if (end) *end = self->selection_end;
    }
}

- (NSUInteger)classify:(const screen_cell_t *)cells column:(NSUInteger)column {
    if (!cells || column < 0) return UNICODE_CLASS_OTHER;

    NSInteger index = column;

    while (index > 0 && cells[index].width == 0) index--;

    return unicode_class(cells[index].codepoint);
}

- (BOOL)updateSelection:(NSEvent *)event {
    if (self.isTrackingAreasEnabled) return NO;

    location_t cell;
    NSInteger direction;

    if (![self select:event cell:&cell direction:&direction]) return NO;

    self.selectionAutoScrollPoint = event.locationInWindow;
    self.selectionAutoScrollDirection = direction;

    if (self.selectionAutoScrollDirection != 0) {
        [self startSelectionTimer];
    } else {
        [self stopSelectionTimer];
    }

    if (event.type != NSEventTypeLeftMouseDragged) {
        if (event.clickCount >= 3) {
            int32_t total = screen_total_rows(screen);
            int32_t start = MIN(total - 1, MAX(0, cell.row));
            int32_t end = MIN(total - 1, MAX(0, cell.row));

            while (start > 0) {
                bool soft_wrap = false;

                if (!screen_absolute_row(screen, start - 1, &soft_wrap, NULL)) break;
                if (!soft_wrap) break;

                start--;
            }

            while (end < total - 1) {
                bool soft_wrap = false;

                if (!screen_absolute_row(screen, end, &soft_wrap, NULL)) break;
                if (!soft_wrap) break;

                end++;
            }

            self.selectPending = NO;
            self.select = YES;
            self.selecting = YES;
            self->selection_start = location(start, 0);
            self->selection_end = location(end, (int32_t)self.columns - 1);
            [self updateSelectionLayer];

            return YES;
        }

        if (event.clickCount == 2) {
            const screen_cell_t *cells = screen_absolute_row(screen, cell.row, NULL, NULL);

            if (!cells) return YES;

            NSInteger anchor = MAX(0, cell.column);

            if (anchor >= self.columns) anchor = (NSInteger)self.columns - 1;

            NSUInteger basis = [self classify:cells column:anchor];
            NSInteger left = anchor;
            NSInteger right = anchor;

            while (left > 0) {
                if ([self classify:cells column:left - 1] != basis) break;

                left--;
            }

            while (right + 1 < self.columns) {
                if ([self classify:cells column:right + 1] != basis) break;

                right++;
            }

            self.selectPending = NO;
            self.select = YES;
            self.selecting = YES;
            self->selection_start = location(cell.row, (int32_t)left);
            self->selection_end = location(cell.row, (int32_t)right);
            [self updateSelectionLayer];

            return YES;
        }

        self.anchor = event.locationInWindow;
        self.selectPending = YES;
        self.select = NO;

        return YES;
    }

    if (self.isSelectPending) {
        NSPoint current = event.locationInWindow;
        CGFloat dx = current.x - self.anchor.x;
        CGFloat dy = current.y - self.anchor.y;
        CGFloat distance = sqrt(dx * dx + dy * dy);
        CGFloat threshold = 3.0;

        if (distance >= threshold) {
            self.selectPending = NO;
            self.select = YES;
            self.selecting = YES;

            if (self.hasSelection && (event.modifierFlags & NSEventModifierFlagShift)) {
                self->selection_end = cell;
            } else {
                self->selection_start = cell;
                self->selection_end = cell;
            }

            [self updateSelectionLayer];

            return YES;
        }

        return YES;
    }

    if (self.isSelecting) {
        self.select = YES;
        self->selection_end = cell;
        [self updateSelectionLayer];

        return YES;
    }

    return NO;
}

- (BOOL)endSelection:(NSEvent *)event {
    if (self.isTrackingAreasEnabled) return NO;

    if (self.isSelectPending) {
        self.selectPending = NO;
        [self clearSelection];

        return YES;
    }

    if (!self.isSelecting) return NO;

    self.selecting = NO;
    self.selectionAutoScrollDirection = 0;
    [self stopSelectionTimer];

    if (!self.shouldSelect && !(event.modifierFlags & NSEventModifierFlagShift)) {
        [self clearSelection];
    } else {
        [self updateSelectionLayer];
    }

    return YES;
}

- (void)clearSelection {
    self->selection_start = location(-1, -1);
    self->selection_end = location(-1, -1);
    self.selectPending = NO;
    self.select = NO;
    self.selecting = NO;
    self.selectionAutoScrollDirection = 0;
    [self stopSelectionTimer];
    [self updateSelectionLayer];
}

- (void)updateSelectionLayer {
    self.selectionLayer.frame = self.bounds;

    if (!screen || !self.hasSelection) {
        self.selectionLayer.path = nil;

        return;
    }

    location_t start;
    location_t end;

    [self selection:&start end:&end];

    CGFloat cellWidth = self.cellWidth / self.scale;
    CGFloat cellHeight = self.cellHeight / self.scale;

    if (cellWidth <= 0.0 || cellHeight <= 0.0) {
        self.selectionLayer.path = nil;

        return;
    }

    CGMutablePathRef path = CGPathCreateMutable();
    int32_t index = screen_viewport_index(self->screen);

    for (NSInteger row = MAX(index, start.row); row <= MIN(index + (int32_t)self.rows - 1, end.row); row++) {
        NSInteger viewportRow = row - index;
        NSInteger startColumn = MAX(0, MIN((NSInteger)self.columns - 1, row == start.row ? start.column : 0));
        NSInteger endColumn = MAX(0, MIN((NSInteger)self.columns - 1, row == end.row ? end.column : (NSInteger)self.columns - 1));

        if (endColumn < startColumn) continue;

        CGFloat x = (CGFloat)startColumn * cellWidth;
        CGFloat y = (CGFloat)((NSInteger)self.rows - 1 - viewportRow) * cellHeight;
        CGFloat width = (CGFloat)(endColumn - startColumn + 1) * cellWidth;
        CGRect rect = CGRectMake(x, y, width, cellHeight);

        CGPathAddRect(path, NULL, rect);
    }

    self.selectionLayer.path = path;
    CGPathRelease(path);
}

- (NSString *)selectedText {
    if (!screen || !self.hasSelection) return @"";

    location_t start;
    location_t end;

    [self selection:&start end:&end];

    NSMutableString *text = [NSMutableString string];
    int32_t total = screen_total_rows(screen);
    NSInteger first = MAX(0, start.row);
    NSInteger last = MIN(total - 1, end.row);

    for (NSInteger row = first; row <= last; row++) {
        NSInteger startColumn = MAX(0, MIN((NSInteger)self.columns - 1, row == start.row ? start.column : 0));
        NSInteger endColumn = MAX(0, MIN((NSInteger)self.columns - 1, row == end.row ? end.column : (NSInteger)self.columns - 1));

        if (endColumn < startColumn) continue;

        bool soft_wrap = false;
        const screen_cell_t *cells = screen_absolute_row(screen, (int32_t)row, &soft_wrap, NULL);

        if (!cells) continue;

        NSMutableString *line = [NSMutableString stringWithCapacity:(NSUInteger)(endColumn - startColumn + 1)];

        for (NSInteger column = startColumn; column <= endColumn; column++) {
            const screen_cell_t *cell = &cells[column];
            uint32_t codepoint = cell->codepoint;

            if (cell->width == 0) continue;
            if (codepoint == 0) codepoint = ' ';

            uint16_t units[2] = {0, 0};
            size_t count = unicode_encode_utf16(codepoint, units);

            if (count == 1) {
                [text appendFormat:@"%C", (unichar)units[0]];
            } else if (count == 2) {
                unichar pair[2] = {(unichar)units[0], (unichar)units[1]};

                [text appendString:[NSString stringWithCharacters:pair length:2]];
            } else {
                [text appendString:@"\uFFFD"];
            }
        }

        BOOL wrap = row < last && soft_wrap && (endColumn == (NSInteger)self.columns - 1);
        BOOL newline = row < last && !wrap;
        BOOL trim = (endColumn == (NSInteger)self.columns - 1) && !wrap;

        if (trim && line.length > 0) {
            while (line.length > 0) {
                if (![[NSCharacterSet whitespaceCharacterSet] characterIsMember:[line characterAtIndex:line.length - 1]]) break;

                [line deleteCharactersInRange:NSMakeRange(line.length - 1, 1)];
            }
        }

        [text appendString:line];

        if (newline) [text appendString:@"\n"];
    }

    return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end

static location_t location(int32_t row, int32_t column) {
    return (location_t){
        .row = row,
        .column = column,
    };
}
