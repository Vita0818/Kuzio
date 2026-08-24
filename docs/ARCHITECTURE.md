# ARCHITECTURE

最近自查日期：2026-08-24

## 总体架构

Kuzio 当前是 macOS 26 原生 SwiftUI 通用资料库。UI 参考 Rokurics 与 Intatis 的共同排版和桌面层级，但数据模型不继承 Rokurics 的固定学习分类、录音、转写或笔记业务。

```text
KuzioApp / WindowGroup
        |
        +--> KuzioTypography startup validation
        |
        v
LibraryRootView / NavigationSplitView
        |
        +--> native sidebar: Library / Trash
        |
        +--> LibraryBrowserPage
        |       +--> arbitrary-depth folder grid
        |       +--> document list
        |       +--> search / breadcrumb / history
        |
        +--> LibraryReaderView
        |       +--> read / edit / metadata / move / trash
        |
        +--> LibraryTrashView
                +--> restore / permanent delete

LibraryViewModel (@MainActor @Observable)
        |
        v
LibraryStore (actor)
        |
        +--> manifest.json
        +--> immutable UUID payload objects
        +--> transaction staging / previous manifest / purge intent
```

## UI 架构

### Scene 与 state ownership

- `KuzioApp` 创建唯一 window-scoped `LibraryViewModel`，启动时校验并注册 bundled fonts，再异步打开 production store。
- `LibraryRootView` 保有 split-view column visibility；selection、search、folder history、active document 与 operation error 由 `LibraryViewModel` 管理。
- create/rename/move sheet 只持有短生命周期 view-local draft state；文件系统 actor 是唯一持久化 truth owner。

### Desktop 结构

- 使用系统 `NavigationSplitView` 并让系统拥有 sidebar material；destination 使用三个参考项目共同的紧凑按钮栈，selected row 只调用 Apple 原生 rectangular glass，不重画 title bar 或 sidebar surface。
- sidebar 只显示稳定产品 destination，不递归投影 filesystem tree，避免深层库把导航栏变成不可维护 outline。
- browser detail 最大宽度 1120，水平 padding 34，顶部 30，folder grid minimum 142 / maximum 210。
- reader 最大正文宽度 780；文档 title、metadata 与正文共用一致左边界。

### 字体、图标与 controls

- JetBrains Mono `v2.304` 是拉丁/数字主字体；中文没有被替换或嵌入，继续由 Apple fallback cascade 解析为苹方。
- 单行品牌名为 28pt semibold；page title 32pt bold；card title 16pt semibold；body 14–15pt；metadata 11–13pt。
- Finder folder icon 通过 `NSWorkspace.icon(for: .folder)` 获取，再直接交给 SwiftUI `Image(nsImage:)`；没有 representable、asset 或第一方图形实现。
- 功能图标使用 SF Symbols。圆形操作 control 使用 Apple `.buttonStyle(.glass)` / `.buttonBorderShape(.circle)` 与 Rokurics macOS 的 36pt control / 15pt symbol；44pt / 18pt 是共享移动端指标，不用于 Kuzio Mac。
- folder/document surfaces 使用 Apple `.glassEffect`；没有自制 glass wrapper、shader、fallback、品牌色、gradient、capsule 或 decorative shadow。

## 文件系统模型

### Package layout

```text
<library>.kuzio/
├── manifest.json
├── objects/
│   └── <object-id-prefix>/
│       └── <object-id>.payload
└── .state/
    ├── previous-manifest.json
    ├── transactions/
    │   └── <transaction-id>/
    │       ├── intent.json
    │       ├── manifest.json
    │       └── objects/...
    └── purge/
        └── <transaction-id>.json
```

- 包是 self-contained；payload reference 不包含绝对路径或机器身份。
- 复制整个目录即可迁移 library；测试以 copy/reopen 验证 library/node ID、revision、层级与正文不变。
- 当前默认 package 由 `LibraryBootstrap` 放在用户 Application Support / `Kuzio/Default.kuzio`。

### Manifest schema v1

| 类型 | 作用 | 稳定性约束 |
| --- | --- | --- |
| `LibraryID` | package identity | canonical lowercase UUID，复制 package 保持不变 |
| `NodeID` | folder/document identity | rename/move/trash/restore 保持不变 |
| `ObjectID` | immutable payload identity | 正文 update 创建新 object，不覆写旧 bytes |
| `TransactionID` | commit/purge identity | canonical lowercase UUID |
| `StoredNodeRecord` | flat node record | kind 决定且只允许 folder 或 document shape |
| `StoredFolderRecord.children` | ordered hierarchy edge | hierarchy 唯一事实源；任意深度 |
| `StoredPayloadReference` | object metadata | media type、schema、byte count、SHA-256 |
| `StoredTrashRecord` | soft-delete root | original parent/index 与 trash timestamp |

