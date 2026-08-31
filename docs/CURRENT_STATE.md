# CURRENT_STATE

最近一次自查日期：2026-08-31

## 当前真实状态总览

- Kuzio 当前工作区实现的是 macOS 26 原生 SwiftUI 虚拟层级资料库；用户已确认核心设计为“库内结构与真实文件/云端结构解耦，节点只链接外部资源”，仍不采用 Rokurics 固定课程层级。
- `main` 与 `origin/main` 当前位于 Git tag `v0.4`；工作区已把 App marketing version 保持为 `0.5` 并把本轮 build 更新为 `2`，包含当前文件夹标题、长文件名展示、完整 8-tool Cowork 注册、presentation-only `IntatisCoworkUI` 接入、重新生成工程、测试与相应文档。这些改动均未 add、commit、tag 或 push；Git tag 与安装版版本暂时不同步。
- 最新源码已经完成前端视觉重做、本地资料库、文件/文件夹递归链接、显式重新链接、provider-neutral工具控制面，以及真正的Intatis Cowork链路。App只有一个主`WindowGroup`：左侧学习库，右侧Harness；folder/document/resource-link context menu与reader“更多”提供“AI 对话”。显式激活后，右栏直接挂载presentation-only `IntatisCoworkUI.IntatisCoworkContentView`，Kuzio不实现chat UI、模型菜单或关闭叉号；Light/Dark Debug与build 2安装版已验证完整Intatis右侧、真实多provider/model菜单、未发送composer ready、target替换/window close和runtime drain。
- Release `0.5`（build `2`）presentation-only Intatis Cowork UI + 完整8-tool minimal版本已经安装为`~/Applications/Kuzio.app`，是arm64/x86_64 universal app；主App与两个nested runtime使用同一Developer ID Application身份、hardened runtime与secure timestamp，strict/integrity验证通过，可直接从安装路径启动，无需打开Xcode。逐工具business-tool approval仍未接入，因此mutation tool一旦被模型调用会直接进入Kuzio provider。
- 2026-08-24 按 Rokurics Mac 源码再次统一全部按钮家族后，已重新运行 `swift build`、26-test `swift test` 与 Xcode Debug App build，并使用隔离 `-KuzioPreviewData` 在 Light/Dark 真实窗口检查 library、reader、editor、trash 与 sheet；可见 circle glass、hit frame 与 SF Symbol 已共同收敛到 36pt / 15pt，不再只有外层 layout frame 为 36pt。
- 2026-08-26 已修复 circle control“可见圆面 36pt、实际只有 glyph 中心容易点中”的命中错位：共享 label 自身拥有 36×36pt frame 与 circle interaction shape，browser history 和 reader back 均已用可见圆面左右边缘坐标点击通过。folder/resource grid tile 同时固定为 152pt 高，并为两行标题与 detail 各保留固定槽位，长短名称不再改变 glass rectangle 尺寸。
- 当前技术栈为 Swift 6、SwiftUI、Observation、Foundation、AppKit、Uniform Type Identifiers，以及唯一 Intatis checkout的`IntatisCore` / `IntatisProtocol` / `IntatisProviders` / `IntatisConversation` / `IntatisCodexRuntime` / `IntatisCoworkUI` / `IntatisSharedUI`。进程在任何dependency object前安装一次`IntatisHostApplication.configure(name: "Kuzio")`；runtime/session namespace使用冻结的Kuzio identity。推理route按用户确认继续由`ChatConfigurationImporter` + `ProviderRegistry.responsesRuntimeRoute(for:)`只读Intatis-owned canonical config；可解析provider/model投影为secret-free UI option，用户选择只冻结下一次`@main` route，credential只进入内存route/child environment，不落Kuzio UI、argv、session instructions、runtime files、日志或文档。Kuzio没有API Key/provider设置页，也不复制或替换runtime/UI。
- App随包封装`CodexRuntime/{arm64,x86_64}` exact `codex-cli 0.145.0-intatis.4`、matching derivation、runtime manifests、SHA inventories、SPDX与完整许可证。产品字体改为只使用`IntatisSharedUI` resource bundle中的JetBrains Mono `v2.304` upright/italic variable TTF，Kuzio额外分发OFL；旧四静态TTF留在源码树但已从SwiftPM/Xcode/App bundle排除。Intatis shared package/runtime/UI provenance继续以Intatis `NOTICE.md`、`ThirdPartyNotices/`和runtime kit为事实源。

