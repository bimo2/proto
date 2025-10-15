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

        strongSelf.terminal.readBlock = ^(ansi_t *ansi) {
            switch (ansi->event) {
                case ANSI_EVENT_TEXT: {
                    NSData *data = [NSData dataWithBytes:ansi->text.bytes length:ansi->text.length];
                    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

                    NSLog(@"text: \"%@\"", string ?: data);

                    break;
                }
                case ANSI_EVENT_CSI: {
                    NSMutableString *parameters = [NSMutableString new];

                    for (size_t i = 0; i < ansi->csi.parameters_count; i++) {
                        if (i > 0) [parameters appendString:@";"];

                        [parameters appendFormat:@"%d", ansi->csi.parameters[i]];
                    }

                    NSLog(@"csi: %d %@ %.*s %c", ansi->csi.dec_private, parameters, (int)ansi->csi.intermediates_count, ansi->csi.intermediates, ansi->csi.final_byte);

                    break;
                }
                case ANSI_EVENT_OSC: {
                    if (ansi->osc.payload == NULL) {
                        NSLog(@"osc: %d", ansi->osc.code);

                        break;
                    }

                    NSString *payload = [NSString stringWithUTF8String:ansi->osc.payload];

                    NSLog(@"osc: %d %@", ansi->osc.code, payload);

                    break;
                }
                case ANSI_EVENT_ESC:
                    NSLog(@"esc: %d", ansi->esc.event);

                    break;
                case ANSI_EVENT_BELL:
                    NSLog(@"bell");

                    break;
                case ANSI_EVENT_UNKNOWN: {
                    NSData *data = [NSData dataWithBytes:ansi->unknown.bytes length:ansi->unknown.length];

                    NSLog(@"unknown: %@", data);

                    break;
                }
            }
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
