//
//  Terminal+UserDefaults.h
//  o1
//
//  Created by grok-code-fast-1 on 2025-10-27.
//

#import "Terminal.h"

@interface Terminal (UserDefaults)

@property (class, assign) NSUInteger width;
@property (class, assign) NSUInteger height;
@property (class, assign) NSUInteger rows;
@property (class, assign) NSUInteger columns;
@property (class, assign) NSUInteger codepoint;

@end
