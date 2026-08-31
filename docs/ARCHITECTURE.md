# ARCHITECTURE

最近自查日期：2026-08-31

## 总体架构

Kuzio 当前是 macOS 26 原生 SwiftUI 虚拟层级资料库。UI 参考 Rokurics 与 Intatis 的共同排版和桌面层级，但数据模型不继承固定学习分类；用户已确认库内 hierarchy 与本机/云端真实结构解耦，外部目标只通过 resource link 被引用。

```text
KuzioApp / single WindowGroup
        |
        +--> IntatisHostApplication.configure(name: "Kuzio")
        +--> IntatisTypography startup validation
        |
        +--> KuzioCodexRuntimeIntegration
        |       +--> IntatisCodexRuntime public host API v1 precondition
        |       +--> exact shared products + bundled runtime identity
        |
        v
LibraryRootView / NavigationSplitView
        |
        +--> native sidebar: Library / Trash
        |
        +--> detail / native HSplitView
                |
                +--> left: learning library
                |       +--> LibraryBrowserPage
                |       +--> LibraryReaderView
                |       +--> LibraryTrashView
                |
                +--> right: Cowork Harness
                        +--> empty placeholder before explicit activation
                        +--> KuzioCoworkHarnessHost
                                +--> IntatisCoworkUI.IntatisCoworkContentView

LibraryViewModel (@MainActor @Observable)
        |
        +--> read-only app-scoped bookmark lifecycle
        +--> single / import-batch relink
        +--> NSWorkspace open original file
        |
        v
LibraryStore (actor)
        |
        +--> schema v2 manifest.json
        |       +--> virtual folder/document/resource-link nodes
        |       +--> external ResourceID records
        +--> immutable UUID document/locator objects
        +--> transaction staging / previous manifest / purge intent

selected LibraryEntry / explicit AI action
        |
        v
KuzioCoworkConversationTarget / LibraryRootView.coworkTarget
        |
        v
KuzioCoworkHarnessHost / dependency IntatisCoworkContentView
        |
        +--> KuzioCoworkHarnessHostModel
        |       +--> lifecycle + public presentation inputs only
        |       +--> no transcript/composer/permission/renderer UI
        |
        v
KuzioCoworkRuntimeProfile
        +--> Intatis config -> ChatConfigurationImporter
        +--> ProviderRegistry.responsesRuntimeRoute()
        +--> memory-only credential resolution
        +--> owner-only workspace + runtime root
        +--> CodexRuntimeConfiguration(mode: .cowork)
        |
        v
CodexAppServerSession / bundled exact runtime
        +--> streamed root + child events
        +--> approvals / interrupt / usage / shutdown
        |
        v
KuzioCodexLibraryTools / CodexRuntimeDynamicTools
        |
        | read_structure + read_content + mutate_structure
        | 8 independent minimal operations
        v
LibraryToolProvider
        +--> capability-scoped definitions
        +--> JSON Schema / strict JSON invocation
        +--> stable success / failure envelope
        |
        v
LibraryToolControlPlane (actor)
        +--> explicit capability check
        +--> typed call / output / stable failure
        +--> UTF-8 content chunk boundary
        |
        v
same LibraryStore actor
```

## UI 架构

### Scene 与 state ownership

- `KuzioApp` 只创建一个主 `WindowGroup` 与唯一 window-scoped `LibraryViewModel`。初始化顺序固定为先安装一次 `IntatisHostApplication.configure(name: "Kuzio")`，再校验 runtime public API、注册 IntatisSharedUI 字体，最后异步打开 production store；任何 dependency object不得早于 host identity。
- `LibraryRootView` 保有 sidebar column visibility 与 optional `coworkTarget`。每次 item action 生成唯一 harness request UUID；`KuzioCoworkHarnessHostModel` 是活动右栏的 runtime lifecycle/public presentation-input owner，替换 target 或关闭主窗口时显式 shutdown 对应 App Server。实际header、连续thread、模型菜单、composer、permission card、Inspector、rich renderer、scroll/status presentation全部由presentation-only `IntatisCoworkUI.IntatisCoworkContentView`拥有；用户明确不增加Kuzio关闭叉号。
- selection、search、folder history、active document 与 operation error 由 `LibraryViewModel` 管理；Cowork target 不进入 library manifest，也不复制 library state。
- create/rename/move sheet 与 file/folder `NSOpenPanel` 只持有短生命周期 view-local state；目录扫描在 detached task 中生成 flat linked-tree draft，文件系统 actor 是唯一持久化 truth owner。

