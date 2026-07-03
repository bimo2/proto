# proto

**A GPU native terminal designed for Apple ARM64 machines.** o1 is implemented in C and Metal using Apple Silicon's unified memory architecture for high performance, maximum throughput and low latency. See `o1` for user defaults including:

- CPU/memory uasge,
- SGR and color modes,
- UTF modes and Unicode support,
- OSC and hyperlink support,
- cursor and text rendering, and
- feature flags

## Download

> [!NOTE]
> Supports macOS 26+ (Tahoe) and Xcode 26.3+

You can download precompiled binaries and static libraries from the [GitHub Releases](https://github.com/bimo2/proto/releases) section.

## DEBUG

Build o1 using Xcode command-line tools:

```sh
# build the debug scheme
xcodebuild -scheme o1 -configuration Debug build

# run unit tests
xcodebuild -scheme o1-tests test

# run static analysis
xcodebuild -scheme o1 analyze
```

### POSIX Tests

POSIX tests are used to test `libo1` against shell applications like `nano`, `tmux` or `codex`. Add E2E tests by writing output bytes from `DISPATCH_SOURCE_TYPE_READ` to a binary file using `debug.h`, then read byte segments through a test fixture using `testing.h` and assert screen and cursor expectations. See [o1-tests/posix](./o1-tests/posix) for examples.

## RELEASE

> [!IMPORTANT]
> Signed and notarized archives are uploaded by GitHub Actions (job: release) and should be published with release tags:
>
> - `o1.xip`
> - `o1.app`

#

<sub><sup>**Open Source.** Copyright &copy; 2026 **Bimal Bhagrath**.</sup></sub>
