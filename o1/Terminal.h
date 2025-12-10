//
//  Terminal.h
//  o1
//
//  Created by gpt-5-high on 2025-10-10.
//

#import <Foundation/Foundation.h>

#include "render.h"
#include "screen.h"

typedef NS_ENUM(NSUInteger, TerminalMouseButton) {
    TerminalMouseButtonNone = 0,
    TerminalMouseButtonLeft,
    TerminalMouseButtonMiddle,
    TerminalMouseButtonRight,
    TerminalMouseButtonWheelUp,
    TerminalMouseButtonWheelDown,
};

typedef NS_ENUM(NSUInteger, TerminalMouseEvent) {
    TerminalMouseEventDown = 0,
    TerminalMouseEventUp,
    TerminalMouseEventDrag,
    TerminalMouseEventMove,
};

typedef NS_OPTIONS(NSUInteger, TerminalMouseModifierFlags) {
    TerminalMouseModifierFlagShift = 1 << 0,
    TerminalMouseModifierFlagOption = 1 << 1,
    TerminalMouseModifierFlagControl = 1 << 2,
};

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

- (void)focus:(BOOL)isFocused;

- (void)layout:(NSSize)size rows:(NSUInteger)rows columns:(NSUInteger)columns;

- (void)mouse:(TerminalMouseButton)button event:(TerminalMouseEvent)event flags:(TerminalMouseModifierFlags)flags row:(NSUInteger)row column:(NSUInteger)column;

@end