### Desktop 结构

- 使用系统 `NavigationSplitView` 并让系统拥有 sidebar material；destination button 采用 Rokurics Mac 的 6pt 行间距、13pt SF Symbol / 20pt 图标槽、8pt 图文间距、12×10pt 内边距与 15pt selected glass 圆角，selected row 只调用 Apple 原生 rectangular glass，不重画 title bar 或 sidebar surface。
- detail 使用原生 `HSplitView`：左侧学习库 min 480 / ideal 720，右侧 Cowork Harness min 440 / ideal 620。未显式选择条目时右栏只显示系统 `ContentUnavailableView`，不创建会话；主窗口最小 1180×690、默认 1520×820。
- sidebar 只显示稳定产品 destination，不递归投影 filesystem tree，避免深层库把导航栏变成不可维护 outline。
- browser detail 最大宽度 1120，水平 padding 34，顶部 30；32pt 大标题直接投影当前 virtual folder title，root 仍为“资料库”，breadcrumb 保留完整祖先路径。folder grid minimum 142 / maximum 210；每个 tile 固定 152pt 高，标题使用 34pt 两行槽，detail 使用 13pt 槽，因此列宽仍可随窗口自适应，但同一布局内的 glass rectangle 不随名称长度或 detail 有无变化。
- reader 最大正文宽度 780；文档 title、metadata 与正文共用一致左边界。

### 字体、图标与 controls

- JetBrains Mono `v2.304` 是拉丁/数字主字体；中文没有被替换或嵌入，继续由 Apple fallback cascade 解析为苹方。
- 单行品牌名为 28pt semibold；page title 32pt bold；card title 16pt semibold；body 14–15pt；metadata 11–13pt。
- Finder folder/file icon 通过 `NSWorkspace.icon(for:)` 获取，再直接交给 SwiftUI `Image(nsImage:)`；folder grid 与 empty-folder state 共用这条原生图标链路，没有 representable、asset 或第一方图形实现。
- 功能图标使用 SF Symbols。`KuzioControlMetrics` 是 macOS button/icon metric 的单一事实源；`KuzioCircleIconLabel` 自身拥有精确 36×36pt frame 与 circle interaction content shape，使 `Button` / `Menu` 的真实命中范围覆盖完整可见圆面。`KuzioCircleIconButton` 与 `kuzioCircleIconControl` 再集中应用 Apple 官方 interactive `.glassEffect(..., in: .circle)`、15pt semibold monochrome symbol、8pt action-group spacing 与 Rokurics 的 0.46 disabled opacity。menu trigger 隐藏系统 indicator，避免额外箭头扩大 footprint。44pt / 18pt 是共享移动端指标，不用于 Kuzio Mac。
- browser toolbar 只投影一个可见 `+` menu control；其 primary action 打开文件/文件夹多选 `NSOpenPanel`，folder/document creation 留在同一个 menu 内，不投影为额外加号按钮。
- 重新链接只存在于既有 item context menu，菜单项名称为“重新链接”，随后直接打开原生 file-only 或 folder-only `NSOpenPanel`；不增加状态文案、说明页、徽标、提示卡片或额外确认弹窗。
- folder 与 file resource-link 共用 58×50pt Finder icon / 52pt icon 槽、34pt title 槽、13pt detail 槽和 152pt 固定总高度的 grid tile；resource-link tile 只显示文件名，使用中间截断保留首尾信息，并在原生 hover help 中提供完整标题，空 detail 槽不可见。folder title 继续使用默认尾部截断；document card 保留 21pt semibold / 42pt leading symbol 的长条样式。
- folder/document surfaces 使用 Apple `.glassEffect`；没有自制 glass wrapper、shader、fallback、品牌色、gradient、capsule 或 decorative shadow。
- AI conversation 是同一主窗口右侧直接挂载的 dependency-owned `IntatisCoworkContentView`。Kuzio只传入public state/actions/thread source及composer/inspector bindings；header、continuous transcript、provider/model selector、composer Send/Stop、permission card、Agents/Goal/Tasks inspector、Markdown/rich rendering、scroll coordinator与status rail均不在Kuzio实现。没有第二个scene、Kuzio chat UI、自制关闭动作或presentation fallback。

