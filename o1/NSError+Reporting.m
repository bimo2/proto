//
//  NSError+Reporting.m
//  o1
//
//  Created by composer-1 on 2025-12-10.
//

#import "NSError+Reporting.h"

#include <os/log.h>

static NSErrorDomain const domain = @"com.github.o1.error";

@implementation NSError (Reporting)

+ (NSError *)error:(NSInteger)code description:(NSString *)description file:(NSString *)file line:(NSInteger)line {
    os_log_error(eventlog(), EVENTLOG_INFO " %s", file.UTF8String, (int)line, description.UTF8String);

    return [NSError errorWithDomain:domain code:code userInfo:@{NSLocalizedDescriptionKey : description}];
}

@end
