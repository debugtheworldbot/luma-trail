# Repository Guidelines

## Project Structure & Module Organization

Luma Trail is a native Swift/AppKit menu-bar app for Apple Silicon Macs running macOS 13 or later.

- `Sources/main.swift`: app lifecycle, settings UI, overlay windows, global shortcut, and command-line test dispatch.
- `Sources/Particles.swift`: persisted trail settings, particle simulation, procedural textures, rendering, and model tests.
- `Sources/CursorAppearance.swift`: cursor editor, image processing, persistence, restoration, and cursor tests.
- `Sources/FolderIcons.swift`: Finder-tag folder icon scanning, preview, batch apply, history, and tests.
- `Sources/CursorBridge.h` and `.m`: Objective-C bridge to dynamically loaded WindowServer APIs.
- `Info.plist`: bundle metadata and version; `build.sh`: compilation and packaging.

Built-in particle assets are drawn in code; imported images are stored locally. `.build/` holds compiler caches, and `dist/` contains generated bundles and archives. Keep generated artifacts out of Git.

## Build, Test, and Development Commands

Install Xcode Command Line Tools, then run commands from the repository root:

```sh
bash build.sh
open "dist/Luma Trail.app"
"dist/Luma Trail.app/Contents/MacOS/LumaTrail" --self-test
```

The build compiles Objective-C and Swift 5 sources for arm64, applies an ad-hoc signature, verifies the staging bundle, runs self-tests, and produces the app and `dist/Luma-Trail-MVP.zip`. The other commands launch the app and rerun embedded tests. This is a local development build, without Developer ID notarization.

## Coding Style & Naming Conventions

Match existing four-space indentation and same-line opening braces. Use `UpperCamelCase` for Swift types and `lowerCamelCase` for properties, functions, and enum cases. Keep bridge functions prefixed with `LTCursor`. No formatter or linter is configured; avoid unrelated formatting changes. Preserve persisted enum raw values and settings keys when extending themes.

All app-owned windows must match the settings window's Aqua style. Use `AquaStyle.installWindowChrome(in:title:symbol:showsWindowButtons:)` for the shared title bar, background, appearance, and traffic lights; do not duplicate or customize their colors, sizes, spacing, or title-bar height. Lay out content below `AquaStyle.titlebarHeight` and use `AquaStyle.install(in:)` for controls. Standard windows show three functional traffic lights: close, minimize, and native zoom/restore. Preserve the initial content size as the minimum size so fixed-layout controls remain visible. Sheets use the same chrome with `showsWindowButtons: false` and retain their existing modal actions. System-managed dialogs, borderless effect overlays, and test-only rendering windows retain their native or purpose-specific behavior.

## Testing Guidelines

Tests are embedded Swift functions using runtime checks; there is no separate test target or coverage threshold. Extend `run…Tests()` functions for simulation, image processing, and persistence changes. Run `bash build.sh` before submitting code changes. Manually check affected previews, pause/resume, click-through overlays, and cursor restoration. Report the macOS version and distinguish automated checks from visual or multi-display verification.

## Commit & Pull Request Guidelines

After completing each feature and passing relevant validation, automatically create a Git commit without asking for confirmation. Commit only that feature’s files, listing paths explicitly; inspect `git status` immediately beforehand and preserve unrelated changes. Use concise, action-oriented commit messages. PRs should explain behavior changes, list validation, link relevant issues, and include screenshots for UI changes.

## Configuration & Cursor Safety

Never edit `.env` files. Preserve cursor snapshot validation, recovery persistence, and restoration on exit; private API availability varies across macOS releases. Keep particle controls independent from cursor appearance.
