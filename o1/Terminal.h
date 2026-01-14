//
//  Terminal.h
//  o1
//
//  Created by gpt-5-high on 2025-10-10.
//

#import <AppKit/AppKit.h>

#include "ansi.h"
#include "render.h"
#include "screen.h"

@interface Terminal : NSObject

@property (nonatomic, copy) NSString *file;
@property (nonatomic, copy) NSArray<NSString *> *flags;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *environment;
@property (readonly, getter=isRunning) BOOL running;
@property (nonatomic, copy) void (^renderBlock)(const render_t *, size_t);
@property (nonatomic, copy) void (^updateBlock)(screen_t *);
@property (nonatomic, copy) void (^titleBlock)(const char *);
@property (nonatomic, copy) void (^bellBlock)(void);
@property (nonatomic, copy) void (^mouseBlock)(bool);
@property (nonatomic, copy) void (^exitBlock)(int);

- (BOOL)start:(NSError **)error;

- (void)stop;

- (void)write:(NSData *)data;

- (void)paste:(NSData *)data;

- (void)scroll:(NSInteger)value;

- (void)focus:(BOOL)value;

- (void)keyboard:(ansi_keyboard_t)value flags:(NSEventModifierFlags)flags;

- (void)mouse:(ansi_mouse_t)value event:(ansi_mouse_event_t)event flags:(NSEventModifierFlags)flags row:(NSUInteger)row column:(NSUInteger)column;

- (void)layout:(NSSize)size rows:(NSUInteger)rows columns:(NSUInteger)columns;

@end