## 当前前端

### App shell

- 入口：`Sources/KuzioApp/KuzioApp.swift`。
- 根结构：单一主 `WindowGroup` 内使用系统 `NavigationSplitView`；sidebar 宽度 min 210 / ideal 236 / max 280，detail 再使用原生 `HSplitView`。左侧学习库 min 480 / ideal 720，右侧 Cowork Harness min 440 / ideal 620；窗口最小 1180×690，默认 1520×820。
- sidebar 只承担稳定产品目的地：`资料库` 与 `废纸篓`；任意深度目录不塞入 sidebar，而在 detail 浏览器中呈现。
- sidebar 顶部品牌名 `Kuzio` 使用 28pt JetBrains Mono semibold；单行品牌区采用 Intatis/Mopelium 的 18pt 水平、22pt 顶部、12pt 底部比例，全局拉丁文本统一使用同一字体族，中文通过 Apple 字体级联使用系统苹方。
- sidebar destination button 采用 Rokurics Mac 的 6pt 行间距、13pt SF Symbol、20pt 图标槽、8pt 图文间距、12pt 水平 / 10pt 垂直内边距与 15pt selected glass 圆角。

### 浏览与阅读

- `LibraryBrowserPage` 使用 32pt 当前文件夹页标题（root 保持“资料库”）、34pt 页面边距、1120pt 最大内容宽度、adaptive folder/resource grid 与 document list；breadcrumb 继续显示完整祖先路径。
- folder 与 file resource-link 共用固定 152pt 高的 grid tile；分别使用 `NSWorkspace` 返回的 Finder 原生文件夹图标和文件类型图标。标题固定使用 34pt 两行槽，detail 固定使用 13pt 槽；resource-link tile 只显示文件名，长文件名使用中间截断并由原生 hover help 显示完整标题，空 detail 槽只承担布局，不显示额外说明。
- 后退、前进、阅读页返回/编辑/取消/更多、废纸篓恢复/删除与 browser 单一添加入口均通过共享 `KuzioCircleIconButton` / `kuzioCircleIconControl` 使用 Rokurics Mac 源码的 36pt control、15pt semibold monochrome SF Symbol 与 8pt 同组间距；不再由各页面分散实现，也不把移动端 44pt label 叠加到系统 glass button。
- folder tile 图标采用 Rokurics Mac 的 58×50pt Finder icon / 52pt 垂直槽；document card action label 内的 leading SF Symbol 采用 21pt semibold / 42pt 图标槽。context menu、alert 与 sheet toolbar 的文字按钮仍由 macOS 原生 control sizing 管理。
- 所有 glass surface 只调用 Apple 官方 `.buttonStyle(.glass)` 或 `.glassEffect(...)`；没有自绘 blur、highlight、refraction 或兼容 fallback。
- 当前没有品牌色、RGB/Hex token、渐变、胶囊、装饰阴影或自定义 root/sidebar 背景；window、sidebar、文字与分隔层级均跟随系统语义外观。
- 文档支持打开、Markdown `AttributedString` 阅读、文本选择、纯文本编辑与保存；browser 右上角只显示一个 36pt `+`，普通点击由 `NSOpenPanel` 多选文件或文件夹，新建文件夹/文档命令收在同一个 menu 中。文件直接创建 resource-link；文件夹递归生成同名虚拟 folder tree，并为每个可见文件创建 resource-link。取消不 mutation，确认后只保存只读 app-scoped security-scoped bookmark，不复制或移动原文件。
- “此文件夹为空”使用 `NSWorkspace` 返回的 Finder 原生 folder icon，不使用 SF Symbol folder 占位。
- 点击 file resource-link 会从 object store 读取并校验 bookmark、以 `.withSecurityScope` 解析、平衡 `startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource` 生命周期，再通过 `NSWorkspace` 打开原文件；stale bookmark 会在保持 `ResourceID` / `NodeID` 的前提下事务替换。文件离线、移动、权限失效或系统无法打开时明确报错。
- file resource-link 与可识别导入批次的 virtual folder 右键菜单只增加一个“重新链接”；随后直接使用原生 file-only / folder-only `NSOpenPanel`。没有新增状态文案、说明页、徽标、提示卡片或额外确认弹窗。
- folder、内部document与file resource-link既有context menu都在首项提供“AI 对话”；reader既有“更多”也提供同一操作，不增加browser toolbar control。操作把selected entry交给右侧`KuzioCoworkHarnessHost`，后者直接渲染`IntatisCoworkUI.IntatisCoworkContentView`，不打开第二窗口，也不包含Kuzio `TextEditor`、消息行、模型菜单、approval dialog、Markdown renderer、Inspector、status rail或关闭叉号实现。
- 不包含录音、转写、AI 总结或固定课程层级。