## 共享 Codex Runtime 依赖边界

- SwiftPM 和 XcodeGen 都只通过相对路径 `../../Intatis` 引用唯一 `/Users/vita/Vitemis/Intatis` checkout；Kuzio 不复制 `Packages/IntatisCodexRuntime`，也不维护 fork、snapshot 或第二套 runtime 源码。
- App target直接声明`IntatisCore`、`IntatisProtocol`、`IntatisProviders`、`IntatisConversation`、`IntatisCodexRuntime`、presentation-only `IntatisCoworkUI`与`IntatisSharedUI`七个产品。`CodexRuntimeHostContract`和`IntatisCoworkUIContract`都锁定public API major v1；CoworkUI/Conversation/SharedUI仍是exact current-checkout public products，上游变化必须重新编译/验收，不得复制源码或维护兼容facade。
- `KuzioCodexRuntimeIntegration` 在进程入口安装并冻结 `IntatisHostApplicationIdentity(name: "Kuzio")`，然后执行 `CodexRuntimeHostContract.publicAPIMajorVersion == 1` fail-closed precondition；每个 `CodexRuntimeConfiguration` 显式保存同一 identity，使 runtime config、environment、diagnostic、toolset/policy 和 model-facing host name不再默认为 Intatis。
- 用户确认推理设置仍由依赖内核的 Intatis canonical config拥有。`KuzioCoworkRuntimeProfile` 通过 `IntatisHostApplicationIdentity.intatis` 派生 `INTATIS_CONFIG`、`.config/intatis`、Intatis Application Support 和文件名 candidates，只读选择一个 exact document；它使用 `ChatConfigurationImporter` 解析 provider/model/options，并由 `ProviderRegistry.responsesRuntimeRoute()` 构造精确 Responses route。Kuzio 不创建 `KUZIO_CONFIG`、设置页或 config 副本，也不写/迁移 Intatis config。literal/environment/file credential reference只在 host memory解析；缺失/unsafe/unsupported明确失败。
- 每个 harness activation request 映射到稳定 `cowork_<request-uuid>`；Application Support / `Kuzio/CoworkSessions/<id>` 下的 workspace/runtime root owner-only 且与 library package 分离。workspace `AGENTS.md` 把 selected title/path 标为 untrusted data，只保存 virtual `NodeID`/kind/path，不保存 locator/raw target path/provider route/credential。
- `CodexRuntimeConfiguration` 固定 `.cowork`、Kuzio host identity、automatic reviewer、selected route reasoning、完整 8-tool dynamic tools 与 `pauseActiveGoalBeforeResume: true`。App Server 继续拥有 agent loop、native collaboration、tool choice、approval 和 rollout；关闭 pane、替换 target 或关闭主窗口都会调用 `shutdown()` 并等待 child process退出。当前注册本身不声明 business-tool approval 已接线，逐工具 approval 仍须独立验证。
- `KuzioCodexLibraryTools` 只做 `LibraryToolInputSchema`↔`JSONValue`、App Server call↔`LibraryToolInvocation`、provider envelope↔dynamic result 的最薄转换。当前 authorization 显式包含 `read_structure` / `read_content` / `mutate_structure`，因此 advertised surface 按 provider 固定顺序包含 8 个工具。每个工具只代表一个最小操作；Agent loop 负责编排，adapter 不得增加 organize/apply-plan/batch 工具，也不得合并、重试或改写调用。失败不得转旧 loop、MCP translator、shell/Python 或另一 provider。
- 完整 Cowork specs 使用 `com.vitemis.kuzio.library-tools.cowork.v2` toolset identity，与旧 3-tool read-only registration 明确不同；Intatis runtime 继续通过官方 persisted dynamic-toolset comparison 拒绝不兼容 resume，Kuzio 不迁移或改写旧 thread。
- Intatis 本地 path dependency 按合同消费 checkout 当前源码；`Package.resolved` 只锁定该 manifest 的远程传递依赖。Intatis 源码变化会在 Kuzio 下一次构建时生效，已构建 App 不会热替换。
- Xcode App resource 直接包含 Intatis runtime kit 的 arm64/x86_64 `codex-cli 0.145.0-intatis.4`、matching derivation、manifest/SHA/SBOM/licenses。Release 先分别签两个 nested executables，刷新 integrity metadata，再签 outer App；两个架构独立验证。

