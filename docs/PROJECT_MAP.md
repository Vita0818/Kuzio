# PROJECT_MAP

最近自查日期：2026-08-27

本文描述当前 macOS 26 SwiftUI App、虚拟层级资料库、外部资源链接数据层、SwiftPM 测试和 XcodeGen 工程结构。

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
│   ├── LibraryToolControlPlane.swift
│   ├── LibraryToolProvider.swift
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
    ├── PROJECT_MAP.md
    ├── TESTING.md
    └── TOOL_CALLING.md
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
- `KuzioControlMetrics.swift`：Rokurics macOS 的 circle icon、sidebar row、folder/card icon、固定 grid tile 尺寸 token，以及拥有 36pt label interaction shape 的 `KuzioCircleIconButton` / menu control modifier。
- `SystemFileIconProvider.swift`：通过 `NSWorkspace.icon(for:)` 获取 Finder 原生 folder/file icon 的最薄 AppKit 接线。
- `LibraryRootView.swift`：系统 `NavigationSplitView`、参考三项目 macOS 比例的轻量 destination sidebar 与切换。
- `LibraryBrowserView.swift`：固定页标题、history、breadcrumb、search、等尺寸 folder/resource-link grid、document list、context operations、Finder 原生 empty-folder state、右上角唯一 `+`，以及添加/重新链接使用的原生 `NSOpenPanel`。
- `LibraryReaderView.swift`：document header、metadata、Markdown 阅读、文本编辑与保存。
- `LibraryTrashView.swift`：trash roots、restore 与 permanent delete UI。
- `LibraryOperationSheets.swift`：create/rename/move 的系统 sheet。

### 数据与文件系统

- `LibraryNode.swift`：UI-facing `LibraryEntry`、`LibrarySnapshot`、`StoredDocument`、`StoredExternalResource`、flat linked-tree/relink draft 与包含 node/resource identity 的 commit receipts。
- `LibraryToolControlPlane.swift`：provider-neutral 工具名称、capability、强类型 call/output/failure 与唯一控制面 actor；复用 Store snapshot/read/transaction，实现结构读取、UTF-8 内容分段读取和有限结构 mutation，不包含模型或 transport adapter。
- `LibraryToolProvider.swift`：`com.vitemis.kuzio.library-tools.v1` contributor、capability-scoped definitions、标准 JSON Schema、65,536-byte strict JSON invocation decoder、控制面 dispatcher 与 stable snake_case result envelope；不实现完整工具总和、模型或 transport。
- `LibraryViewModel.swift`：`@MainActor @Observable` navigation/search/editor state，调用唯一 production `LibraryStore`；在 detached task 中扫描所选可见目录，生成逐文件只读 app-scoped bookmark，并负责 single/batch relink、stale locator replacement、security-scope 生命周期与 `NSWorkspace` 打开。
- `LibraryIdentifiers.swift`：`LibraryID`、`NodeID`、`ResourceID`、`ImportID`、`ObjectID` 与 `TransactionID` canonical lowercase UUID wrappers。
- `LibraryManifest.swift`：legacy schema v1、current schema v2、folder/document/resource-link node、external resource、可选 import-origin metadata、locator、trash 与 transaction/purge intent records。
- `LibraryPackagePaths.swift`：只由常量和 UUID 构造 managed path，并执行 containment/file-type/link 检查。
- `LibraryManifestValidator.swift`：资源上限、version、virtual hierarchy、node/resource shape、alias 引用、cycle/orphan/trash 与 payload/locator metadata/digest 验证。
- `LibraryStoreIO.swift`：bounded read、durable write、atomic replace、SHA-256 与 IO error mapping。
- `LibraryStore.swift`：create/open、v1→v2 transaction migration、recover、snapshot、refresh、coordinated document/locator read；读取可选携带 expected revision，供控制面保持 snapshot/content 一致。
- `LibraryStore+Mutations.swift`：create/update document、create resource link/alias、atomic recursive linked tree、single/batch locator replacement、rename/move/trash/restore/delete 与 expected revision contract。
- `LibraryStore+Transactions.swift`：document/locator staging、publish、previous manifest、purge completion 与 resource-aware coordinated garbage collection。
- `LibraryBootstrap.swift`：production Application Support 默认包；DEBUG-only preview package。

