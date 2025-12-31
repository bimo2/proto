//
//  Terminal.m
//  o1
//
//  Created by gpt-5-high on 2025-10-10.
//

#import "Terminal.h"

#include "ansi.h"
#include "ansi_reader.h"
#include "include.h"
#include "render.h"
#include "screen.h"
#include "screen_context.h"
#include "session.h"

#include <crt_externs.h>
#include <dispatch/dispatch.h>
#include <errno.h>
#include <string.h>
#include <sys/wait.h>

static void on_ansi_callback(void *, ansi_t *);
static void on_title_callback(void *, const char *);
static void on_response_callback(void *, const char *);
static void on_bell_callback(void *);
static void on_mouse_callback(void *, bool);

@interface Terminal () {
    session_t *session;
    ansi_reader_t *reader;
    screen_context_t *context;
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
        reader = init_ansi_reader();
        context = init_screen_context();
        io_queue = dispatch_queue_create("com.github.o1.io_queue", DISPATCH_QUEUE_SERIAL);
        write_source_suspended = true;
        _file = @"/bin/zsh";
        _flags = @[];
        _environment = @{};

        __weak typeof(self) weakSelf = self;

        ansi_reader_set_callback(reader, on_ansi_callback, (__bridge void *)weakSelf);
        screen_context_set_response_callback(context, on_response_callback, (__bridge void *)weakSelf);
        screen_context_set_title_callback(context, on_title_callback, (__bridge void *)weakSelf);
        screen_context_set_bell_callback(context, on_bell_callback, (__bridge void *)weakSelf);
        screen_context_set_mouse_callback(context, on_mouse_callback, (__bridge void *)weakSelf);
    }

    return self;
}

- (void)dealloc {
    [self stop];
    free_screen_context(context);
    free_ansi_reader(reader);
    free_session(session);
}

- (BOOL)isRunning {
    return session_running(session);
}

- (BOOL)start:(__autoreleasing NSError **)error {
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
        *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%s", strerror(errno)]}];
    }

    return self.running;
}

- (void)stop {
    if (!self.running) return;

    __weak typeof(self) weakSelf = self;

    dispatch_async(io_queue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

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

        ansi_reader_reset(strongSelf->reader);
        session_stop(strongSelf->session);
    });
}

- (void)write:(NSData *)data {
    if (!self.running || data.length < 1) return;

    __weak typeof(self) weakSelf = self;

    dispatch_async(io_queue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        session_write(strongSelf->session, (const uint8_t *)data.bytes, data.length, NULL);

        if (strongSelf->write_source && strongSelf->write_source_suspended) {
            dispatch_resume(strongSelf->write_source);
            strongSelf->write_source_suspended = false;
        }
    });
}

- (void)paste:(NSData *)data {
    if (data.length < 1) return;

    if (!screen_context_bracketed_paste(context)) {
        [self write:data];

        return;
    }

    static unsigned long start_length = strlen(ANSI_BRACKETED_PASTE_START);
    static unsigned long end_length = strlen(ANSI_BRACKETED_PASTE_END);
    NSMutableData *payload = [NSMutableData dataWithCapacity:(start_length + data.length + end_length)];

    [payload appendBytes:ANSI_BRACKETED_PASTE_START length:start_length];
    [payload appendData:data];
    [payload appendBytes:ANSI_BRACKETED_PASTE_END length:end_length];
    [self write:payload];
}

- (void)scroll:(NSInteger)delta {
    __weak typeof(self) weakSelf = self;

    dispatch_async(io_queue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        screen_context_scroll(strongSelf->context, (int32_t)delta);

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;

            if (!strongSelf) return;

            screen_t *screen = screen_context_current_screen(strongSelf->context);

            if (strongSelf.renderBlock) {
                render_t *ops = NULL;
                size_t count = 0;

                render_collect_ops(&ops, screen, &count);

                if (count > 0) strongSelf.renderBlock(ops, count);
                if (ops) render_clear_ops(ops, count);
            }

            if (strongSelf.updateBlock) strongSelf.updateBlock(screen);
        });
    });
}

- (void)focus:(BOOL)isFocused {
    if (!screen_context_focus_reporting(context)) return;

    const char *sequence = isFocused ? ANSI_FOCUS_IN : ANSI_FOCUS_OUT;
    NSData *data = [NSData dataWithBytes:sequence length:strlen(sequence)];

    [self write:data];
}

- (void)layout:(NSSize)size rows:(NSUInteger)rows columns:(NSUInteger)columns {
    __weak typeof(self) weakSelf = self;

    dispatch_async(io_queue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) return;

        uint32_t width = (uint32_t)lround(size.width);
        uint32_t height = (uint32_t)lround(size.height);

        screen_context_set_grid(strongSelf->context, (uint32_t)rows, (uint32_t)columns);
        session_update_window(strongSelf->session, (uint32_t)rows, (uint32_t)columns, width, height);

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;

            if (!strongSelf) return;

            screen_t *screen = screen_context_current_screen(strongSelf->context);

            if (strongSelf.renderBlock) {
                render_t *ops = NULL;
                size_t count = 0;

                render_collect_ops(&ops, screen, &count);

                if (count > 0) strongSelf.renderBlock(ops, count);
                if (ops) render_clear_ops(ops, count);
            }

            if (strongSelf.updateBlock) strongSelf.updateBlock(screen);
        });
    });
}