### Cowork 对话

- `KuzioCoworkConversationTarget` 只携带 harness activation request UUID、选中 `NodeID`、kind、title 与 virtual path。稳定 `cowork_<request-uuid>` 是该 target 的 session identity；每个 session 使用 Application Support / `Kuzio/CoworkSessions/<session-id>/workspace` 与独立 `codex-runtime`，目录 owner-only。
- `KuzioCoworkHarnessHostModel`只管理`CodexAppServerSession` lifecycle、send/interrupt/approval/Goal action、secret-free provider/model options、下一轮route选择，以及public runtime event→`CodeItem` / `CoworkAgentThreadSnapshot`输入；`IntatisCoworkContentView`拥有实际presentation。session configuration显式保存Kuzio host identity；切换模型时复用同一session/workspace/runtime root和同一8-tool dynamic toolset，只在空闲边界重建精确route的App Server host。
- session workspace 的 `AGENTS.md` 把 title/path 明确标为 untrusted display data，并要求从选中 `NodeID` 开始；它不包含 raw external path、bookmark、locator、manifest fragment、credential 或 provider route。
- `KuzioCodexLibraryTools` 通过官方 `CodexRuntimeDynamicTools` 直接投影完整 8-tool `LibraryToolProvider`：3 个读取工具与 create-folder / rename / move / trash / restore 5 个独立结构 mutation。Cowork authorization 显式授予 `read_structure`、`read_content` 与 `mutate_structure`；每个工具只执行一个最小操作，不提供 organize/apply-plan/batch 复合工具。binary/directory/HTTPS 内容仍按既有工具合同明确失败，所有外部目标继续只读。
- 未选择target时右栏只显示`Cowork Harness`占位，不创建runtime。用户明确要求Intatis原始右半边，不增加Kuzio关闭叉号；切换target或关闭主窗口会shutdown当前runtime。本轮Light隔离Debug App只有一个标准窗口，AX出现`cowork.harness.intatis-cowork-ui`、完整composer、Intatis模型菜单和无额外close action；菜单列出多个当前可解析provider/model，选择后下一轮标签更新，未发送草稿可启用Send并可清空。替换target后标题与默认模型重建，进程检查只有一个当前Debug App Server；关闭窗口后没有Kuzio App Server残留。当前没有独立历史session列表或手工reopen UI。

## 当前工具控制面

