# DO_NOT_BREAK

本文列出 Kuzio 当前不可破坏的工程、UI、字体、文件格式、安全与回归边界。

## Git 与仓库边界

- Git root 固定为 `/Users/vita/Vitemis/Virgo/Kuzio`；不得把本项目文件写入或暂存到父仓库。
- 不直接编辑 `.git/`，不执行 `git reset --hard`、`git clean`、`git checkout .`、强制 push 或删除用户未提交文件。
- 未经用户明确要求具体 Git 操作，不 add、不 commit、不 push、不创建 PR。
- 用户已有路径修正文档改动必须保留；不得用生成、格式化或重写顺手清理无关文件。

## 产品与前端边界

- 产品是通用任意深度资料库；不得恢复 Rokurics 的 type/subject/chapter/topic 固定四层，也不得增加录音、转写、AI 总结、同步、上传或课程 schema。
- sidebar 只承载稳定产品 destination；不得把任意深度目录树重新塞进 sidebar。
- 不增加品牌色、自定义 RGB/Hex、渐变、纹理、固定浅/深色 root background、装饰性 stroke 或 shadow。
- 不增加胶囊、status pill 或无真实功能的 decoration。系统 search field 与系统 control 自身形态不属于第一方胶囊实现。
- 不自绘 Liquid Glass，不增加 blur/highlight/refraction/shader、glass wrapper 或旧系统 fallback；只使用 Apple `.glass` / `.glassEffect` API。
- 不添加自制 folder asset、手写矢量或第三方图标。folder display 必须直接使用 `NSWorkspace` 的 Finder 原生 icon；功能 action 只使用 SF Symbols。
- browser 右上角只能有一个可见 `+`；普通点击必须直接打开文件/文件夹多选 `NSOpenPanel`，folder/document creation 只能留在同一个 menu 内，不得恢复三个可见加号按钮。“此文件夹为空”必须使用 Finder 原生 folder icon，不得使用 SF Symbol folder 占位。
- macOS circle icon action 固定采用 Rokurics Mac 的 36pt visible control / 15pt semibold monochrome symbol、8pt 同组间距与 0.46 disabled opacity；`KuzioCircleIconLabel` 必须自身拥有 36×36pt frame 与 circle interaction content shape，不能只在 `Button` 外层扩大视觉 frame，否则实际命中会退回 glyph 中心。普通 button 必须通过 `KuzioCircleIconButton`，menu trigger 必须通过 `kuzioCircleIconControl` 并隐藏 menu indicator。共享 modifier 必须让同一 36pt frame 直接承载 Apple official interactive circle glass；不得在页面内重新散落 circle glass/frame 实现，不得误用共享移动端 44pt / 18pt 指标，也不得退回只有 glyph 大小的默认按钮。
- folder 与 file resource-link grid tile 必须保持统一 152pt 高、34pt title 槽与 13pt detail 槽；短名称、两行长名称以及 resource-link 没有可见 detail 时都不得改变 glass rectangle 尺寸。adaptive column 只允许随可用窗口宽度整体调整，不允许由单项文字 intrinsic size 决定卡片宽高。
- sidebar destination button 固定保持 Rokurics Mac 的 6pt 行间距、13pt SF Symbol / 20pt 图标槽、8pt 图文间距、12×10pt 内边距与 15pt selected glass 圆角；system alert、context-menu item 与 sheet toolbar text button 继续使用 macOS 原生 control sizing，不强行改成 circle icon button。
- 重新链接只能复用 item context menu 中的单一“重新链接”和原生 file-only / folder-only `NSOpenPanel`；不得增加状态文案、说明页、徽标、提示卡片、额外确认弹窗或新的 toolbar control。
- “AI 对话”只能作为 folder/document/resource-link 既有 context menu 的 item action，并在 document reader 复用既有“更多”菜单；不得增加第二个 browser toolbar action、sidebar destination、悬浮按钮或自动弹窗。该操作必须在单一主窗口中激活右侧 Cowork Harness，默认 mode 固定 `.cowork`；不得恢复第二个 AI `WindowGroup`。
- 主 detail 必须保持原生 `HSplitView`：左侧学习库 min 480 / ideal 720，右侧 harness min 440 / ideal 620。未选择 target 时右栏只允许系统语义空态且不得预启动 runtime；激活后必须直接挂载 `IntatisSharedUI.CoworkShell`。Kuzio 不得实现或复制 transcript/message row、composer、Send/Stop、permission dialog/card、Agents/Goal/Tasks inspector、Markdown/rich renderer、scroll coordinator、status rail或 SharedUI control styling；本地 view只允许最薄 lifecycle、bindings、selected context、runtime actions和dependency header close action。
- sidebar 品牌与 App 文本不得散落 `.font(.system...)` 文本路径；`.font(.system...)` 只允许用于 SF Symbols 的 size/weight。
- 不把每个 sidebar row、metadata row 或正文段落包成自定义卡片；sidebar selected row 只允许 Apple rectangular glass，form、sheet、alert 与 split-view chrome 保持原生。

