# AGENTS.md

- you are building a GPU-accelerated terminal emulator for macOS that should:
- be xterm-compatible and capable of running shells/applications like _zsh_, _nano_, _tmux_ and _codex_,
- support all modern ECMA-48 control sequences like cursor movement, alternate screens, mouse tracking, hyperlinks and bracketed paste,
- expect high throughput from data streams like `cat` or verbose logging like `make`, and
- use non-blocking IO for fast render updates and animations

## Code

- low level terminal code and underlying data structures should be implemented in C
- expect `/o1/lib` to be exported as a standalone static library (`libo1.a`)
- UI and rendering code should be implemented in Objective-C using AppKit and Metal
- threads should be handled in Objective-C using GCD
- all unit tests should be implemented in Objective-C using XCTest

## Debug

- try printing PTY output bytes using `printx` to debug expected results
- try printing `screen_t` to debug actual results
- try using shell commands like `echo` to replicate and isolate issues