- `LibraryToolControlPlane` 是独立于 UI 和模型供应商的 actor，只接收强类型 `LibraryToolCall`，完成 capability 检查后复用唯一 production `LibraryStore`。
- `LibraryToolProvider` 以 `com.vitemis.kuzio.library-tools.v1` 发布 capability-scoped 工具 definitions；每项包含稳定名称、description、标准 JSON Schema object 和 required capability。它只是未来完整工具总和中的 Kuzio contributor，不排斥或替代其他工具来源。
- provider 接收最多 65,536 bytes 的 JSON object，拒绝未知字段、缺少/错误类型、非 canonical UUID、负 index 与未知 tool name；未授权工具不出现在 definitions 中，绕过目录直接调用仍在解码/Store 前返回 `permission_denied`。
- provider 把成功/失败编码为稳定 snake_case JSON envelope，合同中的可空 node/content/mutation 字段显式输出 JSON `null`；不自动重试、合并冲突、修改调用或维护第二份 tool state。
- 当前提供 8 个工具：读取库状态、列出 folder children、分段读取 UTF-8 内容、创建 folder、rename、move、trash、restore。没有 permanent-delete、外部文件写入、任意路径读取、自动重连或 source refresh 工具。
- capability 明确分为 `read_structure`、`read_content` 与 `mutate_structure`；未授权调用在进入 Store 前返回稳定 `permission_denied`。
- 所有 structure mutation 必须携带 `expected_revision`，并返回 published revision、transaction ID 和 changed node IDs；revision conflict 不自动重试或合并。
- 工具只接受 `NodeID` 和虚拟 parent，不接受 raw path、URL、bookmark bytes、manifest fragment 或 object-store key。external resource content 仍通过现有 `ResourceID`、immutable locator 与 security-scoped access 读取，结果不暴露真实路径。
- 内容读取按 byte offset 分段，单次默认 64 KiB、上限 256 KiB，并返回精确 `nextByteOffset`。当前只支持内部 UTF-8 document 与已链接本机 UTF-8 file；binary、directory 和 HTTPS 内容明确失败，不调用替代 parser/backend。
- 精确 tool name、JSON Schema、调用参数、结果与稳定错误码见 `docs/TOOL_CALLING.md`。Cowork host 把完整 8 个最小工具经最薄 JSONValue/spec/call/result bridge 交给 App Server；Agent loop 负责逐步选择和编排，Kuzio adapter 不合并操作、不自动重试或改写调用。现有注册不等于已完成 business-tool approval 接线；真实 App Server mutation callback 与逐工具审批仍需单独验收。

## 当前可移植文件系统

### 默认位置与包结构

- production 默认库位于用户 Application Support 下的 `Kuzio/Default.kuzio`。
- `Default.kuzio` 可整体复制；内部文档保持自包含。schema v2 外部链接只随包保存虚拟结构、`ResourceID` 与 locator object，不复制外部目标，因此复制到无法解析目标的环境后必须由后续访问层明确要求 relink，不能静默切换缓存或同名文件。
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

- `manifest.json` 标识符为 `com.vitemis.kuzio.library`，layout version 为 1，当前 schema version 为 2；已知 schema v1 在 open 时通过同一 transaction/previous-manifest 合同迁移到 v2，未知版本继续明确失败。
- hierarchy 的唯一事实源是 flat manifest 中 folder 的 ordered child ID；title 从不成为磁盘路径，层级深度没有 type/subject/chapter/topic 上限。
- `NodeID` 只表示库内虚拟位置；`ResourceID` 表示外部文件身份；`ImportID` 关联一次文件夹导入批次。多个 resource-link node 可共享同一个资源。选择文件夹时，真实目录只作为一次性扫描输入：可见子目录成为普通 virtual folder，每个文件保存最多 1 MiB 的 immutable locator object，并可保存仅用于显式重连的 `ImportID` 与相对来源 components；manifest 不保存真实绝对根路径，来源 metadata 永不成为 hierarchy truth。
- library、node、resource、payload object 与 transaction 均使用 canonical lowercase UUID；重命名和移动不会改变 node/resource identity。
- 已实现 create folder/document/external-resource-link/resource-alias、atomic recursive linked-tree creation、single/batch locator replacement、rename、move、trash、restore、permanent delete、refresh、explicit previous-manifest recovery 与 garbage collection。批量重连先验证全部相对目标，再用一次 transaction 更新同一 `ImportID` 的全部 resource locator；不创建节点、不改变虚拟层级。
- 永久移除 resource link 只删除虚拟节点；仅最后一个 alias 消失时回收 resource record 与 locator object，任何数据层 API 都不会删除外部目标。
- 废纸篓保存原 parent/index；恢复保持 subtree 与稳定 ID。原 parent 已删除时必须给出明确恢复目的地，不静默猜测。