## 字体依赖边界

- exact runtime dependency 固定为 `IntatisSharedUI` resource bundle 中 JetBrains Mono `v2.304` upright/italic 两个官方 variable TTF；checksum见 `docs/FONT_DEPENDENCY.md`。
- `Fonts/JetBrainsMono-OFL.txt` 必须继续作为 Kuzio resource分发。仓库中旧 Regular/Medium/SemiBold/Bold 四个静态 TTF必须保持 SwiftPM exclude，且不得出现在 `project.yml`/generated project/App bundle、不得注册或作为 fallback。
- App 入口在 host identity 后直接调用 `IntatisTypography.prepareJetBrainsMonoTypography()`；学习库 views直接使用 `IntatisTypography`，不得恢复 `KuzioTypography`、第二个 Core Text registration、checksum表、字体 wrapper/provider或另一版本。
- IntatisSharedUI 的 resource SHA-256、descriptor set、process registration与bundle URL resolution任一失败必须 fail closed；不得静默回退 system serif、SF Mono、Menlo或旧静态 TTF。
- JetBrains Mono 不含 CJK；中文必须继续由 Apple 字体 cascade 处理，不嵌入或复制苹方。

## Package 与 schema v2 边界

- format identifier：`com.vitemis.kuzio.library`。
- layout version：1；current schema version：2。schema v1 是唯一允许迁移的旧版本，必须先完整验证，再通过 transaction/previous/atomic publish 迁移；未知版本必须明确失败，不得猜测。
- authoritative hierarchy 只来自 manifest 中 folder 的 ordered `children` IDs；不得并存 path-derived tree、第二份 index 或 shadow catalog。
- `LibraryID`、`NodeID`、`ResourceID`、`ImportID`、`ObjectID`、`TransactionID` 必须使用 canonical lowercase UUID 编码。
- title 是 display metadata，不得用于文件名、目录名、object key 或 identity。包含 `/`、`..` 或反斜线的合法 title 仍不得影响 managed path。
- payload object immutable；document update 创建新 `ObjectID`，不得原地覆盖已发布 payload。
- `NodeID` 只表示 virtual placement，`ResourceID` 只表示 external target identity；resource-link node 只能保存 `ResourceID`，不得保存绝对 path、相对 path component 或 bookmark bytes。
- external locator 必须作为最多 1 MiB、带 byte count/SHA-256 的 immutable object 保存；replace locator 创建新 `ObjectID`，保持 `ResourceID` 与 alias `NodeID`。
- 文件夹导入可在 external resource metadata 中保存可选 `ImportID` 与 canonical relative path components，且只用于用户显式 batch relink。不得保存 absolute root path，不得由 provenance 推导、刷新或重建 virtual hierarchy。
- 同一 `ResourceID` 可被多个 virtual node 引用。只有最后一个 alias 被永久移除时才可回收 resource record/locator object；任何 trash/permanent-delete API 都不得删除、移动、重命名或写入外部 target。
- 选择文件夹必须一次递归投影全部可见普通目录与文件：目录创建 virtual folder，文件创建 read-only resource-link；整个 linked tree 必须由一次 transaction 原子发布，失败时不得留下部分节点或 locator。隐藏项目不投影，符号链接与非常规文件必须明确失败。
- 递归投影只发生在用户确认时；投影完成后 manifest folder children 仍是唯一 hierarchy truth。不得 watch、自动 mirror 或让真实目录变化直接改写 virtual tree；源目录刷新/对账必须作为后续显式 mutation 单独设计。
- store 对 file/directory locator 只认识 opaque read-only descriptor；当前 file-link UI 必须保存 Apple 只读 app-scoped security-scoped bookmark，manifest 不得保存 raw path。HTTPS locator 只允许无 username/password 的 `https` URL；任何未实现能力不得用 raw path、缓存副本或 provider adapter 兜底。
- browser 的链接入口必须位于当前虚拟文件夹语义内：`NSOpenPanel` 取消时不 mutation；确认单文件时创建 resource-link，确认文件夹时在当前 parent 下创建同名 virtual subtree，不复制、移动、重命名或写入任何外部目标。
- file resource-link 必须复用 folder grid tile 与 Finder 原生文件类型图标，只显示文件名；不得使用 document 长条或添加说明文案。内部 document 长条保持不变。
- 打开 file link 必须用 `.withSecurityScope` 解析 bookmark，并严格平衡 `startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource`。stale bookmark 只能通过 immutable locator replacement 更新并保持 `ResourceID` / alias `NodeID`；解析失败必须显式报错，不得退回 last-known path。
- 单文件重新链接必须保持 `NodeID` / `ResourceID` / alias identity，只替换 immutable locator，并从原 `ImportID` 脱离。文件夹重新链接必须先验证同一 batch 的全部 relative target，再用一次 transaction 替换全量 locator；缺失、重复、越界、symlink 或类型错误时不得部分提交。
- batch relink 不得新增、删除、移动、重命名 virtual node，也不得复制、移动、写入或删除外部目标。virtual rename/move 后仍必须按 `ImportID` 而不是当前 virtual path 找到全量 batch。
- rename、move、trash 与 restore 必须保持 `NodeID`；rename/move 不得改变 content revision。
- folder 层级保持任意深度，不得把 DEBUG seed 的名称或深度固化为 enum/schema。
- production 默认 store failure 不得切换到 DEBUG seed、内存 fixture、alternate backend 或简化路径。

