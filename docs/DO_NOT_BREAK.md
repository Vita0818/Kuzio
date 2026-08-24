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
- macOS icon action 固定采用 Rokurics Mac 的 36pt control / 15pt symbol；不得误用共享移动端 44pt / 18pt 指标，也不得退回只有 glyph 大小的默认按钮。
- sidebar 品牌与 App 文本不得散落 `.font(.system...)` 文本路径；`.font(.system...)` 只允许用于 SF Symbols 的 size/weight。
- 不把每个 sidebar row、metadata row 或正文段落包成自定义卡片；sidebar selected row 只允许 Apple rectangular glass，form、sheet、alert 与 split-view chrome 保持原生。

## 字体依赖边界

- exact dependency 固定为 JetBrains Mono `v2.304` 的 Regular、Medium、SemiBold、Bold 四个官方静态 TTF。
- 四个文件不得修改、subset、重命名、重新编码或替换为 variable font/其他版本；checksum 见 `docs/FONT_DEPENDENCY.md`。
- `Fonts/JetBrainsMono-OFL.txt` 必须随 App resource 一起分发。
- SwiftPM 必须保持 `.copy("Fonts")`；XcodeGen 必须保持 `Fonts` folder resource，从而保留 bundle 内 `Fonts/` 相对目录。
- App 启动必须验证 resource SHA-256、使用 Core Text process registration，并验证四个 PostScript name；缺失或不一致必须 fail closed，不得静默回退 system serif、SF Mono、Menlo 或另一字体。
- JetBrains Mono 不含 CJK；中文必须继续由 Apple 字体 cascade 处理，不嵌入或复制苹方。

## Package 与 schema v1 边界

- format identifier：`com.vitemis.kuzio.library`。
- layout version：1；schema version：1；未知版本必须明确失败，不得用当前 decoder 猜测。
- authoritative hierarchy 只来自 manifest 中 folder 的 ordered `children` IDs；不得并存 path-derived tree、第二份 index 或 shadow catalog。
- `LibraryID`、`NodeID`、`ObjectID`、`TransactionID` 必须使用 canonical lowercase UUID 编码。
- title 是 display metadata，不得用于文件名、目录名、object key 或 identity。包含 `/`、`..` 或反斜线的合法 title 仍不得影响 managed path。
- payload object immutable；document update 创建新 `ObjectID`，不得原地覆盖已发布 payload。
- rename、move、trash 与 restore 必须保持 `NodeID`；rename/move 不得改变 content revision。
- folder 层级保持任意深度，不得把 DEBUG seed 的名称或深度固化为 enum/schema。
- production 默认 store failure 不得切换到 DEBUG seed、内存 fixture、alternate backend 或简化路径。

## Transaction、并发与恢复边界

- mutation 必须携带 expected manifest revision；write claim 内必须重读 disk manifest 并再次比较 base revision。
- manifest 发布必须使用 staging + immutable object promotion + atomic replacement；不得先覆盖 authoritative manifest 再写 payload。
- previous manifest 必须在普通 commit 中保存 publish 前状态；permanent delete 必须先消除 previous 对待 purge object 的引用再删除 bytes。
- document read、refresh、purge completion 与 garbage collection 必须在 library root 的 `NSFileCoordinator` claim 内读取同一代磁盘状态。
- garbage collection 不能使用 actor 的陈旧 manifest 直接判断；必须合并最新 current 与有效 previous manifest references。
- current manifest 损坏时不得自动恢复。只有 current 无效、previous 有效时返回 `recoveryRequired`；仅显式 recovery API 可发布 previous。
- cleanup failure 可以报告 `cleanupPending`，但不得伪装成 rollback，也不得删除 current/previous 仍引用的 object。

## 路径与安全边界

- managed layout 只允许 `manifest.json`、`objects/` 与 `.state/` 下由常量和 canonical UUID 构造的路径。
- root、managed directories、manifest、previous manifest 与 payload 必须拒绝 symbolic link / alias；manifest 与 payload hard link 必须拒绝。
- 所有构造 URL 必须保持在 standardized package root 内；不得接受 manifest 中的绝对 path 或相对 path component。
- manifest 与 payload read 必须有 byte upper bound；payload read 必须验证 exact byte count 与 SHA-256。
- validator 必须保持 node count、title/media-type 长度、node shape、unique ID/child/object、cycle、orphan、multiple-parent 与 active/trash overlap 检查。
- corruption/security error 必须显式返回，不得跳过检查以让 UI 继续显示旧 cache。

## 工程与资源边界

- `Package.swift` 与 `project.yml` 的 minimum macOS target 均保持 26.0，除非用户明确修改平台范围。
- `project.yml` 是 Xcode project 事实源；新增/删除 source/resource 后必须重新生成 `Kuzio.xcodeproj`，不得长期手工维护冲突的 pbxproj。
- `.build/` 与 `DerivedData/` 是生成物，不得提交或作为源码事实依赖。
- 不引入新 package、构建脚本、外部服务或 schema migration，除非用户明确确认 exact 依赖与范围。

## 验证要求

- 文档改动至少运行 `git diff --check` 与 `git status --short`。
- 文件系统代码改动至少运行 `swift test` 和 Xcode Debug App build。
- 前端改动必须实际检查：sidebar 品牌/行高、全局字体、Finder folder icon、每个 36pt control、Light/Dark、folder grid、reader、trash 与 sheet。
- 字体改动必须核对 source 与 App bundle checksum、bundle 子目录、PostScript registration 和中英混排 glyph fallback。
- 未实际运行的验证必须明确标为未验证；旧构建结果不得冒充最新源码结果。

## 外部依赖与禁止兜底

- 已选择的外部能力必须直接使用官方 API/扩展点；不得新增替代 adapter、shim、compatibility layer、wrapper、proxy、facade、parallel backend、preview backend 或 shadow implementation。
- exact dependency 因版本、构建、签名、许可证、平台或安全限制不可用时，必须停止该能力并报告 blocker；不得静默切换。
- 安全 fail-closed 与显式 schema migration（未来若获授权）必须保持最窄范围，不能演化为第二套产品实现。
