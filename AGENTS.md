# Kuzio 项目常驻上下文

本文件继承 `/Users/vita/Vitemis/AGENTS.md` 中的 Vitemis 通用 Agent 规则。若本文件与通用规则冲突，在不违反系统和用户指令的前提下，以更具体、更严格的项目规则为准。

本文是 AI Agent 每轮进入本仓库时的入口文件。执行任何代码修改、配置修改、构建脚本修改或测试源码修改之前，必须先按顺序阅读并核对下列文档：

0. `/Users/vita/Vitemis/AGENTS.md`
1. `docs/CURRENT_STATE.md`
2. `docs/PROJECT_MAP.md`
3. `docs/ARCHITECTURE.md`
4. `docs/DO_NOT_BREAK.md`
5. `docs/TESTING.md`
6. `docs/NEXT_TARGET.md`（如果存在）

如果文档与源码、工程配置、测试或脚本冲突，必须以当前源码和配置为准，并在最终报告中明确指出冲突位置和采用源码为准的原因。

## 工作目录检查

每轮开始先在项目根目录执行：

```sh
pwd
git rev-parse --show-toplevel
git status --short
```

要求：

- `pwd` 与 `git rev-parse --show-toplevel` 必须指向同一个仓库根目录：`/Users/vita/Vitemis/Virgo/Kuzio`。
- 如果当前目录不是 Git root，停止修改，只报告路径问题。
- 读取 `git status --short` 后，先区分用户已有改动与本轮计划改动；不得覆盖、回退或清理用户已有改动。

## 修改边界

本仓库当前已确认首个产品面：macOS 26 SwiftUI 通用层级资料库前端。未来常规任务可以按用户要求修改业务源码；但在只要求项目自查或文档更新的任务中，只允许修改：

- `AGENTS.md`
- `CLAUDE.md`
- `GEMINI.md`
- `docs/` 下的项目说明文档

除非用户明确要求，不要修改或创建：

- `.git/` 内部文件。
- 尚未由用户确认的业务源码目录、构建清单、依赖清单、工程文件或发布配置。
- `claude-report/`、`gemini-report/`、`cursor-report/` 中属于其他审查副驾驶的报告。

## 禁止事项

- 不执行破坏性 Git 操作：`git reset --hard`、`git clean -fd`、`git checkout .`、强制 push、删除用户未提交文件。
- 未经用户明文要求具体 Git 操作，不 add、不 commit、不 push、不创建 PR；编辑、整理、修复、验证或准备工作都不等于提交请求。
- 若用户要求提交，只提交当前 Git root 中与本任务相关的文件；不得递归进入、暂存、提交或推送子仓库、submodule、nested Git repo 或依赖 checkout。
- 不引入新依赖，不改构建脚本，不改测试源码，除非任务明确要求。
- 不把密钥、token、证书私钥、shared secret、账号密码、完整指纹、完整 API 响应、完整转写文本或个人隐私路径写入文档。
- 不得把模板占位内容、推测或示例当成已经确认的产品要求。
- 在用户确认产品范围、目标平台和技术栈前，不得自行选择语言、框架、构建系统、存储方案、通信协议或外部服务。

## 外部依赖优先与禁止兜底

- 本项目继承 `/Users/vita/Vitemis/docs/DEPENDENCY_POLICY.md`。当用户指定、仓库已经采用，或经许可证、provenance、安全与平台审查可采用的外部依赖提供同等能力时，必须直接集成其官方 API 或官方扩展点。
- 不得自行重写同等能力，不得新增替代 adapter、shim、compatibility layer、wrapper、proxy、facade、parallel backend、preview backend、shadow implementation 或“先兜底、以后再换”的路径。
- 本地代码只允许保留官方 API 必需的最薄生命周期、类型、权限、配置和 bundle 接线；不得重新实现、解释或替代依赖的核心能力。
- exact 依赖因版本、构建、签名、许可证、平台、安全或官方 API 限制暂时无法接入时，必须停止该能力、明确报告 blocker 并请求用户决定；不得静默降级、切换技术或继续交付不完整替代实现。
- 现有 fallback/重复实现不得继续扩展；安全 fail-closed 与明确要求的旧数据解码/迁移不是功能兜底，但必须保持最窄范围。

## 下一目标

- `docs/NEXT_TARGET.md` 是临时下一目标记录，只允许保留一个经用户确认的 active target。
- 目标完成或不再有效后必须删除该文件；不得把待办清单、长期路线图或未经确认的想法堆入其中。

## 本机安装合同