## Transaction、并发与恢复边界

- mutation 必须携带 expected manifest revision；write claim 内必须重读 disk manifest 并再次比较 base revision。
- manifest 发布必须使用 staging + immutable object promotion + atomic replacement；不得先覆盖 authoritative manifest 再写 payload。
- previous manifest 必须在普通 commit 中保存 publish 前状态；permanent delete 必须先消除 previous 对待 purge document/locator object 的引用再删除 bytes。
- document/external-resource read、refresh、purge completion 与 garbage collection 必须在 library root 的 `NSFileCoordinator` claim 内读取同一代磁盘状态。
- garbage collection 不能使用 actor 的陈旧 manifest 直接判断；必须合并最新 current 与有效 v1/v2 previous manifest 的 document/locator references。
- current manifest 损坏时不得自动恢复。只有 current 无效、previous 有效时返回 `recoveryRequired`；仅显式 recovery API 可发布 previous。
- cleanup failure 可以报告 `cleanupPending`，但不得伪装成 rollback，也不得删除 current/previous 仍引用的 object。

## 工具控制面边界

- 工具层必须保持 provider-neutral。用户已确认的 exact shared dependency 只有 `../../Intatis` 中的 Intatis v1 host products；Kuzio 只实现合同允许的 Host/Profile/Tools/UI 薄接线，不得自建 agent loop、App Server protocol、provider adapter、MCP translator 或后台 runtime。
- `Package.swift` 与 `project.yml` 必须同时把 `../../Intatis` 解析到唯一 `/Users/vita/Vitemis/Intatis` checkout，并直接声明实际使用的 `IntatisCore`、`IntatisProtocol`、`IntatisProviders`、`IntatisConversation`、`IntatisCodexRuntime`、`IntatisSharedUI`。不得复制任何 Intatis package/UI source，不得改用 snapshot、vendored clone、远程同名包或第二个 checkout。SharedUI/Conversation 不在 v1 frozen runtime list内，因此每次上游变化必须重新编译/窗口验收，不能增加兼容 facade。
- App 入口必须在任何 Intatis object 前只调用一次 `IntatisHostApplication.configure(name: "Kuzio")`；迟到配置、不同 identity 或默认 `.intatis` identity必须视为接线错误。每个 session必须显式保存同一 `hostApplicationIdentity`，不得手写环境变量、registry/policy/toolset/reserved-field命名表。
- App 启动必须保留 `CodexRuntimeHostContract.publicAPIMajorVersion == 1` 的 fail-closed校验。按用户确认，Cowork route只能由 `ChatConfigurationImporter` + `ProviderRegistry.responsesRuntimeRoute()` 从 Intatis-owned exact canonical config形成；config candidates必须通过 `IntatisHostApplicationIdentity.intatis`派生，不得创建/复制/写入Kuzio config、增加 API Key/provider/model设置、硬编码endpoint/model、读取其他app login、默认credential或provider fallback。credential只能停留在memory route/process environment，不能进入argv、workspace instructions、runtime files、日志、文档或error dump。
- 每个 Cowork harness activation request 必须映射稳定 `cowork_<request-uuid>`；session root、workspace 与 `codex-runtime` 只能位于 owner-only Application Support / `Kuzio/CoworkSessions/<id>`，不能与其他 session 共用写 root。同一 active target 必须使用同一 session identity，并在 resume 前 pause active Goal；关闭 pane、替换 target 或关闭主窗口必须 shutdown 并确认 child process 退出。
- selected context 只允许在 session `AGENTS.md` 中保存 canonical `NodeID`、kind、title 与 virtual path，并把 display fields 标为 untrusted data；不得保存或推导 external raw path、bookmark/locator、manifest fragment、object key、provider route 或 credential。
- `LibraryToolProvider` 只代表 Kuzio 向完整 Cowork 工具总和贡献的 contributor，不得把 8 个 definitions 误写成模型唯一工具面。`KuzioCodexLibraryTools` 只能通过 `CodexRuntimeDynamicTools` / 官方 App Server `dynamicTools` extension 做 JSONValue/spec/call/result 的最薄转换；不得修改共享 runtime、恢复旧 AgentLoop、增加 MCP translator、shell/Python 替代执行或任何 failure fallback。
- 当前 Cowork conversation authorization 只能授予 `read_structure` 与 `read_content`，因此必须只广告 `library_get_state`、`library_list_children`、`library_read_content`；五个 structure mutation 工具即使在完整 provider 中存在，也不得出现在 Cowork specs 或被 callback 执行。后续 mutation 需要单独用户确认的权限/产品合同，不能只加 capability flag。
- provider identity `com.vitemis.kuzio.library-tools.v1` 与当前 8 个名称/schema/default/wire 语义绑定；不兼容变化必须提升版本。definitions 必须按 capability 过滤，同时直接调用未授权工具仍须在参数解码和 Store 前拒绝。
- 所有 input schema 必须是 object、保持 `additionalProperties: false`，并与 strict decoder 使用同一名称、required/default/range 事实。`argumentsJSON` 上限固定 65,536 bytes；未知 name/key、缺失或错误类型、非 canonical UUID、负 index 与超限输入必须稳定返回 `invalid_arguments`，不得宽松丢字段或猜测参数。
- wire result 必须保持 `{ok, tool, result}` / `{ok, tool, error}`、snake_case 与稳定错误码；合同要求存在的可空 node/content/mutation 字段必须编码为 JSON `null`，不得泄露底层错误、路径或 locator。
- `LibraryToolControlPlane` 必须复用唯一 `LibraryStore` snapshot/read/mutation 和 transaction；不得增加 AI 专用 backend、shadow manifest、第二份 hierarchy、自动重试或冲突合并。
- tool call 只允许使用 canonical `NodeID` / `ResourceID`、虚拟 parent、bounded content offset/limit 与 expected manifest revision。不得接受或返回 raw path、URL、bookmark bytes、manifest fragment、object key 或凭据。
- capability 必须在 Store 调用前明确检查；`read_structure`、`read_content`、`mutate_structure` 不得隐式互相授权。
- structure mutation 必须携带 `expected_revision`，并把 Store 的 published revision/transaction receipt 返回给调用方；`revision_conflict` 必须 fail closed，不得自动重放旧决定。
- 内容读取只允许通过库中现有 document/resource-link `NodeID`；外部文件必须复用 locator integrity、`.withSecurityScope` / `.withoutUI` 与平衡的 security-scope 生命周期。不得扫描相似路径、用 last-known name 匹配文件、复制缓存或读取任意磁盘位置。
- 当前 content tool 只支持有界 UTF-8 text chunk；binary、directory、HTTPS、解析器缺失或 locator 失效必须返回稳定错误，不得静默启用替代 parser/provider。
- 当前工具集合不得加入 permanent delete、外部文件写入、relink、source refresh/mirror 或未授权 document mutation。trash 仍只改变虚拟结构，绝不触碰外部目标。
- 工具调用参数与稳定错误码的事实源是 `docs/TOOL_CALLING.md`；当前 adapter 只做最薄类型转换，不得改写工具语义、结果 envelope 或成功/失败状态。

