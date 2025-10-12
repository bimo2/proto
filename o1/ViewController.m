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
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        strongSelf.terminal = [[Terminal alloc] init];
        strongSelf.terminal.file = @"/bin/cat";

        strongSelf.terminal.dataBlock = ^(NSData *data) {
            NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

            NSLog(@"data: (%zu bytes)\n%@", string.length, string);
        };

        strongSelf.terminal.exitBlock = ^(int status) {
            NSLog(@"exit: %d", status);
        };

        NSError *error = nil;

        if (![strongSelf.terminal start:&error]) {
            NSLog(@"error: %@", error);

            return;
        }

        usleep(100 * 1000);

        NSString *string = @"hello, world!";
        NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];

        [strongSelf.terminal write:data];
        usleep(500 * 1000);
        [strongSelf.terminal stop];
    });
}

- (void)dealloc {
    [self.terminal stop];
}

@end