## 工具控制面

- `LibraryToolControlPlane` 仍是 provider-neutral 的应用能力入口，不是 AI runtime。Intatis Cowork 只通过 `KuzioCodexLibraryTools` 调用它；控制面自身仍不包含 prompt、聊天 UI、MCP server、network route 或 agent loop。
- `LibraryToolProvider` 是控制面之上的可组合工具 contributor。它以稳定 provider identity 发布当前 capability 实例可见的名称、description、JSON Schema，并把有界 JSON object 严格解码成 `LibraryToolCall`；它不代表未来模型的完整工具集合，runtime 可把这 8 个工具与其他独立工具来源合并。
- provider schema 全部禁止 additional properties；调用参数最多 65,536 bytes。未知 name/key、缺失或错误类型、非 canonical UUID 与负 index 在 Store 前返回稳定 `invalid_arguments`。未授权工具既不出现在该实例的 definitions 中，直接调用也在参数解码前返回 `permission_denied`。
- provider 结果编码为 `{ok, tool, result}` 或 `{ok, tool, error}`，字段使用稳定 snake_case；node/content/mutation 中合同要求存在但没有值的字段显式编码为 JSON `null`。provider 不做自动重试、冲突合并或调用改写。
- 控制面只接收 `LibraryToolCall`，并按实例创建时授予的 `read_structure`、`read_content`、`mutate_structure` capability 在进入 Store 前 fail closed。
- 读取结构使用协调 refresh 后的 `LibrarySnapshot`，只返回 library revision、`NodeID`、virtual parent、kind、title 与必要 resource/document metadata；不返回真实路径、locator bytes 或 manifest object key。
- 内容读取以 document/resource-link `NodeID` 为入口。内部 document 通过 Store 的 payload integrity read；外部 file 先通过 Store 读取并校验 locator，再以 `.withSecurityScope` / `.withoutUI` 解析、协调读取并平衡 security-scope。当前只输出有界 UTF-8 text chunk，不解析 binary/directory/HTTPS，也不写回 stale locator。
- create-folder、rename、move、trash 与 restore 直接调用现有 Store mutation；每次调用必须携带 expected manifest revision，结果返回 transaction receipt。工具层不合并冲突、不自动重试，也不另存 command state。
- 工具数量不是优化目标。一个独立业务动作对应一个工具；不得为了减少 specs 数量或表面简洁，把 create/rename/move/trash/restore 合并为 organize、apply-plan、batch-mutation 或其他复合接口。跨工具的顺序、观察和下一步选择只属于 Agent loop。
- 工具层刻意不提供 permanent-delete、external-target write、arbitrary-path read、relink 或 source-refresh call。后续能力必须单独确认权限和产品行为后再扩展。
- 精确 wire name、参数、schema、输出 envelope 和错误码见 `docs/TOOL_CALLING.md`。Cowork adapter 已按该边界逐个接入完整 8-tool surface；不能把 runtime/provider 类型下沉到 Store/schema，也不能通过 host adapter重新解释、组合或替代工具语义。

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

- 包内 virtual hierarchy 与内部 document payload 是 self-contained；外部资源目标不被复制，只有 `ResourceID` 与 opaque locator object 随包保存。manifest 不包含绝对外部路径。
- 复制整个目录可保持 library/node/resource ID、virtual 层级与内部正文；外部 locator 在另一环境不可解析时必须显式 relink，不允许缓存或同名文件 fallback。
- 当前默认 package 由 `LibraryBootstrap` 放在用户 Application Support / `Kuzio/Default.kuzio`。