## 路径与安全边界

- managed layout 只允许 `manifest.json`、`objects/` 与 `.state/` 下由常量和 canonical UUID 构造的路径。
- root、managed directories、manifest、previous manifest 与 payload 必须拒绝 symbolic link / alias；manifest 与 payload hard link 必须拒绝。
- 所有构造 URL 必须保持在 standardized package root 内；不得接受 manifest 中的绝对 path 或相对 path component。
- manifest 与 payload read 必须有 byte upper bound；payload read 必须验证 exact byte count 与 SHA-256。
- validator 必须保持 node/resource count、title/media/content-type 长度、node/resource shape、unique ID/child/object、node→resource 完整性、orphan resource、cycle、multiple-parent 与 active/trash overlap 检查。
- corruption/security error 必须显式返回，不得跳过检查以让 UI 继续显示旧 cache。

## 工程与资源边界

- `Package.swift` 与 `project.yml` 的 minimum macOS target 均保持 26.0，除非用户明确修改平台范围。
- `project.yml` 是 Xcode project 事实源；新增/删除 source/resource 后必须重新生成 `Kuzio.xcodeproj`，不得长期手工维护冲突的 pbxproj。
- SwiftPM 与 XcodeGen 的 Intatis local-package path 和六个实际 product dependencies必须保持一致；`Kuzio.xcodeproj` 只能由 `project.yml` 重新生成对应 `XCLocalSwiftPackageReference`，不得手工接入另一份 package。
- XcodeGen 必须把唯一 Intatis `.intatis/runtime-kit/0.66/CodexRuntime` folder 直接作为 App resource，最终 bundle 同时含 arm64/x86_64 exact runtime、manifest、SHA inventory、SPDX 与完整 licenses。SwiftPM 只承担源码编译/测试，不得用 PATH 或系统 `codex` 冒充正式 App bundle runtime。
- `Package.resolved` 只锁定 Intatis manifest 的远程传递 package 版本；不得把本地 Intatis checkout 复制进 Kuzio、改写为远程 pin，或把生成缓存当成 shared runtime 事实源。
- `.build/` 与 `DerivedData/` 是生成物，不得提交或作为源码事实依赖。
- 除已确认的 Intatis shared dependency 外，不引入新 package、构建脚本、外部服务或 schema migration，除非用户明确确认 exact 依赖与范围。

