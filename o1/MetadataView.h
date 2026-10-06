//
//  MetadataView.h
//  o1
//
//  Created by grok-4.7-high-fast on 2026-10-04.
//

#import <Cocoa/Cocoa.h>

#include "screen.h"

@interface MetadataView : NSView

@property (nonatomic, assign, setter=setPID:) NSInteger pid;
@property (nonatomic, assign) screen_t *screen;

@end
