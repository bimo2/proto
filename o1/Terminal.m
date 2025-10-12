//
//  Terminal.m
//  o1
//
//  Created by gpt-5-high on 2025-10-10.
//

#import "Terminal.h"

#import <dispatch/dispatch.h>

#include "include.h"
#include "session.h"

#include <crt_externs.h>

static NSString *TerminalErrorDomain = @"TerminalErrorDomain";

@interface Terminal () {
    session_t *session;
    dispatch_queue_t io_queue;
    dispatch_source_t read_source;
    dispatch_source_t proc_source;
}

@end

@implementation Terminal

- (instancetype)init {
    self = [super init];

    if (self) {
        session = init_session();
        io_queue = dispatch_queue_create("com.github.o1.io_queue", DISPATCH_QUEUE_SERIAL);
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

    if (self.running) {
        [self setupReadSource];
        [self setupProcSource];
    } else if (error) {
        *error = [NSError errorWithDomain:TerminalErrorDomain code:errno userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%s", strerror(errno)]}];
    }

    return self.running;
}

- (void)stop {
    if (!self.running) return;

    session_stop(session);
}

- (void)setupReadSource {
    int fd = session_fd(session);

    if (read_source || fd < 0) return;

    read_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)fd, 0, io_queue);

    __weak typeof(self) weakSelf = self;

    dispatch_source_set_event_handler(read_source, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        uint8_t bytes[_KB(16)];

        while (1) {
            ssize_t size = session_read(strongSelf->session, bytes, sizeof(bytes));

            if (size > 0) {
                if (strongSelf.dataBlock) strongSelf.dataBlock(bytes, size);

                continue;
            }

            if (size == 0) {
                if (strongSelf->read_source) {
                    dispatch_source_cancel(strongSelf->read_source);
                    strongSelf->read_source = nil;
                }

                break;
            }

            if (size < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) break;

                if (strongSelf->read_source) {
                    dispatch_source_cancel(strongSelf->read_source);
                    strongSelf->read_source = nil;
                }

                break;
            }
        }
    });

    dispatch_resume(read_source);
}

- (void)setupProcSource {
    pid_t pid = session_pid(session);

    if (proc_source || pid < 1) return;

    proc_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, (uintptr_t)pid, DISPATCH_PROC_EXIT, io_queue);

    __weak typeof(self) weakSelf = self;

    dispatch_source_set_event_handler(proc_source, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        int status = 0;

        waitpid(pid, &status, WNOHANG);

        if (status == session_pid(strongSelf->session)) {
            if (strongSelf.exitBlock) strongSelf.exitBlock(status);

            session_stop(strongSelf->session);

            if (strongSelf->read_source) {
                dispatch_source_cancel(strongSelf->read_source);
                strongSelf->read_source = nil;
            }

            if (strongSelf->proc_source) {
                dispatch_source_cancel(strongSelf->proc_source);
                strongSelf->proc_source = nil;
            }
        }
    });

    dispatch_resume(proc_source);
}

@end
