//
//  Terminal.m
//  o1
//
//  Created by gpt-5-high on 2025-10-10.
//

#import "Terminal.h"

#include "session.h"

#include <crt_externs.h>

static NSString *TerminalErrorDomain = @"TerminalErrorDomain";

@interface Terminal () {
    session_t *session;
}

@end

@implementation Terminal

- (instancetype)init {
    self = [super init];

    if (self) {
        session = init_session();
        _file = @"/bin/zsh";
        _flags = @[];
        _environment = @{};
    }

    return self;
}

- (void)dealloc {
    [self stop];
    free_session(session);
}

- (BOOL)isRunning {
    return session_running(session);
}

- (BOOL)start:(NSError **)error {
    if (self.running) return YES;

    NSMutableArray<NSString *> *argvObjC = [NSMutableArray array];

    [argvObjC addObject:self.file];

    if (self.flags) [argvObjC addObjectsFromArray:self.flags];

    size_t argc = argvObjC.count;
    char **argv = (char **)calloc(argc + 1, sizeof(char *));

    for (size_t i = 0; i < argc; i++) argv[i] = strdup(argvObjC[i].UTF8String);

    argv[argc] = NULL;

    NSMutableDictionary<NSString *, NSString *> *envpObjC = [NSMutableDictionary dictionary];
    char **current = *_NSGetEnviron();

    if (current) {
        for (char **e = current; *e; e++) {
            char *eq = strchr(*e, '=');

            if (!eq) continue;

            size_t length = (size_t)(eq - *e);
            NSString *key = [[NSString alloc] initWithBytes:*e length:length encoding:NSUTF8StringEncoding];
            NSString *value = [NSString stringWithUTF8String:eq + 1];

            if (key && value) envpObjC[key] = value;
        }
    }

    if (self.environment) [envpObjC addEntriesFromDictionary:self.environment];
    if (!envpObjC[@"TERM"]) envpObjC[@"TERM"] = @"xterm-256color";

    size_t envc = envpObjC.count;
    char **envp = (char **)calloc(envc + 1, sizeof(char *));
    __block size_t i = 0;

    [envpObjC enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        NSString *pair = [NSString stringWithFormat:@"%@=%@", key, value];

        envp[i++] = strdup(pair.UTF8String);
    }];

    envp[envc] = NULL;
    session_start(session, self.file.UTF8String, argv, envp);

    for (i = 0; i < argc; i++) free(argv[i]);
    for (i = 0; i < envc; i++) free(envp[i]);

    free(argv);
    free(envp);

    if (!self.running && error) {
        *error = [NSError errorWithDomain:TerminalErrorDomain code:errno userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%s", strerror(errno)]}];
    }

    return self.running;
}

- (void)stop {
    if (!self.running) return;

    session_stop(session);
}

@end
