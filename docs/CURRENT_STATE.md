# CURRENT_STATE

最近一次自查日期：2026-08-24

## 当前真实状态总览

- Kuzio 当前工作区实现的是 macOS 26 原生 SwiftUI 通用资料库，不是 Rokurics 学习业务的复制品。
- UI、文件系统、测试与 XcodeGen 工程均仍是未提交工作区改动；`main` 仍指向用户已有的初始提交 `v0.0`，本轮未 add、commit 或 push。
- 最新源码已经完成前端视觉重做与本地资料库实现。用户在 Xcode 的首次构建发现 `SystemFileIconProvider` 把 AppKit Swift 参数标签写成了 `icon(forContentType:)`；当前源码已修为 SDK 要求的 `icon(for:)`，但修正后尚未重新执行 `swift test` / `xcodebuild`，因此当前不能描述为“已构建通过”。
- 当前技术栈为 Swift 6、SwiftUI、Observation、Foundation、AppKit、Core Text、CryptoKit 与 Uniform Type Identifiers；没有第三方 Swift package runtime dependency。
- 唯一随 App 分发的第三方资源是官方 JetBrains Mono `v2.304` 四档静态 TTF，许可证为 SIL OFL 1.1。

## 当前前端

### App shell

- 入口：`Sources/KuzioApp/KuzioApp.swift`。
- 根结构：系统两列 `NavigationSplitView`；sidebar 宽度 min 210 / ideal 236 / max 280，窗口最小 1040×690。
- sidebar 只承担稳定产品目的地：`资料库` 与 `废纸篓`；任意深度目录不塞入 sidebar，而在 detail 浏览器中呈现。
- sidebar 顶部品牌名 `Kuzio` 使用 28pt JetBrains Mono semibold；单行品牌区采用 Intatis/Mopelium 的 18pt 水平、22pt 顶部、12pt 底部比例，全局拉丁文本统一使用同一字体族，中文通过 Apple 字体级联使用系统苹方。

### 浏览与阅读

- `LibraryBrowserPage` 使用固定 32pt 页标题、34pt 页面边距、1120pt 最大内容宽度、adaptive folder grid 与 document list。
- folder tile 使用 `NSWorkspace` 返回的 Finder 原生文件夹图标；没有自制 folder asset、手绘矢量或 `folder.fill` 替代。
- 后退、前进、新建文件夹、新建文档、阅读页返回/编辑/取消/更多、废纸篓恢复/删除均使用 Rokurics Mac 源码的 36pt control / 15pt SF Symbol；不再把移动端 44pt label 叠加到系统 glass button。
- 所有 glass surface 只调用 Apple 官方 `.buttonStyle(.glass)` 或 `.glassEffect(...)`；没有自绘 blur、highlight、refraction 或兼容 fallback。
- 当前没有品牌色、RGB/Hex token、渐变、胶囊、装饰阴影或自定义 root/sidebar 背景；window、sidebar、文字与分隔层级均跟随系统语义外观。
- 文档支持打开、Markdown `AttributedString` 阅读、文本选择、纯文本编辑与保存；不包含录音、转写、AI 总结或固定课程层级。

## 当前可移植文件系统

### 默认位置与包结构

- production 默认库位于用户 Application Support 下的 `Kuzio/Default.kuzio`。
- `Default.kuzio` 是可整体复制的自包含目录包；复制后重新打开可保持 library ID、node ID、层级、revision 与正文内容。
- 核心布局：

```text
Default.kuzio/
├── manifest.json
├── objects/<uuid-prefix>/<object-uuid>.payload
└── .state/
    ├── previous-manifest.json
    ├── transactions/<transaction-uuid>/...
    └── purge/<transaction-uuid>.json
```

### 模型与操作

- `manifest.json` 标识符为 `com.vitemis.kuzio.library`，layout/schema version 当前均为 1。
- hierarchy 的唯一事实源是 flat manifest 中 folder 的 ordered child ID；title 从不成为磁盘路径，层级深度没有 type/subject/chapter/topic 上限。
- node、payload object、library 与 transaction 均使用 canonical lowercase UUID；重命名和移动不会改变 node ID 或 payload identity。
- 已实现 create folder/document、update document、rename、move、trash、restore、permanent delete、refresh、explicit previous-manifest recovery 与 garbage collection。
- 废纸篓保存原 parent/index；恢复保持 subtree 与稳定 ID。原 parent 已删除时必须给出明确恢复目的地，不静默猜测。

### 一致性与安全

- `LibraryStore` 是 actor；所有 mutation 带 expected manifest revision，冲突明确返回 `revisionConflict`。
- writer 使用 `NSFileCoordinator`、transaction staging、immutable payload、atomic manifest replacement 与 previous manifest。
- document read、refresh、purge completion 与 garbage collection 都在 library root 协调区间内重载磁盘最新 manifest，避免陈旧窗口删除另一 writer 的新 payload。
- manifest validator 检查 format/version、canonical title/media type/UUID、node shape、唯一父级、cycle、orphan、trash overlap、资源上限、payload size 与路径类型。
- 管理路径拒绝 symbolic link、alias、payload/manifest hard link 和越界路径；正文读取验证 byte count 与 SHA-256。
- corruption 不触发 preview/mock/alternate backend。当前 manifest 损坏且 previous manifest 有效时返回 `recoveryRequired`，只有显式恢复 API 才发布 previous manifest。

## DEBUG 边界

- `-KuzioPreviewData` 只在 `#if DEBUG` 下创建独立临时 `.kuzio` 包并写入演示数据，用于窗口验收。
- 无参数 production 启动不会加载 preview fixture，也不会在真实库失败后降级到内存数据。
- `-KuzioAppearanceLight` / `-KuzioAppearanceDark` 只用于 DEBUG 外观验收；无参数启动始终跟随系统 appearance。

## 测试源码状态

- `Tests/KuzioAppTests/LibraryStoreTests.swift` 当前包含 18 个测试方法。
- 覆盖方向包括：复制可移植性、32 层任意深度、稳定 ID、cycle 防护、trash/restore/permanent delete、revision conflict、并发 writer、陈旧 store garbage collection、协调读取、manifest recovery、payload digest、symlink 防护、路径标题隔离与非法 mutation target。
- 最新测试源码尚未实际运行；结果必须等待明确授权后的 `swift test`。

## 当前风险与未完成项

- 最新工作区仍缺少真实 compiler/test result 与最新窗口截图；任何“通过”结论都必须等待构建和实际 UI 验收。
- 用户截图已证明修正前的首个 compiler blocker；该 blocker 已在源码中修复，后续 compiler diagnostics 仍需重新构建才能确认。
- 当前只提供默认 Application Support 库；Open/Save panel、用户选择外部 `.kuzio` 包、导入/导出与 document type 关联尚未确认，不得描述为已有能力。
- schema v1 当前没有旧版本迁移器；遇到未知 layout/schema 明确失败。
- 当前没有同步、账号、网络、跨设备协作、权限申请、签名、公证或发布配置结论。
- XCUITest、VoiceOver 全流程、大型 100k-node 压力和故障注入仍未覆盖。

## 工作区与文档冲突

- 用户已有的仓库路径修正文档改动已保留。
- 旧文档仍把数据链路写成 `LibraryCatalog.preview` 内存 fixture、字体写成系统字体、图标写成仅 SF Symbols；这些事实已被当前源码取代，本轮同步更新所有项目文档。
- 当前源码是判断实现事实的依据；构建是否成功仍属于未验证状态。
