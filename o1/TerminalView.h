//
//  TerminalView.h
//  o1
//
//  Created by gpt-5.1-high on 2025-11-26.
//

#import "Terminal.h"

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>

#include "render.h"
#include "screen.h"

@interface TerminalView : MTKView <MTKViewDelegate>

@property (nonatomic, weak) Terminal *terminal;
@property (nonatomic, assign, getter=isTrackingAreasEnabled) BOOL trackingAreasEnabled;

- (void)render:(const render_t *)ops count:(size_t)count;

- (void)cursor:(screen_t *)screen;

@end
