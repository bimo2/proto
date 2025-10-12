//
//  ViewController.m
//  o1
//
//  Created by grok-code-fast-1 on 2025-10-10.
//

#import "ViewController.h"
#import "Terminal.h"

@interface ViewController ()

@property (strong) Terminal *terminal;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    __weak typeof(self) weakSelf = self;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        __weak typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.terminal = [[Terminal alloc] init];

        strongSelf.terminal.file = @"/bin/ls";

        strongSelf.terminal.dataBlock = ^(uint8_t *bytes, size_t length) {
            NSData *data = [NSData dataWithBytes:bytes length:length];
            NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

            NSLog(@"data: (%zu bytes)\n%@", length, string);
        };

        strongSelf.terminal.exitBlock = ^(int status) {
            NSLog(@"exit: %d", status);
        };

        NSError *error = nil;

        if (![strongSelf.terminal start:&error]) {
            NSLog(@"error: %@", error);

            return;
        }
    });
}

- (void)dealloc {
    [self.terminal stop];
}

@end