### 一致性与安全

- `LibraryStore` 是 actor；所有 mutation 带 expected manifest revision，冲突明确返回 `revisionConflict`。
- writer 使用 `NSFileCoordinator`、transaction staging、immutable payload、atomic manifest replacement 与 previous manifest。
- document read、refresh、purge completion 与 garbage collection 都在 library root 协调区间内重载磁盘最新 manifest，避免陈旧窗口删除另一 writer 的新 payload。
- manifest validator 检查 format/version、canonical title/media type/UUID、folder/document/resource-link shape、node→resource 引用、orphan resource、跨 document/locator object 唯一性、cycle、trash overlap、资源上限、payload/locator size、locator digest 与路径类型。
- 管理路径拒绝 symbolic link、alias、payload/manifest hard link 和越界路径；正文读取验证 byte count 与 SHA-256。
- corruption 不触发 preview/mock/alternate backend。当前 manifest 损坏且 previous manifest 有效时返回 `recoveryRequired`，只有显式恢复 API 才发布 previous manifest。

## 本机安装状态

- 本机正式使用路径固定为 `~/Applications/Kuzio.app`；该 bundle 是 Release 生成物，不属于仓库源码，不提交 Git。
- 安装版继续通过同一个 `LibraryBootstrap` 读取用户 Application Support 下的 production `Default.kuzio`，不会复制、重建或切换第二套资料库。
- 2026-08-31 v0.5 build 2从全新独立DerivedData完成universal Release。arm64/x86_64 nested Codex分别使用与旧安装版相同的Developer ID Application身份、hardened runtime与secure timestamp签名；随后按Intatis packaging逻辑刷新两份`runtime-manifest.json.binary_sha256`和完整`SHA256SUMS.txt`，再签outer App。fresh/installed executable SHA-256一致（`71dc…405f`），三份strict signature、outer seal、两架构static validator、bundle identifier、`0.5` / build `2`、universal架构与SharedUI variable fonts/OFL均通过。旧build 1保存在`/private/tmp/KuzioInstalledBuild1Backup.Fcwp23/`，未删除。正式路径启动后production root和真实`Syllabus.md`外部链接打开无Kuzio错误；`UCB-CS61A`右栏AX确认`cowork.harness.intatis-cowork-ui`、Intatis模型菜单、无Kuzio叉号和未发送composer ready。关闭主窗口后runtime drain，随后从正式路径重启并留在资料库首页。production manifest全程保持revision 17、578 nodes、457 resources与原SHA-256不变，没有资料库mutation。
- 2026-08-30 v0.5 从全新独立 DerivedData 完成 universal Release。arm64/x86_64 nested Codex 分别使用与旧安装版相同的 Developer ID Application identity、hardened runtime 与 secure timestamp 签名；随后按 Intatis packaging 逻辑刷新两份 `runtime-manifest.json.binary_sha256` 和完整 `SHA256SUMS.txt`，再签 outer App。fresh/installed executable SHA-256 相同（`316b…e2db`），三份 strict signature、outer seal、两架构 static validator、bundle identifier、`0.5` / build `1`、universal 架构与 SharedUI variable fonts/OFL 均通过。从正式路径启动后 production root、动态文件夹大标题和真实 PDF 系统打开无 Kuzio 错误；`Notes` Cowork composer ready，未发送消息即关闭，runtime process drain。production manifest 全程保持 revision 17、578 nodes、457 resources 与 SHA-256 `a045…f703`，没有资料库 mutation。App 当前留在资料库首页。
- 2026-08-26 已从安装路径实际启动，确认 production 根目录中的三门课程与一个文件可见；根文件和课程嵌套 PDF 均可通过 `NSWorkspace` 打开。
- 先前由 ad-hoc Debug binary 创建的 app-scoped bookmarks 与稳定安装签名不兼容；四个旧根节点已移到 Kuzio 废纸篓，并由最终安装版从相同外部目标重新创建链接。外部目录和文件未被移动、复制、改名或删除，旧虚拟节点仍可恢复。
- 当前本机安装签名包含 secure timestamp，但尚未公证；它只表示这台 Mac 上可直接使用和持续更新的本地安装版，不表示已具备对外分发条件。
- 2026-08-27 已用最新 Release 更新安装版并实际执行一个 165-file legacy course 的文件夹重连：production revision 只从 16 增至 17，四个 root child `NodeID`、457 个 resource 总数与外部样本文件 SHA-256 均保持不变；165 个资源获得同一 `ImportID`，manifest 仍不含绝对路径，重启安装版后嵌套文件可打开。
- 2026-08-27 工具控制面完成后再次从全新 derived data 构建 Release，并以同一 Developer ID Application 身份、hardened runtime 与 secure timestamp 更新 `~/Applications/Kuzio.app`。安装副本的 bundle identifier、`0.1` / build `1`、arm64/x86_64、可执行文件、四个字体资源与签名校验均通过；从安装路径启动后 production revision 仍为 17，三门课程和根文件可见，课程内真实 PDF 链接发起打开时没有 Kuzio 错误，本轮没有 mutation production library。
- 2026-08-27 可组合工具 provider 完成后又从独立 derived data 全新构建 Release，保持同一 Developer ID、hardened runtime 与 secure timestamp 更新 `~/Applications/Kuzio.app`。安装副本与 fresh Release executable 完全一致；bundle identifier、`0.1` / build `1`、arm64/x86_64、四个字体 checksum 与 strict signature 均通过。从最终安装路径启动后 production revision 仍为 17，三门课程和 `Syllabus.md` 可见；点击既有 `Syllabus.md` 外部链接没有 Kuzio 错误，未执行任何资料库 mutation。
- 2026-08-28 Cowork 功能从独立 derived data 完成 universal Release，分别签署 arm64/x86_64 nested Codex executables、刷新 manifest/SHA inventory 后再签顶层 App；主 App 与两个 runtime 都使用同一 Developer ID、hardened runtime 与 secure timestamp，并通过 strict signature 与 Intatis `validate-codex-runtime.sh`。`~/Applications/Kuzio.app` 已原子更新，installed executable 与 fresh Release 完全一致；从安装路径启动后 production revision 仍为 17，三门课程和 `Syllabus.md` 可见，真实外部链接打开无 Kuzio 错误。production folder Cowork 对无敏感、禁止工具的测试消息返回 `READY`，显示 reasoning activity 与 7,138-token usage；没有调用 library tool或 mutation library。
- 2026-08-28 单窗口双栏版本再次从全新 derived data 构建并原子更新 `~/Applications/Kuzio.app`。installed executable 与 fresh Release 完全一致；bundle identifier、`0.1` / build `1`、arm64/x86_64、四个字体 checksum、outer seal 与两个 runtime 的独立签名/manifest/SHA 校验均通过。从安装路径启动后只有一个标准窗口，production 三门课程与 `Syllabus.md` 可见，真实外部链接打开无 Kuzio 错误；`UCB-CS61A` 在右侧 harness 到达 ready，关闭后恢复空态且无 Kuzio runtime process。production revision 保持 17，578 个节点、457 个 resource 与 manifest SHA-256 均未变化；本轮没有发送新的模型 turn，也没有 mutation library。
- 2026-08-28 最新Intatis host identity + dependency-owned Shared Harness版本又从全新derived data完成universal Release。arm64/x86_64 nested Codex先分别使用同一Developer ID、hardened runtime、secure timestamp签名，再按Intatis packaging逻辑刷新manifest/SHA inventory并签outer App；三份strict signature、两架构`validate-codex-runtime.sh`与outer seal均通过。`~/Applications/Kuzio.app`已原子更新，installed executable与fresh Release SHA-256同为`b3379e0250a647fc0b32dd3ac85915b8ca8b4734b5118facab3a3e1746c4694d`。App bundle只有SharedUI两个variable TTF和Kuzio OFL。正式路径启动后production三门课程与`Syllabus.md`可见，真实链接打开无Kuzio错误；`UCB-CS61A`右栏AX确认`CoworkShell`和SharedUI composer。安装版发送无敏感、明确禁止工具的测试消息后，SharedUI真实渲染用户消息、`READY` root reply、reasoning时间与7,186-token usage；message AX ID以`kuzio.message...`命名，未调用library tool。close后runtime drain，验证session已移入废纸篓。revision仍17，578节点、457 resources与manifest SHA-256`a045…f703`不变，未mutation library。

