//
//  NSError+Reporting.h
//  o1
//
//  Created by composer-1 on 2025-12-10.
//

#import <Foundation/Foundation.h>

#include "include.h"

#define NSErrorLog(code, nsstring) \
    [NSError error:code description:nsstring file:@__FILENAME__ line:__LINE__]

@interface NSError (Reporting)

+ (NSError *)error:(NSInteger)code description:(NSString *)description file:(NSString *)file line:(NSInteger)line;

@end
