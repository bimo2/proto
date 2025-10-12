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
    dispatch_source_t write_source;
    dispatch_source_t proc_source;
    bool write_source_suspended;
}

@end

@implementation Terminal

- (instancetype)init {
    self = [super init];

    if (self) {
        session = init_session();
        io_queue = dispatch_queue_create("com.github.o1.io_queue", DISPATCH_QUEUE_SERIAL);
        write_source_suspended = true;
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
        [self setupWriteSource];
        [self setupProcSource];
    } else if (error) {
        *error = [NSError errorWithDomain:TerminalErrorDomain code:errno userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%s", strerror(errno)]}];
    }

    return self.running;
}

- (void)stop {
    if (!self.running) return;

    __weak typeof(self) weakSelf = self;

    dispatch_sync(io_queue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        if (strongSelf->proc_source) {
            dispatch_source_cancel(strongSelf->proc_source);
            strongSelf->proc_source = nil;
        }

        if (strongSelf->write_source) {
            if (strongSelf->write_source_suspended) {
                dispatch_resume(strongSelf->write_source);
                strongSelf->write_source_suspended = false;
            }

            dispatch_source_cancel(strongSelf->write_source);
            strongSelf->write_source = nil;
            strongSelf->write_source_suspended = true;
        }

        if (strongSelf->read_source) {
            dispatch_source_cancel(strongSelf->read_source);
            strongSelf->read_source = nil;
        }

        session_stop(strongSelf->session);
    });
}

- (void)write:(NSData *)data {
    if (!self.running) return;

    __weak typeof(self) weakSelf = self;

    dispatch_async(io_queue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        session_write(strongSelf->session, (const uint8_t *)data.bytes, data.length);

        if (strongSelf->write_source && strongSelf->write_source_suspended) {
            dispatch_resume(strongSelf->write_source);
            strongSelf->write_source_suspended = false;
        }
    });
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
                if (strongSelf.dataBlock) {
                    NSData *data = [NSData dataWithBytes:bytes length:size];

                    strongSelf.dataBlock(data);
                }

                continue;
            }

            if (size == 0) {
                [strongSelf stop];

                break;
            }

            if (size < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) break;

                [strongSelf stop];

                break;
            }
        }
    });

    dispatch_resume(read_source);
}

- (void)setupWriteSource {
    int fd = session_fd(session);

    if (write_source || fd < 0) return;

    write_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, (uintptr_t)fd, 0, io_queue);

    __weak typeof(self) weakSelf = self;

    dispatch_source_set_event_handler(write_source, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        if (session_flush_write(strongSelf->session) > -1) {
            if (!strongSelf->write_source_suspended) {
                dispatch_suspend(strongSelf->write_source);
                strongSelf->write_source_suspended = true;
            }
        }
    });

    dispatch_resume(write_source);
    dispatch_suspend(write_source);
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

        if (strongSelf.exitBlock) strongSelf.exitBlock(status);

        [strongSelf stop];
    });

    dispatch_resume(proc_source);
}

@end
