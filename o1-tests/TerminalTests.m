//
//  TerminalTests.m
//  o1-tests
//
//  Created by grok-4 on 2025-10-12.
//

#import "Terminal.h"

#import <XCTest/XCTest.h>

@interface TerminalTests : XCTestCase

@end

@implementation TerminalTests

- (void)test {
    Terminal *terminal = [[Terminal alloc] init];
    XCTestExpectation *expectation = [self expectationWithDescription:@"did exit"];
    __weak typeof(terminal) weakTerminal = terminal;

    terminal.exitBlock = ^(int status) {
        XCTAssertEqual(status, 1);

        [expectation fulfill];
        XCTAssertFalse(weakTerminal.isRunning);
    };

    [terminal start:nil];
    XCTAssertTrue(terminal.isRunning);

    sleep(1);
    [terminal stop];
    [self waitForExpectations:@[expectation] timeout:1.0];
}

@end
