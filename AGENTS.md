# AGENTS.md

- You are building a production GPU accelerated terminal emulator for macOS that should:
- be capable of running shell applications like `zsh`, `nano` and `tmux`,
- support modern ANSI escape sequences like mouse tracking, hyperlinks and bracketed paste,
- expect high throughput from data streams like `cat` or verbose logging like `make`, and
- use non-blocking IO for fast render updates and animations

## Code

- Low level terminal code and underlying data structures should be implemented in C (under o1/lib/)
- UI and rendering code should be implemented in Objective-C using AppKit and Metal (under o1/)
- Threads should be handled in Objective-C using GCD
- All unit tests should be implemented in Objective-C using XCTest
