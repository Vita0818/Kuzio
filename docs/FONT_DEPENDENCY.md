# JetBrains Mono Font Dependency

最近核对日期：2026-08-24

## Exact dependency

- 字体：JetBrains Mono `v2.304`。
- 上游：JetBrains 官方 `JetBrains/JetBrainsMono` 仓库的 `v2.304` release。
- 官方发布包：`JetBrainsMono-2.304.zip`。
- 官方发布包 SHA-256：`6f6376c6ed2960ea8a963cd7387ec9d76e3f629125bc33d1fdcd7eb7012f7bbf`。
- 许可证：SIL Open Font License 1.1。
- 本仓库许可证原文：`Sources/KuzioApp/Fonts/JetBrainsMono-OFL.txt`。
- 用途：Kuzio 的 Latin、数字与技术文本共同字体；SF Symbols 和 CJK 字形不由该依赖提供。

本仓库只保留当前源码实际使用的四个官方静态 TTF，不修改、不 subset、不重命名、不重新编码：

| Bundle 文件 | PostScript name | SHA-256 |
| --- | --- | --- |
| `Fonts/JetBrainsMono-Regular.ttf` | `JetBrainsMono-Regular` | `a0bf60ef0f83c5ed4d7a75d45838548b1f6873372dfac88f71804491898d138f` |
| `Fonts/JetBrainsMono-Medium.ttf` | `JetBrainsMono-Medium` | `31c92d01a8a08528b718a43addf0ad3df0af2ca4b7b3290a452f70f358e14d3d` |
| `Fonts/JetBrainsMono-SemiBold.ttf` | `JetBrainsMono-SemiBold` | `1b3bfa1ed5665a4ce3f9feb68d2d4e40e70bf8b4b7d9a3edd418f321b4e166a0` |
| `Fonts/JetBrainsMono-Bold.ttf` | `JetBrainsMono-Bold` | `5590990c82e097397517f275f430af4546e1c45cff408bde4255dad142479dcb` |

本轮资源从已完成同版本 provenance/license 审查的本地 Rokurics font source 机械复制，并重新执行 source SHA-256；结果与其锁定的官方 release 文件一致。

## Bundle wiring

- source directory：`Sources/KuzioApp/Fonts/`。
- SwiftPM：`Package.swift` 使用 `.copy("Fonts")`，保持 module resource bundle 中的 `Fonts/` 子目录。
- Xcode App：`project.yml` 把 `Sources/KuzioApp/Fonts` 作为 `type: folder` 的 resources build phase 输入，保持 App bundle `Contents/Resources/Fonts/`。
- `xcodegen generate` 后，`Kuzio.xcodeproj/project.pbxproj` 必须包含 `Fonts in Resources`。
- OFL 文本与四个 TTF 一起进入 folder resource。

## Runtime registration

`KuzioTypography.ensureAvailable()` 在 `KuzioApp.init()` 执行：

1. 从 SwiftPM `Bundle.module` 或 Xcode `Bundle.main` 的 `Fonts/` 读取四个 exact TTF。
2. 用 CryptoKit SHA-256 与本文件锁定值逐项比较。
3. 用 Apple `CTFontManagerRegisterFontsForURL(..., .process, ...)` 注册每个 resource。
4. 用 AppKit `NSFont(name:size:)` 验证四个 PostScript name 可解析。
5. SwiftUI 只通过 `Font.custom(postScriptName, fixedSize:)` 使用这些字体。

任一步失败立即给出明确 fatal diagnostic 并停止 App；没有 system serif、SF Mono、Menlo、另一 JetBrains Mono 版本、下载器、缓存或 alternate provider fallback。

## Typography contract

- single-line sidebar brand：28pt semibold。
- page title：32pt bold。
- section/card：16–17pt semibold。
- body：14–15pt regular/medium。
- metadata/caption：11–13pt medium/semibold。
- `.font(.system...)` 只能用于 `Image(systemName:)` 的 SF Symbol size/weight，不得重新进入 product text。

## CJK 与 symbol 边界

JetBrains Mono `v2.304` 不包含 CJK 汉字。Kuzio 以 JetBrains Mono 作为 SwiftUI custom primary font 时，汉字继续进入 Apple 系统 fallback cascade，并由 macOS 的 PingFang 字体提供；本仓库不嵌入、复制或替代苹方。

SF Symbols 继续使用系统 symbol font。action icon 的 `.font(.system(size:weight:))` 只控制 symbol 视觉尺寸，不是 product text fallback。

## 变更与验证合同

任何字体变更必须同步更新：

1. `Sources/KuzioApp/Fonts/` 资源与 OFL。
2. `Package.swift` / `project.yml` bundle wiring。
3. `KuzioTypography` resource list、PostScript mapping 与 checksum。
4. 本文件、`PROJECT_MAP.md`、`ARCHITECTURE.md`、`DO_NOT_BREAK.md` 与 `TESTING.md`。
5. source checksum、SwiftPM/Xcode build、App bundle checksum、PostScript resolution 与中英混排 glyph run。

exact dependency 不可用时必须停止字体能力并报告 blocker；不得自行选择或实现替代字体。
