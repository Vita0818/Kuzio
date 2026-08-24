# PROJECT_MAP

最近自查日期：2026-08-24

本文描述当前 macOS 26 SwiftUI App、可移植本地资料库、SwiftPM 测试和 XcodeGen 工程结构。

## 目录结构

```text
Kuzio/
├── .gitignore
├── AGENTS.md
├── CLAUDE.md
├── GEMINI.md
├── Package.swift
├── project.yml
├── Kuzio.xcodeproj/
├── Sources/KuzioApp/
│   ├── KuzioApp.swift
│   ├── KuzioTypography.swift
│   ├── KuzioControlMetrics.swift
│   ├── SystemFileIconProvider.swift
│   ├── LibraryNode.swift
│   ├── LibraryViewModel.swift
│   ├── LibraryRootView.swift
│   ├── LibraryBrowserView.swift
│   ├── LibraryReaderView.swift
│   ├── LibraryTrashView.swift
│   ├── LibraryOperationSheets.swift
│   ├── Fonts/
│   │   ├── JetBrainsMono-Regular.ttf
│   │   ├── JetBrainsMono-Medium.ttf
│   │   ├── JetBrainsMono-SemiBold.ttf
│   │   ├── JetBrainsMono-Bold.ttf
│   │   └── JetBrainsMono-OFL.txt
│   └── LibraryStorage/
│       ├── LibraryIdentifiers.swift
│       ├── LibraryManifest.swift
│       ├── LibraryManifestValidator.swift
│       ├── LibraryPackagePaths.swift
│       ├── LibraryStoreError.swift
│       ├── LibraryStoreIO.swift
│       ├── LibraryStore.swift
│       ├── LibraryStore+Mutations.swift
│       ├── LibraryStore+Transactions.swift
│       └── LibraryBootstrap.swift
├── Tests/KuzioAppTests/
│   └── LibraryStoreTests.swift
└── docs/
    ├── ARCHITECTURE.md
    ├── CURRENT_STATE.md
    ├── DO_NOT_BREAK.md
    ├── FONT_DEPENDENCY.md
    ├── NEXT_TARGET.md
    ├── PROJECT_MAP.md
    └── TESTING.md
```

`.git/` 是仓库元数据，不属于业务源码，不得直接编辑。

## Target / 模块

| Target / 模块 | 类型 | 平台 | 入口 | 职责 |
| --- | --- | --- | --- | --- |
| `Kuzio` | Xcode macOS App | macOS 26+ | `KuzioApp.swift` | 正式 `.app` target 与资源 bundle |
| `KuzioApp` | SwiftPM executable/module | macOS 26+ | `KuzioApp.swift` | 共享 App 源码与 SwiftPM 构建入口 |
| `KuzioAppTests` | SwiftPM test | macOS | `LibraryStoreTests.swift` | 文件系统、并发、一致性和安全回归 |

## 关键源码

### App 与前端

- `KuzioApp.swift`：`WindowGroup`、进程级 `LibraryViewModel`、字体启动校验、DEBUG appearance 参数与 store 启动任务。
- `KuzioTypography.swift`：JetBrains Mono 四档资源 checksum、Core Text process registration、PostScript 校验与文字 token。
- `KuzioControlMetrics.swift`：Rokurics macOS 的 36pt icon control / 15pt symbol 尺寸事实。
- `SystemFileIconProvider.swift`：通过 `NSWorkspace.icon(for:)` 获取 Finder 原生 folder icon 的最薄 AppKit 接线。
- `LibraryRootView.swift`：系统 `NavigationSplitView`、参考三项目 macOS 比例的轻量 destination sidebar 与切换。
- `LibraryBrowserView.swift`：固定页标题、history、breadcrumb、search、folder grid、document list 与 context operations。
- `LibraryReaderView.swift`：document header、metadata、Markdown 阅读、文本编辑与保存。
- `LibraryTrashView.swift`：trash roots、restore 与 permanent delete UI。
- `LibraryOperationSheets.swift`：create/rename/move 的系统 sheet。

### 数据与文件系统

- `LibraryNode.swift`：UI-facing `LibraryEntry`、`LibrarySnapshot`、`StoredDocument` 与 commit receipts。
- `LibraryViewModel.swift`：`@MainActor @Observable` navigation/search/editor state，调用唯一 production `LibraryStore`。
- `LibraryIdentifiers.swift`：canonical lowercase UUID wrappers。
- `LibraryManifest.swift`：schema v1 manifest、node、payload、trash、transaction/purge intent records。
- `LibraryPackagePaths.swift`：只由常量和 UUID 构造 managed path，并执行 containment/file-type/link 检查。
- `LibraryManifestValidator.swift`：资源上限、shape、version、hierarchy、cycle/orphan/trash 与 payload metadata 验证。
- `LibraryStoreIO.swift`：bounded read、durable write、atomic replace、SHA-256 与 IO error mapping。
- `LibraryStore.swift`：create/open/recover/snapshot/refresh/coordinated document read。
- `LibraryStore+Mutations.swift`：create/update/rename/move/trash/restore/delete 与 expected revision contract。
- `LibraryStore+Transactions.swift`：staging、publish、previous manifest、purge completion 与 coordinated garbage collection。
- `LibraryBootstrap.swift`：production Application Support 默认包；DEBUG-only preview package。

## 构建事实源与资源

- `Package.swift` 定义 `KuzioApp` executable 与 `KuzioAppTests`，并以 `.copy("Fonts")` 保留 font bundle 子目录。
- `project.yml` 是正式 App 工程事实源；源码排除 `Fonts` 后把它作为 folder resource 加入 resources build phase。
- `Kuzio.xcodeproj/project.pbxproj` 由本机 XcodeGen 2.45.4 生成；已包含 typography、control metrics、AppKit icon provider 与 `Fonts in Resources`。
- `Sources/KuzioApp/Fonts/JetBrainsMono-OFL.txt` 随 App 分发，字体 provenance/checksum 见 `docs/FONT_DEPENDENCY.md`。

## Runtime 数据布局

- production root：用户 Application Support / `Kuzio/Default.kuzio`。
- authoritative manifest：`manifest.json`。
- immutable payload：`objects/<ID 前两位>/<ID>.payload`。
- recovery / transaction state：`.state/previous-manifest.json`、`.state/transactions/`、`.state/purge/`。
- title、breadcrumb 与显示层级不会参与任何磁盘路径构造。

## 测试与生成物

- `LibraryStoreTests.swift` 当前有 18 个 async/filesystem 测试方法；最新改动尚未实际运行。
- `.build/`、`DerivedData/` 是本地生成物并被忽略，不得作为源码事实。
- Debug App 预期路径：`DerivedData/Build/Products/Debug/Kuzio.app`；必须在成功构建后才能视为当前产物。

## 当前不确定项

- 外部 `.kuzio` package 的 Open/Save panel、document type registration、导入/导出 UX：`UNKNOWN`。
- schema migration、同步、账号、网络、跨端平台、签名、公证与发布方式：`UNKNOWN`。
- 最新源码的 compiler/test/runtime 结果：等待明确构建授权后确认。