- 本机正式使用的 App 固定安装为 `~/Applications/Kuzio.app`；安装产物是本地生成物，不提交 Git，也不得成为源码事实源。
- 每次用户确认的重大版本更新完成后，必须先通过相称测试与全新 Release App build，再使用同一套本机 Developer ID Application 身份、hardened runtime 与 secure timestamp 签名，更新该安装路径，并从安装路径启动验收；用户不需要打开 Xcode 或手动构建。
- 更新后至少核对 bundle identifier、版本/build、架构、签名、字体资源，以及 production 默认库和一个真实外部资源链接。不得用 Debug、`-KuzioPreviewData`、临时 bundle ID 或旧构建产物覆盖安装版。
- app-scoped bookmark 与签名身份相关；后续更新不得改用 ad-hoc 或另一签名身份。所需身份不可用时必须停止安装并报告，不得通过 raw path、复制外部文件或其他兜底绕过。
- App bundle 现包含 `Contents/Resources/CodexRuntime/{arm64,x86_64}` exact runtime。Release 必须分别用同一 Developer ID + hardened runtime + secure timestamp 签两个 nested `codex`，按 Intatis 官方 packaging 顺序刷新各自 `runtime-manifest.json` 的 `binary_sha256` 与完整 `SHA256SUMS.txt`，再签顶层 App；只用 `codesign --deep` 不足以证明 x86_64 nested runtime 已签。两个架构都必须通过 Intatis `validate-codex-runtime.sh`、独立 strict signature 与最终 outer seal 验证。
- 安装或升级 App bundle 不得删除、替换或迁移用户 Application Support 下的 production 资料库；本地安装合同不等于已完成公证、发布或 App Sandbox 配置。

## 项目理解要求

修改前至少确认：

- 产品 target：macOS 26 `Kuzio` App；入口为 `Sources/KuzioApp/KuzioApp.swift`。
- 工程：`Package.swift` 提供 SwiftPM executable/test 入口；`project.yml` 通过本机 XcodeGen 2.45.4 生成 `Kuzio.xcodeproj` 正式 App target。
- UI 链路：`KuzioApp` 的单一主 `WindowGroup` → `LibraryRootView` → 系统 `NavigationSplitView`（稳定 destination sidebar）→ detail 内原生 `HSplitView`；左栏是 `LibraryBrowserPage` / `LibraryReaderView` / `LibraryTrashView` 学习库，右栏是 Cowork Harness。
- 数据链路：`LibraryBootstrap` → actor `LibraryStore` → schema v2 `manifest.json` + UUID payload/locator objects → `LibrarySnapshot` → `LibraryViewModel` → 任意深度 virtual folder/document/resource-link 投影；已知 schema v1 只允许事务迁移到 v2，DEBUG-only `-KuzioPreviewData` seed 不是 production fallback。
- AI 对话链路：folder/document/resource-link 的既有 context menu（以及 document reader 的“更多”菜单）→ `KuzioCoworkConversationTarget` → `LibraryRootView.coworkTarget` → 右栏 `KuzioCoworkHarnessHost` → dependency-owned `IntatisSharedUI.CoworkShell`；Kuzio host model 只把 selected context、runtime lifecycle 与 public `CodeItem` / `CoworkAgentThreadSnapshot` 输入接到共享 UI，再由 `KuzioCoworkRuntimeProfile` → `CodexRuntimeConfiguration(mode: .cowork)` → `CodexAppServerSession`。不得在 Kuzio 重新实现 transcript、composer、permission card、Inspector、Markdown/rich renderer、scroll coordinator 或 status rail。启动前右栏只能显示占位且不得预启动 runtime；每次显式激活 request 使用稳定 `cowork_<request-uuid>` session identity。关闭右栏、替换 target 或关闭主窗口必须 shutdown runtime，不能遗留 App Server process；不得恢复第二个 AI `WindowGroup`。
- App 进程入口必须在任何 Intatis storage/provider/tool/SharedUI/runtime 对象前只调用一次 `IntatisHostApplication.configure(name: "Kuzio")`，并把冻结的 `IntatisHostApplicationIdentity` 显式传入 session configuration；runtime/session namespace 使用 Kuzio identity。推理设置按用户确认继续只读 Intatis-owned canonical config，通过 `IntatisHostApplicationIdentity.intatis` 派生 `INTATIS_CONFIG`、`.config/intatis` 与 Application Support candidates；Kuzio 不新增 API Key/provider/model 设置 UI，不写入或迁移 Intatis config，不把 credential/base URL 写入 argv、session instructions、runtime files、日志、文档或错误明细。缺失/不兼容配置必须明确失败，不切 provider、默认 key 或另一 runtime。
- 选中项上下文只把 `NodeID`、kind、title 与 virtual path 写入 owner-only session workspace `AGENTS.md`；不得写 raw external path、bookmark/locator 或 manifest fragment。`KuzioCodexLibraryTools` 只把 `read_structure` / `read_content` 三个现有 provider tools 直接投影为 `CodexRuntimeDynamicTools`，当前 Cowork 对话不得广告或执行 library mutation。
- 资源链接核心合同：`NodeID` 只表示库内虚拟位置，`ResourceID` 表示外部资源身份，`ImportID` 只关联一次文件夹导入批次，immutable locator object 只表示访问定位；真实文件/云端目录结构不得成为 Kuzio hierarchy truth。选择文件夹时只把当时可见目录递归投影为虚拟 folder tree，并为每个文件创建链接；投影完成后 rename/move/trash/delete 只改变虚拟节点，永久移除链接绝不删除外部目标，也不 watch 或自动同步真实目录。显式重新链接只替换 locator，保持虚拟结构与 node/resource identity。
- 重新链接 UI 只允许复用项目右键菜单中的单一“重新链接”操作和原生 `NSOpenPanel`；不得增加状态文案、说明页、徽标、提示卡片或额外确认弹窗。
- UI 禁区：不引入品牌色、自定义渐变、自绘玻璃、胶囊、装饰性阴影或自制图标；只使用系统语义表面、SF Symbols、`NSWorkspace` 原生文件图标与 Apple 原生 Liquid Glass API。
- 字体：拉丁字母、数字与技术文本统一使用 `IntatisSharedUI` resource bundle 随 App 分发并 fail-closed 注册的官方 JetBrains Mono `v2.304` upright/italic variable TTF；中文由系统字体级联回退为苹方。仓库中旧四档静态 TTF 已从 SwiftPM/Xcode resource graph 排除，不得注册、打包或作为 fallback；Kuzio 只额外分发 OFL 文本。checksum、许可证与边界见 `docs/FONT_DEPENDENCY.md`。
- macOS 圆形图标按钮：按 Rokurics Mac 源码保持 36pt control / 15pt SF Symbol；不得误用共享移动端的 44pt / 18pt 指标，也不得退回只有 glyph 大小的默认小按钮。
- 任何新建工程、模块、入口或依赖都必须来自用户明确需求，并同步更新 `docs/PROJECT_MAP.md`、`docs/ARCHITECTURE.md`、`docs/CURRENT_STATE.md`、`docs/DO_NOT_BREAK.md` 与 `docs/TESTING.md` 中受影响的事实。

