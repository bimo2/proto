//
//  Terminal.h
//  o1
//
//  Created by gpt-5-high on 2025-10-10.
//

#import <Foundation/Foundation.h>

@interface Terminal : NSObject

@property (nonatomic, copy) NSString *file;
@property (nonatomic, copy) NSArray<NSString *> *flags;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *environment;
@property (assign, readonly, getter=isRunning) BOOL running;
@property (nonatomic, copy) void (^dataBlock)(uint8_t *, size_t);
@property (nonatomic, copy) void (^exitBlock)(int);

- (BOOL)start:(NSError **)error;

- (void)stop;

@end