### Manifest schema v2

| 类型 | 作用 | 稳定性约束 |
| --- | --- | --- |
| `LibraryID` | package identity | canonical lowercase UUID，复制 package 保持不变 |
| `NodeID` | virtual folder/document/resource-link placement | rename/move/trash/restore 保持不变；只表达库内位置 |
| `ResourceID` | external resource identity | 多个 resource-link node 可共享；relink 保持不变 |
| `ImportID` | one folder-import provenance identity | 只关联显式 batch relink；virtual rename/move 不改变，不成为 hierarchy truth |
| `ObjectID` | immutable document/locator object identity | 正文 update 或 locator replace 创建新 object，不覆写旧 bytes |
| `TransactionID` | commit/purge identity | canonical lowercase UUID |
| `StoredNodeRecord` | flat virtual node record | kind 决定且只允许 folder、document 或 resource-link shape |
| `StoredFolderRecord.children` | ordered hierarchy edge | hierarchy 唯一事实源；任意深度 |
| `StoredPayloadReference` | object metadata | media type、schema、byte count、SHA-256 |
| `StoredResourceLinkRecord` | placement → target edge | 只保存 `ResourceID`，不保存 path/bookmark bytes |
| `StoredExternalResourceRecord` | target metadata | file/directory/HTTPS kind、read-only policy、locator reference、last-known hints |
| `StoredExternalResourceOrigin` | optional relink provenance | `ImportID` + relative path components；不保存 root path，不驱动 virtual tree |
| `StoredLocatorReference` | opaque access descriptor | locator schema、最多 1 MiB、byte count、SHA-256；bytes 存在 object store |
| `StoredTrashRecord` | soft-delete root | original parent/index 与 trash timestamp |

title 只存于 manifest display metadata。即使 title 包含 `/`、`..`、反斜线或组合字符，也不会进入 managed path；写入前只做 trim、Unicode NFC、长度和 control-character validation。

schema v1 是唯一已知旧版本。open 会先完整验证 v1，再把同一组 library/node/object identity 投影为 v2 candidate，通过现有 revision、transaction staging、previous manifest 与 atomic publish 合同迁移；未知 schema 继续明确失败。

### Virtual tree 与 external resource

- folder `children` 是 Kuzio hierarchy 唯一事实源。选择真实文件夹时，只在确认瞬间递归扫描可见内容：目录变成普通 virtual folder，文件变成 resource-link；之后真实目录不会自动贡献、重排或删除 virtual children。
- linked-tree draft 使用 parent draft index 表达任意深度和顺序；store 在同一 candidate manifest 中生成全部 `NodeID`、`ResourceID` 与 locator object，并用一次 transaction 原子发布，失败不留下部分树。
- rename/move/trash/restore 只改变 `NodeID` placement；不会改变外部目标。
- permanent delete 移除 subtree 后重新计算仍被 node 引用的 `ResourceID`。只有最后一个 alias 消失时才移除 resource record 与 locator object；任何数据层删除路径都不会调用外部 target URL。
- replace locator 创建新 immutable locator object，同时保持 `ResourceID` 与所有 alias `NodeID`；旧 locator 受 current/previous reference 保护后再由 GC 清理。
- file/directory locator 在 store 中仍只作为 opaque bytes 存储，HTTPS locator 必须是 credential-free `https` URL。当前 UI 直接使用 Apple Foundation 为单文件或目录内每个文件生成只读、app-scoped security-scoped bookmark；bookmark bytes 只进入 immutable locator object，不进入 manifest。
- 打开 file link 时，ViewModel 通过 `.withSecurityScope` / `.withoutUI` 解析 bookmark，检查目标可达，平衡 `startAccessingSecurityScopedResource` 与 `stopAccessingSecurityScopedResource`。若 bookmark stale，则在访问范围内重建只读 bookmark，并经 `replaceExternalResourceLocator` 保持 `ResourceID` 与所有 `NodeID` identity 后再打开。
- 文件夹导入时，同一个 root 下的文件获得同一 `ImportID` 与各自 relative components。它们只用于用户显式选择新 root 后定位同一批目标；absolute root URL 不进 manifest，真实目录不会自动新增、删除、重排或改写 virtual nodes。
- 单文件重连调用现有 immutable locator replacement，并让该资源脱离原 import batch；所有 alias 继续共享同一 `ResourceID`。文件夹重连先解析该 `ImportID` 的全量资源、验证每个相对目标，再用一次 transaction 替换全部 locator；任何缺失或类型错误都不产生部分更新。
- batch 关系存于 resource metadata，不依赖当前 virtual parent/title。因此 virtual folder/resource-link 后续 rename 或 move 后，重新链接仍只更新原 batch 的资源，不重建树、不生成重复 node。