- (void)keyboard:(ansi_keyboard_t)value flags:(NSEventModifierFlags)flags {
    uint16_t mods = 0;

    if (flags & NSEventModifierFlagShift) mods |= ANSI_MODIFIER_FLAG_SHIFT;
    if (flags & NSEventModifierFlagOption) mods |= ANSI_MODIFIER_FLAG_OPTION;
    if (flags & NSEventModifierFlagControl) mods |= ANSI_MODIFIER_FLAG_CONTROL;

    uint8_t bytes[64];
    size_t length = ansi_keyboard(value, mods, screen_context_cursor_keys(context), bytes, sizeof(bytes));

    if (length < 1) return;

    NSData *data = [NSData dataWithBytes:bytes length:length];

    [self write:data];
}

- (void)mouse:(ansi_mouse_t)button event:(ansi_mouse_event_t)event flags:(NSEventModifierFlags)flags row:(NSUInteger)row column:(NSUInteger)column {
    screen_context_mouse_mode_t mode = screen_context_mouse_mode(context);

    if (mode == SCREEN_CONTEXT_MOUSE_NONE) return;

    uint16_t mods = 0;

    if (flags & NSEventModifierFlagShift) mods |= ANSI_MODIFIER_FLAG_SHIFT;
    if (flags & NSEventModifierFlagOption) mods |= ANSI_MODIFIER_FLAG_OPTION;
    if (flags & NSEventModifierFlagControl) mods |= ANSI_MODIFIER_FLAG_CONTROL;

    uint32_t x = MAX(1, (uint32_t)column);
    uint32_t y = MAX(1, (uint32_t)row);
    bool sgr = screen_context_mouse_sgr(context);
    uint8_t bytes[64];
    size_t length = 0;

    switch (mode) {
        case SCREEN_CONTEXT_MOUSE_X10:
            length = ansi_mouse_x10(button, event, mods, x, y, sgr, bytes, sizeof(bytes));

            break;
        case SCREEN_CONTEXT_MOUSE_NORMAL:
            length = ansi_mouse_normal(button, event, mods, x, y, sgr, bytes, sizeof(bytes));

            break;
        default:
            length = ansi_mouse_all(button, event, mods, x, y, sgr, bytes, sizeof(bytes));

            break;
    }

    if (length < 1) return;

    NSData *data = [NSData dataWithBytes:bytes length:length];

    [self write:data];
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
                ansi_reader_feed(strongSelf->reader, bytes, (size_t)size);

                continue;
            }

            if (size < 0 && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)) break;

            [strongSelf stop];

            break;
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

        int code = status;

        if (WIFEXITED(status)) {
            code = WEXITSTATUS(status);
        } else if (WIFSIGNALED(status)) {
            code = 128 + WTERMSIG(status);
        }

        if (strongSelf.exitBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                strongSelf.exitBlock(code);
            });
        }

        dispatch_source_cancel(strongSelf->proc_source);
        strongSelf->proc_source = nil;
        [strongSelf stop];
    });

    dispatch_resume(proc_source);
}

- (screen_context_t *)_context {
    return context;
}

@end

static void on_ansi_callback(void *user_data, ansi_t *ansi) {
    Terminal *self = (__bridge Terminal *)user_data;

    if (!self) return;

    screen_context_t *context = [self _context];
    screen_context_update(context, ansi);

    dispatch_async(dispatch_get_main_queue(), ^{
        screen_t *screen = screen_context_current_screen(context);

        if (self.renderBlock) {
            render_t *ops = NULL;
            size_t count = 0;

            render_collect_ops(&ops, screen, &count);

            if (count > 0) self.renderBlock(ops, count);
            if (ops) render_clear_ops(ops, count);
        }

        if (self.updateBlock) self.updateBlock(screen);
    });
}

static void on_title_callback(void *user_data, const char *title) {
    Terminal *self = (__bridge Terminal *)user_data;

    if (!self) return;

    if (self.titleBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.titleBlock(title);
        });
    }
}

static void on_response_callback(void *user_data, const char *response) {
    Terminal *self = (__bridge Terminal *)user_data;

    if (!self) return;

    if (response) {
        NSData *data = [NSData dataWithBytes:response length:strlen(response)];

        [self write:data];
    }
}

static void on_bell_callback(void *user_data) {
    Terminal *self = (__bridge Terminal *)user_data;

    if (!self) return;

    if (self.bellBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.bellBlock();
        });
    }
}

static void on_mouse_callback(void *user_data, bool enable) {
    Terminal *self = (__bridge Terminal *)user_data;

    if (!self) return;

    if (self.mouseBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.mouseBlock(enable);
        });
    }
}
