# PROJECT_MAP

最近自查日期：2026-08-31

本文描述当前 macOS 26 SwiftUI App、虚拟层级资料库、外部资源链接数据层、SwiftPM 测试和 XcodeGen 工程结构。

## 目录结构

```text
Kuzio/
├── .gitignore
├── AGENTS.md
├── CLAUDE.md
├── GEMINI.md
├── Package.swift
├── Package.resolved
├── project.yml
├── Kuzio.xcodeproj/
├── Sources/KuzioApp/
│   ├── KuzioApp.swift
│   ├── KuzioCodexRuntimeIntegration.swift
│   ├── KuzioCodexLibraryTools.swift
│   ├── KuzioCoworkRuntimeProfile.swift
│   ├── KuzioCoworkConversationModel.swift
│   ├── KuzioCoworkConversationView.swift
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
│   │   ├── JetBrainsMono-Regular.ttf       # source-only, excluded
│   │   ├── JetBrainsMono-Medium.ttf        # source-only, excluded
│   │   ├── JetBrainsMono-SemiBold.ttf      # source-only, excluded
│   │   ├── JetBrainsMono-Bold.ttf          # source-only, excluded
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
│   ├── LibraryStoreTests.swift
│   └── KuzioCoworkRuntimeTests.swift
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
| Intatis host + Cowork UI products | `../../Intatis` 本地 SwiftPM products | macOS 26+ | `IntatisHostApplication` / `IntatisCodexRuntime` / `IntatisCoworkUI` public API | 七个直接产品：`IntatisCore` / `IntatisProtocol` / `IntatisProviders` / `IntatisConversation` / `IntatisCodexRuntime` / `IntatisCoworkUI` / `IntatisSharedUI`；Kuzio拥有真实session、events、approval与dynamic tools，presentation-only CoworkUI拥有完整右侧呈现 |

## 关键源码

### App 与前端

- `KuzioApp.swift`：唯一主 `WindowGroup`、进程级 `LibraryViewModel`、字体/runtime contract 启动校验、主窗口尺寸与 DEBUG appearance 参数；不再声明第二个 AI scene。
- `KuzioCodexRuntimeIntegration.swift`：在任何 dependency object 前只安装一次 `IntatisHostApplication.configure(name: "Kuzio")`，公开冻结的 application identity，并对 `CodexRuntimeHostContract` / `IntatisCoworkUIContract` public API major v1执行fail-closed校验。
- `KuzioCoworkRuntimeProfile.swift`：selected-node harness target、Intatis-owned canonical config discovery（候选由 `.intatis` identity 派生）、`ChatConfigurationImporter` / `ProviderRegistry` route resolution、memory-only literal/environment/file credential resolver、Kuzio host identity、stable Cowork session identity、owner-only workspace/runtime root 与 untrusted metadata `AGENTS.md`。
- `KuzioCodexLibraryTools.swift`：把 capability-filtered `LibraryToolProvider` definitions/JSON Schema/invocation/result 最薄转换为 `CodexRuntimeDynamicTools`；当前 Cowork 使用 `com.vitemis.kuzio.library-tools.cowork.v2` toolset identity，显式授予 read-structure/read-content/mutate-structure，并逐个注册完整 8 个最小工具，不做组织计划、批量操作、重试或调用改写。
- `KuzioCoworkConversationModel.swift`：仅承担 `CodexAppServerSession` startup/shutdown/send/interrupt、root/child public event→`CodeItem` / `CoworkAgentThreadSnapshot` 输入、`IntatisCoworkThreadSource`更新流、reviewed/read-write workspace presentation、approval/Goal action、secret-free模型option与下一轮route选择；不渲染或设计 Harness UI。
- `KuzioCoworkConversationView.swift`：右栏最薄 lifecycle host，直接挂载 `IntatisCoworkUI.IntatisCoworkContentView`，只把selected target、state/actions/thread source与composer/inspector bindings映射给依赖；没有Kuzio transcript、composer、模型菜单、permission dialog、Inspector、Markdown renderer、status rail或关闭叉号。
- `KuzioControlMetrics.swift`：Rokurics macOS 的 circle icon、sidebar row、folder/card icon、固定 grid tile 尺寸 token，以及拥有 36pt label interaction shape 的 `KuzioCircleIconButton` / menu control modifier。
- `SystemFileIconProvider.swift`：通过 `NSWorkspace.icon(for:)` 获取 Finder 原生 folder/file icon 的最薄 AppKit 接线。
- `LibraryRootView.swift`：系统 `NavigationSplitView`、轻量 destination sidebar，以及 detail 内左学习库 / 右 Cowork Harness 的原生 `HSplitView`；持有当前 optional target，并在空态与活动 pane 间切换。
- `LibraryBrowserView.swift`：root“资料库”/当前文件夹动态 32pt 页标题、history、breadcrumb、search、等尺寸 folder/resource-link grid、resource-link 文件名中间截断与完整标题 hover help、document list、context operations、把 AI conversation selected entry 回传根 split 的 action、Finder 原生 empty-folder state、右上角唯一 `+`，以及添加/重新链接使用的原生 `NSOpenPanel`。
- `LibraryReaderView.swift`：document header、metadata、Markdown 阅读、文本编辑/保存，以及“更多”菜单中回传 selected entry 的同一 AI conversation action。
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

- `Package.swift` 定义 `KuzioApp` executable 与 `KuzioAppTests`，通过 `.package(path: "../../Intatis")` 直接声明七个实际使用的 Intatis products；只 copy OFL，并 exclude 四个旧静态 TTF，正式字体由 `IntatisSharedUI` resource bundle拥有。
- `Package.resolved` 锁定 Intatis 当前 manifest 所带来的远程传递 package revision/version；本地 Intatis package 本身按合同直接消费唯一 checkout 的当前源码，不复制、不 vendoring，也不由 lockfile 伪装成远程版本。
- `project.yml` 是正式 App 工程事实源；当前 marketing version `0.5` / build `2`，声明 `../../Intatis` local package、相同七个 products、Kuzio OFL resource，并把 Intatis `.intatis/runtime-kit/0.66/CodexRuntime` 作为 sealed folder resource加入 App。
- `Kuzio.xcodeproj/project.pbxproj` 于 2026-08-30 由本机 XcodeGen 2.45.4 重新生成；Debug/Release为`0.5` / build `2`，继续包含全部 Cowork Host/Profile/Tools source、OFL、双架构 `CodexRuntime in Resources`、`XCLocalSwiftPackageReference "../../Intatis"` 与七个product dependencies；不包含旧四个静态 TTF resource build files。
- `Sources/KuzioApp/Fonts/JetBrainsMono-OFL.txt` 随 App 分发，字体 provenance/checksum 见 `docs/FONT_DEPENDENCY.md`。

## Runtime 数据布局

- production root：用户 Application Support / `Kuzio/Default.kuzio`。
- authoritative manifest：`manifest.json`。
- immutable object：`objects/<ID 前两位>/<ID>.payload`；同一 object store 保存内部文档正文与最多 1 MiB 的 opaque external locator，kind 只由 manifest reference 决定。
- recovery / transaction state：`.state/previous-manifest.json`、`.state/transactions/`、`.state/purge/`。
- title、breadcrumb、virtual folder 层级与外部真实路径不会参与 managed object path 构造；文件夹扫描只生成独立 virtual folders、逐文件 locator，以及用于显式重连的 `ImportID` / relative components，不保存外部 root path。
- Cowork session root：用户 Application Support / `Kuzio/CoworkSessions/cowork_<harness-request-uuid>/`；其 `workspace/AGENTS.md` 只保存 selected virtual identity/display context，`codex-runtime/` 由 Intatis 按 isolated `CODEX_HOME`/runtime record 合同拥有。它与 `Default.kuzio` 平行，不能成为第二份 library state。
- App runtime bundle：`Contents/Resources/CodexRuntime/{arm64,x86_64}/`；每架构含 signed `codex`、`runtime-manifest.json`、`SHA256SUMS.txt`、SPDX、LICENSES 与 license tree。

## 测试与生成物

- `LibraryStoreTests.swift` 有 38 个 async/filesystem 测试；`KuzioCoworkRuntimeTests.swift` 有 5 个 config/route/dynamic-tools/session-context/single-scene 测试，当前共 43 个且全部通过。
- `.build/`、`DerivedData/` 是本地生成物并被忽略，不得作为源码事实。
- Debug App 预期路径：`DerivedData/Build/Products/Debug/Kuzio.app`；必须在成功构建后才能视为当前产物。
- Release App 预期位于本轮指定 derived data 的 `Build/Products/Release/Kuzio.app`；本机正式使用副本固定为 `~/Applications/Kuzio.app`。两者都是仓库外生成物，不提交 Git。
- 当前安装副本是presentation-only Intatis Cowork UI + 完整8-tool minimal版本的`0.5`（build `2`）arm64/x86_64 universal app；主App与两个nested runtime使用与旧安装版相同的Developer ID Application、hardened runtime与secure timestamp。installed executable与fresh Release一致，两架构runtime manifest/SHA inventory、SharedUI variable fonts/OFL、production只读资源打开、Intatis模型菜单/composer ready与window-close shutdown均通过。切换模型后的远端turn、真实model-driven mutation callback与逐工具approval尚未验收。

## 当前不确定项

- 外部 `.kuzio` package 的 Open/Save panel、document type registration、导入/导出 UX：`UNKNOWN`。
- v1→v2 之外的未来 schema migration、同步、账号、网络与跨端平台：`UNKNOWN`。本机 Release 安装、同身份升级与 secure timestamp 已经确认；公证、对外发布和自动更新服务仍为 `UNKNOWN`。
- 文件/文件夹多选、递归 linked-tree creation、逐文件只读 security-scoped bookmark、single/batch relink、stale 更新与系统打开已经实现；源目录显式刷新/对账、HTTPS picker/open 与 File Provider 状态 UI 尚未实现。
- App Sandbox entitlement、默认库 container migration、公证与对外发布策略仍为 `UNKNOWN`；当前正式 target 保持未 sandbox。
- 2026-08-27 relink 版本的 30-test `swift test`、Xcode Debug/Release App build、签名/资源校验、安装路径更新、production 165-file batch relink、重启与外部链接打开均已通过；随后工具控制面版本的 `swift build`、34-test `swift test`、Xcode Debug/Release App build、同身份签名、安装路径更新与真实链接启动验收也已通过，production revision 保持 17。
- Intatis Cowork session、runtime bundle、完整8-tool minimal dynamic tools与presentation-only `IntatisCoworkContentView`已接入；模型菜单由依赖拥有，Kuzio只提供secret-free options与下一轮route action，同一session/workspace/runtime root和toolset不变。本轮Light真实窗口确认多provider/model菜单、标签切换、composer ready、无Kuzio叉号、target替换和process drain；此前安装版真实root turn返回过`READY`并显示reasoning/usage。bridge/provider单次mutation callback已由测试覆盖，切换模型后的远端turn、真实App Server model-driven tool callback、child delegation与逐工具approval round trip尚未触发，且当前无独立session history/list/reopen UI。`IntatisConversation` / `IntatisCoworkUI` / `IntatisSharedUI`是exact current-checkout public products，每次上游变化必须重新编译和窗口验收，不能假设source compatibility。
