# JetBrains Mono Font Dependency

最近核对日期：2026-08-28

## Exact dependency

- 字体：JetBrains Mono `v2.304`。
- 上游：JetBrains 官方 `JetBrains/JetBrainsMono` 仓库的 `v2.304` release。
- 官方发布包：`JetBrainsMono-2.304.zip`。
- 官方发布包 SHA-256：`6f6376c6ed2960ea8a963cd7387ec9d76e3f629125bc33d1fdcd7eb7012f7bbf`。
- 许可证：SIL Open Font License 1.1。
- 本仓库许可证原文：`Sources/KuzioApp/Fonts/JetBrainsMono-OFL.txt`。
- runtime owner：唯一 `/Users/vita/Vitemis/Intatis` checkout 的 `IntatisSharedUI` SwiftPM product。
- 用途：Kuzio 与 dependency-owned Cowork Harness 的 Latin、数字与技术文本共同字体；SF Symbols 和 CJK 字形不由该依赖提供。

正式 App 只注册和使用 `IntatisSharedUI` resource bundle 中的两个官方 variable TTF：

| Bundle resource | 主要 PostScript family | SHA-256 |
| --- | --- | --- |
| `Intatis_IntatisSharedUI.bundle/Contents/Resources/JetBrainsMono[wght].ttf` | `JetBrainsMono-Regular_*` upright instances | `662a196d58f1183bf2d77428b6d5283fe3f45161ab021bea4036bc98e5cac016` |
| `Intatis_IntatisSharedUI.bundle/Contents/Resources/JetBrainsMono-Italic[wght].ttf` | `JetBrainsMono-Italic_*` italic instances | `f115aaa12113718c02ce72864fe6823b87241bc23d3e44cf1220155f861063f2` |

`Sources/KuzioApp/Fonts/` 中原有 Regular、Medium、SemiBold、Bold 四个静态 TTF 仍是既有未提交工作区之前的 tracked source，但当前 `Package.swift` 明确 exclude，`project.yml` 也不把它们加入 resources。它们不进入 SwiftPM module bundle、Xcode App bundle或 process registration，不是 fallback；后续是否从源码树永久删除需要单独确认，不能把存在于仓库误写成当前 runtime dependency。

## Bundle wiring

- SwiftPM：`KuzioApp` 直接依赖 `IntatisSharedUI`；其两个 TTF 由 dependency `Bundle.module` 形成 `Intatis_IntatisSharedUI.bundle`。Kuzio 自己只 `.copy("Fonts/JetBrainsMono-OFL.txt")`，并显式 exclude 四个旧静态 TTF。
- Xcode：`project.yml` 直接声明 `IntatisSharedUI` product，仅把 `Sources/KuzioApp/Fonts/JetBrainsMono-OFL.txt` 放入 App resources；生成工程不得再出现四个静态 TTF 的 Resources build file。
- App bundle：两个 variable TTF 只存在于 IntatisSharedUI resource bundle；OFL 文本存在于 `Contents/Resources/JetBrainsMono-OFL.txt`。
- 不复制 Intatis 字体 bytes 到 Kuzio resources，不建立第二个注册器、下载器、缓存或字体 provider。

## Runtime registration

`KuzioApp.init()` 的顺序固定为：

1. `IntatisHostApplication.configure(name: "Kuzio")` 安装 process-wide host identity。
2. 校验 `IntatisCodexRuntime` public API major。
3. 直接调用 `IntatisTypography.prepareJetBrainsMonoTypography()`。

`IntatisSharedUI` 负责：

1. 从自己的 `Bundle.module` 读取两个 exact variable TTF。
2. 校验固定 SHA-256 和完整 PostScript descriptor set。
3. 用 Core Text process scope 注册。
4. 验证每个 PostScript name 精确解析回 dependency bundle URL。
5. 任一步失败时 precondition failure；不回退到系统 serif、SF Mono、Menlo、旧 Kuzio 静态 TTF 或另一 JetBrains Mono 版本。

学习库源码直接使用 `IntatisTypography` 的语义字体 API，并在需要保持既有 Kuzio 尺寸时传入显式 point size/weight；仓库不再保留 `KuzioTypography` wrapper、第二份注册生命周期或字体 backend。

## Typography contract

- single-line sidebar brand：28pt semibold。
- page title：32pt bold。
- section/card：16–17pt semibold。
- body：14–15pt regular/medium。
- metadata/caption：11–13pt medium/semibold。
- dependency-owned `CoworkShell` 使用 IntatisSharedUI 自己的 thread typography、composer、rich renderer 与 control metrics；Kuzio 不覆盖其中的 text styles。
- `.font(.system...)` 只能用于 Kuzio `Image(systemName:)` 的 SF Symbol size/weight，不得重新进入 product text。

## CJK 与 symbol 边界

JetBrains Mono `v2.304` 不包含 CJK 汉字。SwiftUI/AppKit 使用 dependency font 作为 primary family 时，汉字继续进入 Apple 系统 fallback cascade，并由 macOS PingFang 提供；本仓库不嵌入、复制或替代苹方。

SF Symbols 继续使用系统 symbol font。Kuzio action icon 的 `.font(.system(size:weight:))` 只控制 symbol 视觉尺寸，不是 product text fallback；Cowork Harness 的 icon/control presentation由 IntatisSharedUI 拥有。

## 变更与验证合同

任何字体或 SharedUI product 变更必须同步核对：

1. IntatisSharedUI product/resource graph 与两个 variable TTF checksum。
2. `Package.swift` / `project.yml` 只接入 SharedUI fonts + Kuzio OFL，不重新打包旧静态 TTF。
3. `KuzioApp` 与学习库 views 继续直接调用 dependency typography lifecycle/roles，不恢复 `KuzioTypography` wrapper。
4. 本文件、`PROJECT_MAP.md`、`ARCHITECTURE.md`、`DO_NOT_BREAK.md` 与 `TESTING.md`。
5. SwiftPM/Xcode build、App bundle inventory、PostScript registration、Light/Dark 与中英混排 glyph fallback。

exact dependency 不可用时必须停止字体和 Shared Harness 能力并报告 blocker；不得自行选择或实现替代字体。