title 只存于 manifest display metadata。即使 title 包含 `/`、`..`、反斜线或组合字符，也不会进入 managed path；写入前只做 trim、Unicode NFC、长度和 control-character validation。

## Mutation 与 transaction

每次 mutation 的顺序为：

1. 调用方提供 expected manifest revision；actor 先验证内存 graph 与 active/trash ownership。
2. 创建 candidate manifest，revision +1，并保持 timestamp 单调。
3. 在唯一 transaction UUID 目录 durable-write intent、candidate manifest 与新 immutable payload。
4. 进入 library root 的 `NSFileCoordinator` write claim，重新读取并完整验证磁盘 manifest。
5. 比较 library ID 与 base revision；任何变化都明确返回 conflict，不合并、不覆盖。
6. 原子写 previous manifest，promote 新 payload，再原子发布 candidate manifest。
7. 验证 published revision/transaction ID 与所有 payload metadata。
8. destructive delete 先把 previous manifest 更新为不再引用已删除 object 的 published manifest，再进行协调垃圾回收。

如果 manifest 已发布而 transaction directory 或旧 object cleanup 失败，commit receipt 标记 `cleanupPending`；不会回滚已经发布的用户操作，也不会用另一套 store 冒充成功。

## Concurrency 与 garbage collection

- 所有 writer 都用 manifest revision 做 optimistic concurrency control，并在 write claim 内重新读取磁盘 truth。
- refresh、document read、purge completion 与 garbage collection 都以 library root 为协调范围。
- garbage collection 不信任 actor 的陈旧 manifest；它在 write claim 内读取最新 current manifest，并把有效 previous manifest 的 object references 合并后才删除 unreferenced payload。
- 这个约束防止旧窗口或第二个 `LibraryStore` actor 把较新 writer 刚发布的 object 当作垃圾删除。
- document read 在 read claim 内同时解析最新 manifest、定位 payload、验证 file type/size/digest 并读取 bytes，避免 manifest/payload 跨 revision 混读。

## Recovery 与 fail-closed

- open 首先验证 current manifest 与 referenced payload file metadata。
- current 无效而 previous manifest 完整时只返回 `recoveryRequired`；不会自动覆盖 current。
- `recoverPreviousManifest` 是显式 API；验证 previous 后才原子发布并重新 open。
- unsupported format/layout/schema、cycle、orphan、multiple parent、trash overlap、missing payload、symlink/alias/hard link、digest mismatch 都明确失败。
- DEBUG seed 不参与 production error path；没有 preview backend、in-memory fallback、legacy store 或 parallel implementation。

## 搜索与 presentation projection

- `LibrarySnapshot` 把 validated flat manifest 投影成 `LibraryEntry` dictionary、parent map、ordered children 与 trash roots。
- breadcrumb/path 由 stable parent relationship 计算；folder history 保存 `NodeID`，不保存 title/path string。
- search 只遍历 active root subtree，并按 display title 匹配；trash subtree 不混入普通结果。
- 当前搜索不索引正文；没有宣称全文检索能力。

## 外部依赖与禁止兜底

- production runtime 没有第三方 Swift package。
- bundled JetBrains Mono 是 exact external font dependency；版本、来源、checksum、OFL 与 fail-closed 行为见 `docs/FONT_DEPENDENCY.md`。
- AppKit/Core Text/CryptoKit/SwiftUI/Foundation 均通过 Apple 官方 API 直接使用；本地代码仅承担资源注册、类型、生命周期和 package 接线。
- exact dependency 或 schema 条件不成立时必须明确失败；不得增加 system-font fallback、替代字体、第二个 store、adapter/shim、mock/cache backend 或 shadow implementation。

## 当前架构边界

- Open/Save panel、外部 package bookmark、document type registration、schema migration、sync、账号、网络和多平台尚未确认。
- App sandbox、签名、公证和发布策略尚未确认。
- 当前源码结构已为未来外部 package 选择保留 `LibraryStore.create(at:)` / `open(at:)` URL 边界，但不等于相关 UX 已实现。