## DEBUG 边界

- `-KuzioPreviewData` 只在 `#if DEBUG` 下创建独立临时 `.kuzio` 包并写入演示数据，用于窗口验收。
- 无参数 production 启动不会加载 preview fixture，也不会在真实库失败后降级到内存数据。
- `-KuzioAppearanceLight` / `-KuzioAppearanceDark` 只用于 DEBUG 外观验收；无参数启动始终跟随系统 appearance。

## 测试源码状态

- 2026-08-30 Cowork mutation registration 与 v0.5 安装完成后已运行 SwiftPM graph、`swift build`、43-test `swift test`、XcodeGen 2.45.4、Xcode Debug 与全新 universal Release App build：全部通过，测试 0 failures；Xcode 只报告 Intatis checkout 既有 `ChatLoop.swift` / MCP unused warnings。测试确认 `KuzioCodexLibraryTools` 与实际 `CodexRuntimeDynamicTools.specs` 使用独立 `com.vitemis.kuzio.library-tools.cowork.v2` toolset ID，按固定顺序逐个包含 8 个工具，并通过同一薄 bridge 执行单次 `library_create_folder`，published revision 只增加 1；session instructions 同时锁定“一工具一最小操作”、逐步携带最新 revision 与 `revision_conflict` 后重读。v0.5 正式路径 Cowork runtime/composer ready 与 shutdown/drain 已通过；真实模型驱动的 App Server mutation callback 与逐工具 approval 尚未运行。
- 2026-08-30 当前文件夹标题与 resource-link 长文件名展示完成后已运行 `swift build`、43-test `swift test` 与 Xcode Debug App build，全部通过；SwiftPM 因本机 `sandbox-exec` 限制在获批的沙箱外完成。唯一 bundle ID、隔离 `-KuzioPreviewData` 的 Light 临时 Debug App 已确认 root 大标题仍为“资料库”，进入“数学”后大标题同步变为“数学”，breadcrumb、36pt controls 与等尺寸 grid 未变化。resource-link `.middle` 截断和完整标题 `.help` 已由当前源码、Swift/Xcode build 覆盖；临时 App 在后续真实 PDF 层导航时 UI 控制 native pipe 中断，因此本轮没有把 Dark 或 hover tooltip 的实际窗口显示写成已通过。
- `LibraryStoreTests.swift` 保持 38 个测试；`KuzioCoworkRuntimeTests.swift` 当前 5 个测试，合计 43 tests。
- 原 18 个文件系统测试继续覆盖复制、任意深度、稳定 ID、并发、恢复与安全；新增 8 个方向覆盖虚拟树/真实目标解耦、alias 生命周期、relink 身份、v1→v2 迁移、locator digest、HTTPS locator、陈旧 store GC 与协调读取。
- recursive linked-tree / batch relink 继续由 4 个方向覆盖；新增 4 个工具层方向覆盖完整结构 mutation、capability/revision fail-closed、UTF-8 分段读取与真实 bookmark 外部文本读取。
- 新增 4 个 provider 方向覆盖 capability-scoped definitions/JSON Schema、7 个结构工具的完整 JSON wire 调用链、内容工具默认参数与 snake_case/null envelope，以及 unknown/extra/malformed/oversized/unauthorized 调用 fail-closed。
- 5个Cowork方向覆盖：完整8-tool minimal dynamic-tool surface、真实read/mutation provider wire envelope；process-first `Kuzio` host identity和`INTATIS_CONFIG` shared-config owner派生；Intatis-compatible多模型fixture→memory-only routes/secret-free options且description redaction；`.cowork` configuration、stable session root、owner-only selected-node instructions、无credential/path泄漏、target Codable identity；主scene唯一`WindowGroup`、library/harness `HSplitView`、direct `IntatisCoworkContentView`、Harness源码无`CoworkShell`/自制model menu/xmark/composer/renderer/approval UI。
- 2026-08-28 最新内核适配源码已运行`swift build`、43-test `swift test`、XcodeGen 2.45.4、Xcode Debug/全新universal Release builds，全部通过；Light/Dark DEBUG preview已检查单窗口双栏、右栏空态、folder AI入口、dependency-owned CoworkShell/composer ready、关闭恢复空态与process drain。SharedUI版本的签名安装、字体/runtime inventory与production只读验收也已完成；上一版自制UI安装证据只保留为历史，不再代表当前产品。
- 2026-08-27 已重新运行 `swift build`、`swift test`、Xcode Debug App build 与独立 derived data 的全新 Release App build：38 tests，0 failures，正式 App target 构建成功；同身份安装与 production 只读验收也已完成。