## Mutation 与 transaction

每次 mutation 的顺序为：

1. 调用方提供 expected manifest revision；actor 先验证内存 graph 与 active/trash ownership。
2. 创建 candidate manifest，revision +1，并保持 timestamp 单调。
3. 在唯一 transaction UUID 目录 durable-write intent、candidate manifest 与新 immutable document/locator objects。
4. 进入 library root 的 `NSFileCoordinator` write claim，重新读取并完整验证磁盘 manifest。
5. 比较 library ID 与 base revision；任何变化都明确返回 conflict，不合并、不覆盖。
6. 原子写 previous manifest，promote 新 payload，再原子发布 candidate manifest。
7. 验证 published revision/transaction ID 与所有 payload metadata。
8. destructive delete 先把 previous manifest 更新为不再引用已删除 document/locator object 的 published manifest，再进行协调垃圾回收；外部 target 不属于 purge 范围。

如果 manifest 已发布而 transaction directory 或旧 object cleanup 失败，commit receipt 标记 `cleanupPending`；不会回滚已经发布的用户操作，也不会用另一套 store 冒充成功。

## Concurrency 与 garbage collection

- 所有 writer 都用 manifest revision 做 optimistic concurrency control，并在 write claim 内重新读取磁盘 truth。
- refresh、document read、purge completion 与 garbage collection 都以 library root 为协调范围。
- garbage collection 不信任 actor 的陈旧 manifest；它在 write claim 内读取最新 current manifest，并把有效 v1/v2 previous manifest 的 document 与 locator object references 合并后才删除 unreferenced payload。
- 这个约束防止旧窗口或第二个 `LibraryStore` actor 把较新 writer 刚发布的正文或 locator 当作垃圾删除。
- document 与 external-resource read 都在 read claim 内解析最新 v2 manifest、定位 object、验证 file type/size/digest 并读取 bytes，避免 manifest/object 跨 revision 混读。

## Recovery 与 fail-closed

- open 首先验证 current manifest 与 referenced payload file metadata。
- current 无效而 previous manifest 完整时只返回 `recoveryRequired`；不会自动覆盖 current。
- `recoverPreviousManifest` 是显式 API；验证 previous 后才原子发布并重新 open。
- unsupported format/layout/schema、invalid v1 migration、node/resource orphan、cycle、multiple parent、trash overlap、missing document/locator object、symlink/alias/hard link、locator digest mismatch 都明确失败。
- DEBUG seed 不参与 production error path；没有 preview backend、in-memory fallback、legacy store 或 parallel implementation。

## 搜索与 presentation projection

- `LibrarySnapshot` 把 validated flat manifest 投影成 folder/document/resource-link `LibraryEntry` dictionary、parent map、ordered children、external resource hints 与 trash roots；locator bytes 不进入 UI snapshot。
- breadcrumb/path 由 stable parent relationship 计算；folder history 保存 `NodeID`，不保存 title/path string。
- search 只遍历 active root subtree，并按 display title 匹配；trash subtree 不混入普通结果。
- 当前搜索不索引正文；没有宣称全文检索能力。

## 外部依赖与禁止兜底