## 本机安装与升级边界

- 本机正式使用路径固定为 `~/Applications/Kuzio.app`；安装 bundle 是 Release 生成物，不得提交或反向作为源码事实。
- 用户确认的重大版本更新完成后，必须先通过相称测试和全新 Release build，再保持同一 Developer ID Application 签名身份、hardened runtime 与 secure timestamp 更新安装版；不得安装 Debug、preview、临时 bundle ID 或旧产物。
- 更新后必须验证 bundle identifier、版本/build、arm64/x86_64 架构、`codesign --verify --deep --strict`、字体资源，并从安装路径启动，确认 production 默认库和至少一个真实外部链接可访问。
- Release 签名顺序固定为：分别签 arm64/x86_64 nested `codex`（同一 Developer ID、hardened runtime、secure timestamp）→ 按 Intatis packaging 规则刷新每个 `runtime-manifest.json.binary_sha256` 与完整 `SHA256SUMS.txt` → 签 outer App。随后必须对两个 runtime 单独 strict verify、运行 `validate-codex-runtime.sh`，再验证 outer seal；只运行 `codesign --deep` 不足以证明 x86_64 nested code 已签。
- 安装/升级只替换 App bundle，不得删除、替换、重建或迁移用户 Application Support 下的 `Default.kuzio`。发现旧签名 bookmark 不兼容时必须显式处理，不得退回 last-known raw path 或复制外部目标。
- 同一签名身份、secure timestamp 服务不可用，Release build 失败或上述验证失败时必须停止更新并保留现有安装版；不得用 ad-hoc 或无时间戳签名冒充完成。