不确定的模块必须标注 `UNKNOWN` 或 `需要后续确认`，不要编造。

## 文档索引

- `docs/PROJECT_MAP.md`：目录、target、入口、关键文件和生成物地图。
- `docs/ARCHITECTURE.md`：总体架构、主要链路、数据模型和安全机制。
- `docs/CURRENT_STATE.md`：当前真实状态、已有能力、风险、工作区改动。
- `docs/TESTING.md`：环境、构建、测试、lint/format 与手动验证方式。
- `docs/DO_NOT_BREAK.md`：工程禁区、数据格式、协议、路径和回归要求。
- `docs/NEXT_TARGET.md`：临时下一目标记录；目标完成或不再有效后删除。

## 完成标准

完成任务前至少做到：

- 说明本轮实际阅读/检查过哪些源码、配置或测试。
- 只修改任务范围内文件。
- 保留用户已有改动。
- 运行与任务相称的检查；文档任务至少运行 `git diff --check` 与 `git status --short`。
- 将本轮已完成的持久性改动及时回写到相关项目文档；若无需更新文档，最终报告说明原因。
- 如未运行构建或测试，最终报告必须明确写“未运行构建/测试”。

## 最终报告格式

最终报告建议包含：

1. `MODEL_CHECK_RESULT`：当前模型名称；无法确认时写无法确认。
2. `PATH_CHECK_RESULT`：`pwd`、Git root、是否匹配预期。
3. `FILES_WRITTEN`：新增/修改文件。
4. `PROJECT_AUDIT_SUMMARY`：识别到的项目结构、主要模块和关键链路。
5. `DOCS_CONTENT_SUMMARY`：各文档内容摘要。
6. `VALIDATION_RESULT`：实际运行命令与结果。
7. `UNCERTAINTIES`：无法确认、需要人工确认的点。
8. `NEXT_RECOMMENDED_ACTION`：下一步建议；不要自动继续改业务源码。