## 构建事实源与资源

- `Package.swift` 定义 `KuzioApp` executable 与 `KuzioAppTests`，并以 `.copy("Fonts")` 保留 font bundle 子目录。
- `project.yml` 是正式 App 工程事实源；源码排除 `Fonts` 后把它作为 folder resource 加入 resources build phase，并显式保留既有 Development Team，避免 XcodeGen 更新时破坏本机同身份签名合同。
- `Kuzio.xcodeproj/project.pbxproj` 由本机 XcodeGen 2.45.4 生成；已包含 typography、control metrics、AppKit icon provider、工具控制面/provider 与 `Fonts in Resources`。
- `Sources/KuzioApp/Fonts/JetBrainsMono-OFL.txt` 随 App 分发，字体 provenance/checksum 见 `docs/FONT_DEPENDENCY.md`。

## Runtime 数据布局

- production root：用户 Application Support / `Kuzio/Default.kuzio`。
- authoritative manifest：`manifest.json`。
- immutable object：`objects/<ID 前两位>/<ID>.payload`；同一 object store 保存内部文档正文与最多 1 MiB 的 opaque external locator，kind 只由 manifest reference 决定。
- recovery / transaction state：`.state/previous-manifest.json`、`.state/transactions/`、`.state/purge/`。
- title、breadcrumb、virtual folder 层级与外部真实路径不会参与 managed object path 构造；文件夹扫描只生成独立 virtual folders、逐文件 locator，以及用于显式重连的 `ImportID` / relative components，不保存外部 root path。

## 测试与生成物

- `LibraryStoreTests.swift` 当前有 38 个 async/filesystem 测试方法；2026-08-27 已重新运行并全部通过，其中 4 个直接覆盖强类型工具控制面，另 4 个覆盖工具目录/schema、完整 wire dispatcher、默认参数、结果 envelope 与错误/授权边界。
- `.build/`、`DerivedData/` 是本地生成物并被忽略，不得作为源码事实。
- Debug App 预期路径：`DerivedData/Build/Products/Debug/Kuzio.app`；必须在成功构建后才能视为当前产物。
- Release App 预期位于本轮指定 derived data 的 `Build/Products/Release/Kuzio.app`；本机正式使用副本固定为 `~/Applications/Kuzio.app`。两者都是仓库外生成物，不提交 Git。
- 当前安装副本为可组合工具 provider 源码对应的 `0.1`（build `1`）arm64/x86_64 universal app，使用本机同一 Developer ID Application 身份、hardened runtime 与 secure timestamp 签名；安装 executable 与全新 Release executable 完全一致。

## 当前不确定项

- 外部 `.kuzio` package 的 Open/Save panel、document type registration、导入/导出 UX：`UNKNOWN`。
- v1→v2 之外的未来 schema migration、同步、账号、网络与跨端平台：`UNKNOWN`。本机 Release 安装、同身份升级与 secure timestamp 已经确认；公证、对外发布和自动更新服务仍为 `UNKNOWN`。
- 文件/文件夹多选、递归 linked-tree creation、逐文件只读 security-scoped bookmark、single/batch relink、stale 更新与系统打开已经实现；源目录显式刷新/对账、HTTPS picker/open 与 File Provider 状态 UI 尚未实现。
- App Sandbox entitlement、默认库 container migration、公证与对外发布策略仍为 `UNKNOWN`；当前正式 target 保持未 sandbox。
- 2026-08-27 relink 版本的 30-test `swift test`、Xcode Debug/Release App build、签名/资源校验、安装路径更新、production 165-file batch relink、重启与外部链接打开均已通过；随后工具控制面版本的 `swift build`、34-test `swift test`、Xcode Debug/Release App build、同身份签名、安装路径更新与真实链接启动验收也已通过，production revision 保持 17。
- provider-neutral 工具控制面、可组合 provider contributor 与调用文档已经实现；具体模型 runtime、其他工具来源的总和聚合器、runtime adapter 与授权 UI 尚未选择，当前不得描述为 AI 已接入。