## 验证要求

- 文档改动至少运行 `git diff --check` 与 `git status --short`。
- 文件系统代码改动至少运行 `swift test` 和 Xcode Debug App build；resource-link 改动还必须覆盖 v1→v2 migration、tree/target independence、alias lifetime、single/batch relink identity、partial-batch rejection、locator integrity、协调读取与陈旧 store GC。
- 前端改动必须实际检查：sidebar 品牌/行高、全局字体、Finder folder icon、每个 36pt control、可见圆面边缘坐标点击、Light/Dark、长短/单双行名称的等尺寸 folder grid、reader、trash 与 sheet。resource-link 改动还必须检查单一 `+`、文件/文件夹多选、取消/确认、递归层级、空目录、single/batch relink、单 transaction、无重复 node、嵌套文件打开、manifest 无 absolute root path 与原文件未变。
- Cowork 改动至少覆盖：process-first Kuzio host identity、session identity readback、Intatis-owned fixture config→redacted exact route、read-only dynamic tool names/schema/result、stable session root、selected NodeID instructions无raw path/credential、43-test suite、单一 `WindowGroup` + library/harness split、源码证明 `CoworkShell` direct mount且Harness view无`TextEditor`/ScrollView/confirmation dialog/Kuzio controls、空态不启动runtime、Xcode Debug/Release、双架构runtime static/signature/integrity、Light/Dark folder/file entry、SharedUI composer ready、close/shutdown无残留process，以及installed production revision/真实链接/ready。没有实际发送的模型turn、child delegation、tool callback或approval round trip必须明确标为未验证。
- 字体改动必须核对 App bundle只含 IntatisSharedUI 两个 variable TTF + Kuzio OFL、两个checksum、PostScript registration和中英混排glyph fallback；旧四静态TTF不得进入bundle。
- 未实际运行的验证必须明确标为未验证；旧构建结果不得冒充最新源码结果。

## 外部依赖与禁止兜底

- Codex runtime 能力只能直接使用 Intatis v1 public host surface；Kuzio 不得重写 App Server protocol/process/agent loop，也不得复制 shared kernel source。Intatis checkout 不存在、v1 major 不匹配或 exact products 无法构建时必须停止并明确报告。
- 已选择的外部能力必须直接使用官方 API/扩展点；不得新增替代 adapter、shim、compatibility layer、wrapper、proxy、facade、parallel backend、preview backend 或 shadow implementation。
- exact dependency 因版本、构建、签名、许可证、平台或安全限制不可用时，必须停止该能力并报告 blocker；不得静默切换。
- 安全 fail-closed 与显式 schema migration（未来若获授权）必须保持最窄范围，不能演化为第二套产品实现。