## 当前风险与未完成项

- 2026-08-26 已用唯一临时 bundle ID 与隔离 preview store 实际验收：单一 `+` 打开文件/文件夹多选 Open Panel；选择含空目录、两层子目录和三个文件的课程目录后，只增加一次 revision，并生成完整 virtual tree 与三个可打开的文件链接。Light 完成结果窗口检查，Dark 完成入口与实际 transaction 检查；隔离 manifest 不包含 fixture raw path。
- 当前只提供默认 Application Support 库；Open/Save panel、用户选择外部 `.kuzio` 包、导入/导出与 document type 关联尚未确认，不得描述为已有能力。
- 文件和文件夹多选、递归一次性投影、嵌套文件打开、单文件重连与导入批次重连已经实现；源目录后续变化的显式刷新/对账、HTTPS 添加与打开、File Provider 离线下载进度尚未实现。隐藏项目被跳过，符号链接和其他非常规文件会明确失败。
- 正式 target 当前未启用 App Sandbox；本轮已验证安装版可创建、解析并使用只读 security-scoped bookmark，但 Sandbox entitlement 与现有默认库向 container 的迁移仍未确认，不得描述为已完成 sandbox 发布配置。
- 当前没有同步、账号、网络抓取或跨设备协作；本机 Developer ID + secure timestamp 安装方式已经确认，但公证、对外发布与自动更新服务仍未配置。
- Cowork runtime、root streaming、usage、完整 8-tool minimal dynamic-tools registration 与双架构 executable bundle 已接入；真实 provider turn 已返回 `READY`。bridge/provider 单次 mutation callback 已由测试执行，但真实模型驱动的 App Server dynamic tool callback、child delegation 与逐工具 approval round trip 尚未触发，不能描述为已线上验收。当前 AI tools 支持 virtual create-folder/rename/move/trash/restore，不支持 permanent delete、document content mutation、binary/PDF parsing、directory/HTTPS content、relink 或外部目标写入。
- 当前唯一 Intatis checkout存在大量既有未提交的host identity/runtime/SharedUI与presentation-only `IntatisCoworkUI`改动；Kuzio只读消费当前源码且SwiftPM/Xcode构建通过，没有修改Intatis源码。跨机器或clean checkout可复现性取决于上游先按Intatis自身流程落盘；`IntatisConversation`/`IntatisCoworkUI`/`IntatisSharedUI`必须按各自public合同重新编译验收，Kuzio不得复制、pin第二checkout或增加compatibility facade兜底。
- XCUITest、VoiceOver 全流程、大型 100k-node 压力和故障注入仍未覆盖。

## 工作区与文档冲突

- 本轮开始时 `main` / `origin/main` 位于 `v0.4`；当前未提交差异包含用户确认的浏览页标题/resource-link 长文件名展示、完整 8-tool Cowork 注册、marketing version `0.5`、重新生成的 Xcode 工程、测试与相应文档。没有回退或清理其他改动；未 add、commit、tag 或 push。
- 旧文档仍把 Git 状态写成 `v0.1` 与未提交 schema v2 工作区；该描述已被当前 `v0.4` clean baseline 取代，本轮以实际 Git/source 为准同步更新。