- exact 共享内核依赖是唯一 Intatis checkout 的 `IntatisCodexRuntime` v1 public host surface；Kuzio 通过本地 SwiftPM path 直接编译同一源码，并复用 Intatis 已审查的 package graph。Kuzio 不单独复制、升级、替换或重写其 runtime 能力。
- 消费项目的 `Package.resolved` 锁定 Intatis manifest 引入的远程传递 dependencies；这些版本属于共享 package graph，不是 Kuzio 选择的并行 provider/runtime。exact dependency 无法解析或编译时必须明确失败。
- JetBrains Mono 只由 exact `IntatisSharedUI` resource bundle 分发/注册；Kuzio直接调用 `IntatisTypography`，旧四档静态 TTF 从 build/resource graph排除，只额外分发 OFL。版本、来源、checksum与 fail-closed 行为见 `docs/FONT_DEPENDENCY.md`。
- AppKit/Core Text/CryptoKit/SwiftUI/Foundation/Uniform Type Identifiers 均通过 Apple 官方 API 直接使用；本地代码仅承担资源注册、类型、权限生命周期和 package 接线。文件选择直接调用 `NSOpenPanel`，外部打开直接调用 `NSWorkspace`，没有 path/cache/provider adapter。
- exact dependency 或 schema 条件不成立时必须明确失败；不得增加 system-font fallback、替代字体、第二个 store、adapter/shim、mock/cache backend 或 shadow implementation。

## 当前架构边界

- Intatis Cowork runtime activation、Kuzio host identity、Intatis-owned route resolution、memory-only credential handoff、独立session roots、双架构sealed runtime、完整8-tool minimal dynamic-tools bridge和presentation-only `IntatisCoworkContentView`已实现；当前配置中可解析provider/model作为secret-free options进入依赖菜单，选择只在下一次空闲`@main`发送前用同一session root和同一toolset重建route。此前真实root turn已流式返回`READY`；本轮Light Debug已验证完整Intatis右侧、模型菜单、未发送composer ready、无自制叉号、target替换与process drain。真实model-driven App Server tool callback、切换模型后的远端turn、child delegation与逐工具approval round trip仍未线上验收。
- 当前没有独立的 Cowork history/session browser；右栏 target 在当前主窗口生命周期内持有 stable request/session identity，用户再次从 item action 激活则创建新的 request/session。virtual create-folder/rename/move/trash/restore 已注册；permanent delete、document content mutation、binary/PDF parser、directory/HTTPS content、relink 与 external-target write 未授权且不广告。
- Open/Save panel、外部 package bookmark、document type registration、v1→v2 之外的未来 schema migration、sync、账号、网络和多平台尚未确认。
- 当前 v0.5 / build 2 本机安装链路为“全新 universal Release App build → 两架构 nested Codex 分别使用同一 Developer ID Application 身份、hardened runtime 与 secure timestamp 签名 → 刷新 runtime manifest/SHA inventory → 签 outer App → `~/Applications/Kuzio.app` → 原 production `Default.kuzio`”。安装副本不引入第二个backend/store，也不复制或迁移资料库；本轮production manifest在启动、真实外部资源打开、Cowork模型菜单/composer ready与window-close shutdown前后保持同一revision/SHA。
- app-scoped security-scoped bookmark 与签名身份绑定；后续安装升级必须保持同一签名身份。ad-hoc Debug 产物不得作为安装版，签名身份不可用时也不得用 raw path、缓存或复制目标兜底。
- 本机安装、同身份升级与 secure timestamp 已经确认；App Sandbox、公证和对外发布策略尚未确认。当前正式 target 未启用 App Sandbox，因此尚未决定默认库迁入 app container 的兼容策略。
- 当前源码结构已为未来外部 package 选择保留 `LibraryStore.create(at:)` / `open(at:)` URL 边界，但不等于相关 UX 已实现。
- schema v2 数据层已经支持 file/directory/HTTPS resource record、alias、single/batch relink、read-only policy 与 atomic recursive linked-tree creation；文件/文件夹多选、逐文件 app-scoped read-only bookmark、原文件打开与用户触发的重新链接已经实现。
- 源目录显式刷新/对账、HTTPS picker/open、File Provider 下载状态与 App Sandbox entitlements 尚未实现。当前 bookmark 无法解析时只明确报错，不扫描路径、不匹配同名文件、不复制缓存。
