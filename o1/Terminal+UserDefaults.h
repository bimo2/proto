//
//  Terminal+UserDefaults.h
//  o1
//
//  Created by grok-code-fast-1 on 2025-10-27.
//

#import "Terminal.h"

typedef NS_ENUM(NSUInteger, TerminalCodepoint) {
    TerminalCodepointDynamic = 0,
    TerminalCodepointUTF8 = 8,
    TerminalCodepointUTF16 = 16,
    TerminalCodepointUTF32 = 32,
};

@interface Terminal (UserDefaults)

@property (class, assign) NSUInteger width;
@property (class, assign) NSUInteger height;
@property (class, assign) NSUInteger rows;
@property (class, assign) NSUInteger columns;
@property (class, assign) TerminalCodepoint codepoint;

@end
