# NEXT_TARGET

## Active Target

- Status: active
- Objective: Finish the Rokurics/Intatis-informed Kuzio frontend and portable arbitrary-depth filesystem with real build, test, and window evidence.
- Implemented: JetBrains Mono global typography; Finder native folder icons; corrected 36pt/15pt macOS glass controls; 28pt single-line brand sidebar with compact rows; system split view; versioned `.kuzio` package; stable IDs; CRUD/trash/recovery; coordinated multi-writer reads and garbage collection; 18 filesystem tests; updated project documentation.
- Remaining: rerun `swift test` and Xcode Debug App build after the `NSWorkspace.icon(for:)` compiler fix, then complete font bundle checks and Light/Dark end-to-end window inspection; fix any subsequent real compiler/runtime defects found.
- Validation: Swift tests, Xcode App build, font resource integrity, filesystem fault/safety tests, and Light/Dark window inspection.
- Blocker: current session requires an explicit user approval before build/test commands may be retried; compiler and runtime results are therefore still unknown.

## Rules

- Keep at most one active objective here.
- Delete this file when the objective is complete or no longer current.
