# TESTING

最近自查日期：2026-08-31

## 当前验证状态

- 2026-08-31 presentation-only `IntatisCoworkUI`接入已运行SwiftPM graph、`swift build --disable-automatic-resolution`、43-test `swift test --disable-automatic-resolution`、XcodeGen 2.45.4、Xcode Debug与全新universal Release App build，全部通过、0 failures。测试锁定Runtime/UI public API v1、七个direct products、多个fixture model→secret-free inference options、切换route仍保持同一session/workspace/runtime root与`com.vitemis.kuzio.library-tools.cowork.v2`完整8-tool surface，以及Kuzio Harness不再直接组装`CoworkShell`、自制model menu或xmark。Light/Dark隔离Debug窗口AX与截图确认`cowork.harness.intatis-cowork-ui`、完整Intatis右侧、当前配置的多provider/model菜单、选择标签更新、未发送composer ready、无额外叉号；target由“数学”替换为“计算机科学”后只有一个当前Debug App Server，关闭窗口后Kuzio App Server全部drain。
- 同轮Release为`0.5` / build `2`、arm64/x86_64 universal；两个nested Codex分别使用与旧安装版相同的Developer ID、hardened runtime、secure timestamp签名，刷新manifest/SHA inventory后签outer App。三份strict signature、两架构`validate-codex-runtime.sh`、outer seal、fresh/staging/installed executable equality、SharedUI两项variable font checksum、OFL与旧静态字体排除均通过。`~/Applications/Kuzio.app`已更新；production root、真实`Syllabus.md`外部链接、`UCB-CS61A` Intatis UI/model menu/composer ready和window-close process drain通过，随后App留在资料库首页。production revision 17、578 nodes、457 resources与manifest SHA-256全程不变。未发送模型turn，因此切换模型后的真实远端请求、model-driven dynamic tool callback、child与逐工具approval仍未验证。
- 2026-08-30 v0.5（build 1）已运行 SwiftPM graph、`swift build`、`swift test`、XcodeGen 2.45.4、Xcode Debug 与独立 DerivedData 的全新 universal Release build：43 tests / 0 failures。Release bundle identifier `com.Vita0818.Kuzio`、arm64/x86_64、SharedUI 两个 variable TTF checksum、Kuzio OFL 与旧静态字体排除均通过。两架构 nested Codex 分别使用与旧安装版相同的 Developer ID Application、hardened runtime、secure timestamp 签名；刷新两份 runtime manifest/SHA inventory 后签 outer App，三份 strict signature、outer seal、两个 `validate-codex-runtime.sh` static validation 与 installed/fresh executable equality 均通过。`~/Applications/Kuzio.app` 已原子更新；正式路径启动后 root/动态文件夹标题、真实 PDF 系统打开、Notes Cowork composer ready、未发送草稿关闭和 runtime drain 通过。production revision 17、578 nodes、457 resources 与 manifest SHA-256 `a045…f703` 全程不变。未发送模型 turn，model-driven mutation callback 与逐工具 approval 未验证。
- 2026-08-30 Cowork mutation tool registration 已运行 `swift build`、`swift test` 与 Xcode Debug App build：43 tests / 0 failures，正式 App target 编译成功；Xcode 只报告 Intatis checkout 既有 `ChatLoop.swift` unused-result warning。`KuzioCodexLibraryTools` 与实际 `CodexRuntimeDynamicTools.specs` 按固定顺序逐个包含完整 8 个最小工具，并使用不同于旧 read-only surface 的 `com.vitemis.kuzio.library-tools.cowork.v2` toolset ID；测试经同一薄 bridge 执行一次 `library_create_folder`，published revision 只增加 1。session instructions 锁定“一工具一最小操作”、使用最近 revision、`revision_conflict` 后重读及外部目标禁止写入。该轮不修改 Intatis；真实 model-driven App Server mutation callback、逐工具 approval、Light/Dark runtime window 与正式 Release/安装尚未运行。
- 2026-08-30 browser hierarchy/title polish 已运行 `swift build`、`swift test` 与 Xcode Debug App build：43 tests / 0 failures，正式 App target 编译成功。SwiftPM 初次在沙箱内被既有 `sandbox-exec: sandbox_apply: Operation not permitted` 阻止，随后按权限流程在沙箱外成功完成。唯一临时 bundle ID、ad-hoc 签名、隔离 `-KuzioPreviewData` 的 Light Debug App 已确认 root 大标题为“资料库”，进入“数学”后大标题为“数学”，breadcrumb、Finder icons、36pt controls、sidebar 与固定 152pt grid 不变。resource-link title 的 `.middle` 与完整标题 `.help` 已由静态源码和两套 build 覆盖；Computer Use 在继续进入 production-read-only PDF 层时 native pipe 关闭，所以本轮 Dark appearance、实际中间截断截图和 hover tooltip 弹出仍标为未完成，不复用旧窗口证据冒充当前结果。
- 2026-08-28 最新Intatis host-identity/SharedUI适配已运行`swift build`、`swift test`、XcodeGen 2.45.4与Xcode Debug App build：43 tests / 0 failures。测试锁定process-first `IntatisHostApplication.configure(name: "Kuzio")`、session frozen identity、Intatis-owned shared config、六个direct products、唯一`WindowGroup`、`HSplitView`、direct `CoworkShell`，并拒绝Harness源码中的`TextEditor`/ScrollView/confirmation dialog/Kuzio controls。编译只有Intatis checkout既有unused/deprecated warnings，Kuzio无warning/error。
- Light/Dark最新DEBUG preview均只有一个标准窗口：启动时左学习库、右`Cowork Harness`空态且无runtime；folder“数学”的“AI对话”在同窗右栏显示dependency AX identity `cowork.harness.intatis-shared-ui`、标题、SharedUI `Give Main a project task...` composer、Send与close。只填写不发送本地草稿后Send启用，证明Intatis-owned config和Kuzio host-identity session ready；清空草稿并close后恢复空态。两轮空session已移入废纸篓，关闭后无Kuzio bundled runtime process。
- Debug与Release App bundle都只含`Intatis_IntatisSharedUI.bundle`中的upright/italic两个variable TTF（SHA-256分别`662a…016`/`f115…3f2`）与Kuzio OFL；没有旧四静态TTF。全新Release为arm64/x86_64 universal；两个nested Codex分别用同一Developer ID、hardened runtime、secure timestamp签名，刷新manifest/SHA inventory后签outer App。三份strict signature、两架构`validate-codex-runtime.sh`与outer seal均通过。
- `~/Applications/Kuzio.app`已原子更新；bundle identifier `com.Vita0818.Kuzio`、`0.1` / build `1`、universal架构、SharedUI字体、runtime inventory与installed/fresh executable equality通过。从正式路径启动后production三门课程与`Syllabus.md`可见，真实链接打开无Kuzio错误；`UCB-CS61A`同窗右栏逐字确认dependency AX identity/SharedUI composer/Send/close。随后发送无敏感且禁止工具的真实测试消息，SharedUI渲染user text、`READY` root reply、reasoning timestamp与Input 7,163 / Output 23 / Reasoning 21 / Total 7,186 / 4.01s usage，message AX ID为`kuzio.message...`，无tool row/call。close后process drain，session已移入废纸篓。production revision 17、578 nodes、457 resources与manifest SHA-256不变；dynamic tool callback、child delegation与approval request仍未触发。
- 2026-08-27 可组合 `LibraryToolProvider` 完成后已运行 `swift build`、`swift test`、Xcode Debug App build 与独立 derived data 的全新 Release App build：38 tests / 0 failures，正式 App target 构建成功。新增覆盖 capability-scoped definitions/JSON Schema、7 个结构工具的完整 JSON wire 调用链、内容读取默认参数、snake_case/null envelope，以及 unknown/extra/malformed/oversized/unauthorized 调用 fail-closed；该能力没有新增 UI。
- 同轮 Release 保持既有 Developer ID、hardened runtime 与 secure timestamp，`codesign --verify --deep --strict` 通过；`~/Applications/Kuzio.app` 已更新，installed executable 与 fresh Release executable 完全一致，bundle identifier、`0.1` / build `1`、arm64/x86_64 与四个字体 checksum 全部通过。从最终安装路径启动后 production revision 保持 17，三门课程与 `Syllabus.md` 可见，点击既有 `Syllabus.md` 外部链接没有 Kuzio 错误，本轮没有资料库 mutation。
- 2026-08-27 provider-neutral 工具控制面完成后已运行 `swift build`、`swift test`、Xcode Debug App build 与全新 Release App build：34 tests / 0 failures，正式 App target 构建成功。新增测试实际覆盖完整 create-folder/rename/move/trash/restore 调用链、capability 拒绝、stale revision 拒绝、UTF-8 scalar 边界分段，以及通过真实 security-scoped bookmark 读取外部文本文件。
- 同轮 Release 使用与原安装版相同的 Developer ID Application identity、hardened runtime 与 secure timestamp，严格签名验证通过。`~/Applications/Kuzio.app` 已更新，installed executable 与 fresh Release executable 完全一致；bundle identifier、`0.1` / build `1`、arm64/x86_64 与四个 font checksum 全部通过。
- 从安装路径启动后 production revision 保持 17，根目录仍显示三门课程和 `Syllabus.md`；进入 `UCB-CS70/Slides` 后对真实 `lecture1.pdf` 发起系统打开没有 Kuzio 错误，再返回 root。该安装验收没有执行任何工具 mutation，也没有增加 UI。
- 2026-08-27 显式重新链接完成后已运行 `swift test`：30 tests / 0 failures；Xcode Debug App build 与全新 Release App build 均成功。Release 的 bundle identifier、`0.1` / build `1`、arm64/x86_64、四个 font checksum、Developer ID、hardened runtime、secure timestamp 与 `codesign --verify --deep --strict` 均通过，并已更新 `~/Applications/Kuzio.app`。
- 同轮实际窗口确认 file 与 legacy imported folder 的 context menu 都只增加一个“重新链接”；folder-only picker 使用系统默认界面，没有新增说明文案、状态、徽标或额外确认。取消 picker 后 production revision 保持 16。
- 安装版对一个 165-file legacy course 执行 batch relink 后，revision 仅从 16 增至 17，四个 root child `NodeID`、457 个 resource 数量与外部样本 SHA-256 不变；165 个资源获得同一 `ImportID`，manifest 不含 absolute path。退出重开安装版后，重连课程的嵌套文件可通过 `NSWorkspace` 打开。
- 2026-08-26 已重新运行 `swift test`：28 tests / 0 failures；随后从全新 derived data 完成 Xcode Release build，产物为 `0.1`（build `1`）arm64/x86_64 universal app，四个 bundled font checksum 与锁定值一致。
- 同轮 Release 使用本机 Developer ID Application 身份、hardened runtime 与 secure timestamp 签名，`codesign --verify --deep --strict` 通过，并安装为 `~/Applications/Kuzio.app`。已从该路径直接启动、加载 production `Default.kuzio`，确认三门课程与一个根文件可见，根文件和课程中的嵌套 PDF 均可打开。
- 旧链接由 ad-hoc Debug binary 创建，无法跨到稳定签名身份；已把四个旧根节点移到 Kuzio 废纸篓，再由最终安装版从相同外部目标重新链接。外部文件未改变，旧虚拟节点未永久删除。
- 当前安装签名包含 secure timestamp，但未公证；本轮只验证本机安装与启动，不代表对外分发验收。
- 2026-08-26 circle hit target 与 grid tile 尺寸修复后已重新运行 `swift build`、`swift test` 与 Xcode Debug App build；28 tests / 0 failures。共享 label 的 36pt interaction shape 已在 Light 使用 browser Back 左/右边缘、Forward 边缘和 reader Back 左边缘坐标点击通过，并在 Dark 复查 browser Back 左边缘。Light/Dark 隔离 preview 中分别把“数学”临时改为超长两行名称后，它与短名称 folder 的 glass rectangle 宽高一致。
- 2026-08-26 文件夹递归链接完成后已重新运行 `swift build`、`swift test` 与 Xcode Debug App build；28 tests / 0 failures，正式 App target 构建成功。
- 同轮用唯一临时 bundle ID `com.Vita0818.Kuzio.RecursiveFolderValidation`、隔离 preview store 与真实临时目录检查：单一 `+` 打开文件/文件夹多选 panel；一次选择 `Course Alpha` 后，revision 只增加一次，生成 `Empty`、`Notes/Lesson 1.md`、`Slides/lecture01.txt` 与 `README.md`，嵌套文件可打开，manifest 不含 fixture raw path。Light 完成结果窗口检查；Dark 完成入口、选择与实际 transaction 检查。
- 2026-08-26 单一添加入口与 empty-folder icon 修正后已重新运行 `swift build`、`swift test` 与 Xcode Debug App build；26 tests / 0 failures，正式 App target 构建成功。
- 同轮用唯一临时 bundle ID `com.Vita0818.Kuzio.SingleAddValidation` 与隔离 `-KuzioPreviewData` 检查：AX tree 与 Light 窗口均只有一个右上角 36pt `+`，普通点击直接打开标题为“选择文件”的 file-only `NSOpenPanel`。
- 同轮用唯一临时 bundle ID `com.Vita0818.Kuzio.EmptyStateValidation` 的空 production store 检查：Light/Dark 中“此文件夹为空”均使用 Finder 原生 folder icon，右上角均只有一个 `+`。
- 2026-08-25 file-link grid 样式完成后已重新运行 `swift build`、`swift test` 与 Xcode Debug App build；26 tests / 0 failures，正式 App target 构建成功。
- 同轮用唯一临时 bundle ID `com.Vita0818.Kuzio.GridValidation` 与隔离 `-KuzioPreviewData` 检查：Light/Dark 中 file resource-link 与 folder 共用 grid tile，使用 Finder 文件类型图标，只显示文件名；Open Panel 只保留“选择文件”与“添加”。
- 同轮用唯一临时 bundle ID `com.Vita0818.Kuzio.CodexValidation2` 与隔离 `-KuzioPreviewData` 实际检查：Light/Dark 中右上角 36pt `+` 可见且使用系统 circle glass；file-only `NSOpenPanel`、取消选择、根目录创建链接、现有“数学”虚拟文件夹创建链接、保存后点击打开均通过。取消 fixture 保持 revision 13 / 0 resource-link / 0 external-resource；确认 fixture 中两个链接的 parent 分别为“资料库”与“数学”，manifest 不含 `/private/tmp/Kuzio-Link-Validation.txt` raw path；测试文件 SHA-256 前后均为 `fb8edca06a551c01199764681b7eae821e81e17f2de452a1e80618c493353473`。
- 2026-08-24 Rokurics Mac button metric 收敛后已重新运行 `swift build`、`swift test` 与 Xcode Debug App build；26 tests / 0 failures，正式 App target 构建成功。
- 同轮已用隔离 `-KuzioPreviewData` 分别启动 Light/Dark Debug App，实际检查 library navigation/create、sidebar、folder/document card、reader back/edit/save/cancel/more、native create sheet 与 trash restore/delete。测试只在临时 preview package 中创建、trash、restore 一个文档，未访问或修改 production library。
- 2026-08-24 resource-link schema v2 改动后已实际运行 repository path check、`swift build`、`swift test` 与 Xcode Debug App build。
- `swift build` 成功；首次沙箱内 manifest 编译被 `sandbox-exec: sandbox_apply: Operation not permitted` 阻止，按权限流程在用户批准的沙箱外重跑后成功。
- `swift test` 成功：26 tests，0 failures。
- Xcode Debug App build 成功；命令只出现 arm64/x86_64 多 destination 选择 warning，没有 compiler error。
- 2026-08-24 resource-link 轮次没有修改字体资源、`Package.swift`、`project.yml` 或 `Kuzio.xcodeproj`，因此当轮未重新运行 `xcodegen generate`；2026-08-28 dependency 轮次已按当前 `project.yml` 重新生成并验证工程，没有把旧生成物作为源码事实。
- file resource-link、文件夹多选、递归 linked tree、逐文件 bookmark 生成/解析、security-scope 生命周期、嵌套文件打开与 explicit relink 已经完成实际验收。源目录刷新/对账、HTTPS、File Provider 离线状态与 App Sandbox entitlement 仍未验收。

## 环境与工程

- 产品平台：macOS 26+。
- SwiftPM manifest：swift-tools-version 6.2。
- Xcode target setting：Swift 6.0，deployment target 26.0。
- XcodeGen：2026-08-30 使用本机2.45.4根据`project.yml`重新生成`Kuzio.xcodeproj`，保留既有Development Team、bundle identifier与签名设置，当前 Debug/Release为`0.5` / build `2`，并保持Intatis local package、七个实际products、OFL与双架构runtime resource；generated Resources不含旧四静态TTF。
- shared runtime 通过 `../../Intatis` 本地 SwiftPM dependency 直接编译；Kuzio 根 `Package.resolved` 锁定 Intatis manifest 的远程传递 packages。Xcode bundle 直接封装 exact Intatis runtime kit；Kuzio 没有复制 shared kernel source、引入第二 provider/runtime 或使用 PATH runtime 作为正式 App fallback。
- 测试 fixture 不需要真实 `.env`、token、账号或 Keychain；安装版启动 route 时只通过 Intatis config 的 literal/environment/file reference 在进程内解析 credential，验证过程不读取/打印其值。

## 构建合同

SwiftPM 编译：

```sh
swift package dump-package
swift build
```

`dump-package`必须显示local dependency path为唯一`/Users/vita/Vitemis/Intatis` checkout，且`KuzioApp`直接依赖`IntatisCore`、`IntatisProtocol`、`IntatisProviders`、`IntatisConversation`、`IntatisCodexRuntime`、`IntatisCoworkUI`、`IntatisSharedUI`七个实际products。该检查和编译不得读取或输出API credential。

正式 App 工程：

```sh
xcodegen generate
xcodebuild -quiet \
  -project Kuzio.xcodeproj \
  -scheme Kuzio \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

预期 App 产物：`DerivedData/Build/Products/Debug/Kuzio.app`。只有命令成功且产物资源核对通过后，才能把它描述为当前源码的有效 App。

## 本机 Release 安装合同

重大版本更新使用命令行构建，不要求用户打开 Xcode：

```sh
install_derived_data="$(mktemp -d "${TMPDIR:-/tmp}/KuzioInstall.XXXXXX")"
xcodebuild -quiet \
  -project Kuzio.xcodeproj \
  -scheme Kuzio \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$install_derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  ENABLE_DEBUG_DYLIB=NO \
  build
```

Release 产物必须使用与当前安装版相同的本机 Developer ID Application identity、hardened runtime 与 secure timestamp 签名；notarization 尚未写成已完成条件。由于 App 含两个独立架构的 nested Mach-O，签名顺序不能简化为单次 `--deep`：

```sh
release_app="$install_derived_data/Build/Products/Release/Kuzio.app"
codesign --force --options runtime --timestamp \
  --sign 'Developer ID Application' \
  "$release_app/Contents/Resources/CodexRuntime/arm64/codex"
codesign --force --options runtime --timestamp \
  --sign 'Developer ID Application' \
  "$release_app/Contents/Resources/CodexRuntime/x86_64/codex"

# 按 Intatis scripts/package-macos-release.sh 中
# refresh_staged_runtime_integrity 的精确逻辑：
# 1. 更新两个 runtime-manifest.json.binary_sha256
# 2. 重建两个完整 SHA256SUMS.txt

codesign --force --options runtime --timestamp \
  --sign 'Developer ID Application' "$release_app"
codesign --verify --deep --strict --verbose=2 \
  "$release_app"
codesign --verify --strict --verbose=2 \
  "$release_app/Contents/Resources/CodexRuntime/arm64/codex"
codesign --verify --strict --verbose=2 \
  "$release_app/Contents/Resources/CodexRuntime/x86_64/codex"
../../Intatis/scripts/validate-codex-runtime.sh \
  "$release_app/Contents/Resources/CodexRuntime/arm64" arm64
../../Intatis/scripts/validate-codex-runtime.sh \
  "$release_app/Contents/Resources/CodexRuntime/x86_64" x86_64
```

确认 App 未运行后，将已验证 bundle 更新到 `~/Applications/Kuzio.app`，再对安装副本重复签名、版本、架构和字体校验，并从该完整安装路径启动。必须实际打开 production 默认库中的真实外部资源；只看到 library tree 不算安装验收完成。更新失败时保留原安装副本，不修改 production `Default.kuzio`。

## Swift 测试合同

```sh
swift test
```

当前共有 43 个测试：`LibraryStoreTests.swift` 38 个，`KuzioCoworkRuntimeTests.swift` 5 个。原有 18 个方向继续覆盖：

1. create / reopen / copy package 保持 library ID、node ID、revision 与正文。
2. 32 层 folder，证明不存在固定四层上限。
3. rename / move 保持 node ID 与 content revision。
4. folder 不能移入自己的 descendant。
5. trash / restore 保持 subtree 与 ID。
6. permanent delete 只接受 trash root，并清理 payload。
7. stale revision 明确 conflict。
8. concurrent writers 只能一个提交成功，不丢更新。
9. stale store garbage collection 不删除 newer writer payload。
10. stale store document read 重载最新 coordinated manifest。
11. corrupt current manifest 要求显式 previous recovery。
12. payload size/digest corruption detection。
13. trashed node 禁止 rename/update。
14. manifest symlink 拒绝且不读取外部目标。
15. payload symlink 拒绝且不读取外部目标。
16. original parent 已永久删除时要求 explicit restore destination。
17. 包含路径字符的 title 永不进入 filesystem path。
18. root/document mutation target kind boundary。

新增 resource-link 数据层方向：

19. virtual rename/move/trash/permanent-delete 与真实 target bytes 完全解耦；manifest 不含 raw path。
20. 多个 `NodeID` alias 共享一个 `ResourceID`，最后一个 alias 删除前 locator 不得回收。
21. replace locator 保持 `ResourceID`/alias identity，previous manifest 保护旧 locator 后再 GC。
22. schema v1 通过 transaction/previous manifest 迁移到 schema v2，library/node/content 不丢失。
23. locator size/digest corruption detection。
24. HTTPS locator 只接受 credential-free `https`，非法输入不增加 revision。
25. stale store garbage collection 不删除 newer writer locator。
26. stale store external-resource read 重载最新 coordinated manifest。

新增 recursive linked-tree / batch relink 方向：

27. flat draft 在单一 revision/transaction 中生成任意深度 virtual folder、空目录与逐文件 resource-link，reopen 后结构和 locator 保持。
28. batch 中任一 locator 无效时整棵树拒绝，revision、root children 与 object store 均不发生部分写入。
29. virtual folder rename 与 resource-link move 后，batch relink 仍保持 `NodeID` / `ResourceID` / relative origin，并只增加一个 revision。
30. 同一 `ImportID` 的 partial replacement 整体拒绝，revision、locator 与 object store 不变。

新增工具控制面方向：

31. `library_get_state` / `library_list_children` 与 create-folder/rename/move/trash/restore 全部通过控制面落入同一 Store transaction，并保持 virtual identity。
32. capability 缺失与 stale `expected_revision` 在无 mutation 的情况下返回稳定 `permission_denied` / `revision_conflict`。
33. 内部 UTF-8 document 在 multi-byte scalar 边界按 `nextByteOffset` 无损分段。
34. 已链接本机 UTF-8 file 通过真实只读 security-scoped bookmark 和协调读取返回内容，不接受 raw path。

新增工具提供者方向：

35. capability-scoped definitions 完整发布当前 8 个名称、description、required capability 与 `additionalProperties: false` JSON Schema；受限实例只广告已授权工具。
36. `get_state/create_folder/rename_node/move_node/list_children/trash_node/restore_node` 从 JSON arguments 到唯一 Store 的完整 wire 调用链及 snake_case/null success envelope。
37. `read_content` wire 调用只传 `node_id` 时使用 offset `0` / 64 KiB 默认值，并输出稳定 content envelope。
38. unknown name、extra key、non-canonical UUID、oversized JSON 与 capability bypass 分别 fail closed，且不改变 library revision。

新增 Cowork runtime 方向：

39. `KuzioCodexLibraryTools` 与 `CodexRuntimeDynamicTools.specs` 使用 `com.vitemis.kuzio.library-tools.cowork.v2` toolset ID，按固定顺序逐个广告完整 8 个最小工具，并把 `library_read_content` 与单次 `library_create_folder` 真实 provider success envelope 投影成 dynamic-tool result；没有 organize/apply-plan/batch 复合工具。
40. Intatis-owned compatible fixture config经`ChatConfigurationImporter` / `ProviderRegistry`解析成exact Responses routes和多个secret-free inference options，fixture credential只在内存且不会出现在route description/debugDescription；选择另一个model后仍保持同一session/workspace/runtime root和同一8-tool toolset。
41. 每个test先安装`Kuzio` host identity；Runtime/UI public API major固定v1，prepared configuration固定`.cowork`、同一`hostApplicationIdentity`、stable harness-request session identity、`pauseActiveGoalBeforeResume`、独立workspace/runtime root与selected `NodeID` instructions；instructions不含config path/credential。
42. selected target Codable round-trip 保持 `NodeID`、kind、title、virtual path 与 request identity。
43. 主scene只有一个`WindowGroup`；detail使用左学习库/右harness的`HSplitView`，browser/reader通过callback激活target；右栏直接`IntatisCoworkContentView`，Harness host源码不含`CoworkShell`、自制model menu、`IntatisThreadHeaderAction`/xmark、`TextEditor`、ScrollView、confirmation dialog或Kuzio controls，Package/XcodeGen使用相同七产品与SharedUI typography。

当前没有 XCUITest；43 个 Swift tests 不等于窗口验证。单一 `+`、resource linking/relink、Cowork folder/file actions、Light/Dark 单窗口双栏 ready/shutdown、installed production root turn/stream/usage 已包含实际 App 窗口验收；dynamic tool callback、child/approval data plane、File Provider 与 accessibility 全流程仍不得描述为已覆盖。

## 字体资源验证

SharedUI source checksum：

```sh
shasum -a 256 \
  ../../Intatis/Packages/IntatisSharedUI/Sources/Resources/JetBrainsMono\[wght\].ttf \
  ../../Intatis/Packages/IntatisSharedUI/Sources/Resources/JetBrainsMono-Italic\[wght\].ttf
```

锁定结果：

| 文件 | SHA-256 |
| --- | --- |
| upright variable | `662a196d58f1183bf2d77428b6d5283fe3f45161ab021bea4036bc98e5cac016` |
| italic variable | `f115aaa12113718c02ce72864fe6823b87241bc23d3e44cf1220155f861063f2` |

成功构建后还必须验证：

```sh
find DerivedData/Build/Products/Debug/Kuzio.app/Contents/Resources \
  -type f \( -name 'JetBrainsMono*.ttf' -o -name 'JetBrainsMono-OFL.txt' \) -print
find DerivedData/Build/Products/Debug/Kuzio.app/Contents/Resources \
  -type f -name 'JetBrainsMono*.ttf' -exec shasum -a 256 {} +
! find DerivedData/Build/Products/Debug/Kuzio.app/Contents/Resources \
  -type f -name 'JetBrainsMono-Regular.ttf' | grep -q .
```

Runtime 验收：

- App init先安装Kuzio host identity，再调用`IntatisTypography.prepareJetBrainsMonoTypography()`；dependency的两项resource checksum、完整descriptor set、Core Text registration与bundle URL resolution不触发fatal diagnostic。
- App bundle只有一个`Intatis_IntatisSharedUI.bundle`和exactly两个variable TTF，另有Kuzio OFL；旧四静态TTF不得出现。
- 中英混排的 Latin run 使用 JetBrains Mono，CJK run 继续使用系统 PingFang；SF Symbols 仍使用 system symbol font。
- Kuzio source直接使用`IntatisTypography`，不存在`KuzioTypography`文件/引用；剩余`.font(.system...)`只能位于`Image(systemName:)`的symbol size/weight路径。

## 静态 UI 边界检查

```sh
rg -n 'Capsule|capsule|LinearGradient|RadialGradient|AngularGradient|Color\\(|\\.shadow\\(|folder\\.fill' \
  Sources/KuzioApp --glob '*.swift'

rg -n '\\.font\\(\\.system' Sources/KuzioApp --glob '*.swift'

rg -n '\\.buttonStyle\\(\\.glass\\)|\\.buttonBorderShape\\(\\.circle\\)|\\.controlSize\\(\\.large\\)' \
  Sources/KuzioApp --glob '*.swift'

rg -n -B 8 -A 10 'KuzioCircleIconButton\\(|kuzioCircleIconControl|Glass\\.regular\\.interactive\\(\\), in: \\.circle' \
  Sources/KuzioApp --glob '*.swift'

rg -n -F -e 'pageTitle' -e '.truncationMode(entry.isResourceLink ? .middle : .tail)' -e '.help(resourceLink.title)' \
  Sources/KuzioApp/LibraryBrowserView.swift
```

预期：

- 第一条无结果。
- 第二条结果都对应 SF Symbols，不对应 `Text` / `TextField` / `TextEditor`。
- 第三条 circle-style legacy audit 无结果：可见圆面不能再由 intrinsic `.buttonStyle(.glass)` 缩在 36pt layout frame 内，也不需要 `.buttonBorderShape(.circle)` / `.controlSize(.large)`。
- 普通 icon action 通过 `KuzioCircleIconButton`，reader menu trigger 通过同一个 `kuzioCircleIconControl` modifier；`KuzioCircleIconLabel` 自身必须使用 `KuzioControlMetrics.iconButtonSize` 36pt frame 与 circle interaction content shape，共享 modifier 再让同一 frame 承载 Apple official `Glass.regular.interactive()` circle，并应用 0.46 disabled opacity。
- 每个 circle icon control 使用 15pt semibold monochrome symbol 与 8pt 同组间距；menu indicator 隐藏，label 不得再塞入 44pt frame。
- sidebar destination row 必须解析为 13pt symbol / 20pt slot、8pt 图文间距、12×10pt padding、15pt selected glass corner；folder/resource tile 为 58×50pt Finder icon / 52pt icon slot、34pt title slot、13pt detail slot 与 152pt fixed height，document card symbol 为 21pt semibold / 42pt slot。
- folder tile、move sheet 与 trash folder 都调用 `SystemFileIconProvider.folder()`。
- browser title 必须来自 `library.currentFolder?.title` 并在缺失 snapshot 时只回退“资料库”；resource-link 必须命中 `.middle` 与完整标题 `.help`，folder 不得被全局改成中间截断。

## 文件系统静态检查

```sh
rg -n 'type|subject|chapter|topic|录音|转写|AI|Recording|transcript' \
  Sources Tests --glob '*.swift'

rg -n 'LibraryCatalog|LibraryPreviewCatalog|folder\\.fill' \
  Sources Tests --glob '*.swift'
```

允许的 `type` 只应是 Swift 类型语义、media type 或 metadata label；不得出现固定课程层级 schema 或旧内存 catalog。

Resource-link 静态边界：

```sh
rg -n 'resourceLink|ResourceID|StoredLocatorReference|externalResources' \
  Sources Tests --glob '*.swift'

rg -n 'removeItem.*external|delete.*target|rawPath|absolutePath' \
  Sources Tests --glob '*.swift'
```

预期：virtual node 只经 `ResourceID` 连接 external record；locator bytes 只在 object store；不存在删除外部 target 的 mutation 路径。

Tool-control 静态边界：

```sh
rg -n 'library_(get_state|list_children|read_content|create_folder|rename_node|move_node|trash_node|restore_node)' \
  Sources/KuzioApp/LibraryToolControlPlane.swift \
  Sources/KuzioApp/LibraryToolProvider.swift \
  docs/TOOL_CALLING.md

rg -n 'OpenAI|Anthropic|prompt|MCP|URLSession|rawPath|absolutePath' \
  Sources/KuzioApp/LibraryToolControlPlane.swift \
  Sources/KuzioApp/LibraryToolProvider.swift

rg -n 'Intatis(Core|Protocol|Providers|Conversation|CodexRuntime|CoworkUI|SharedUI)|publicAPIMajorVersion' \
  Package.swift project.yml \
  Sources/KuzioApp/KuzioCodexRuntimeIntegration.swift \
  Kuzio.xcodeproj/project.pbxproj

rg -n 'IntatisHostApplication\.configure|hostApplicationIdentity|IntatisHostApplicationIdentity\.intatis|environmentVariable\("CONFIG"\)' \
  Sources/KuzioApp/KuzioApp.swift \
  Sources/KuzioApp/KuzioCodexRuntimeIntegration.swift \
  Sources/KuzioApp/KuzioCoworkRuntimeProfile.swift

rg -n 'mode: \.cowork|CodexRuntimeDynamicTools|readStructure|readContent|mutateStructure' \
  Sources/KuzioApp/KuzioCoworkRuntimeProfile.swift \
  Sources/KuzioApp/KuzioCodexLibraryTools.swift

rg -n 'WindowGroup|HSplitView|cowork\.harness\.empty|onOpenCowork' \
  Sources/KuzioApp/KuzioApp.swift \
  Sources/KuzioApp/LibraryRootView.swift \
  Sources/KuzioApp/LibraryBrowserView.swift \
  Sources/KuzioApp/LibraryReaderView.swift

rg -n 'IntatisCoworkContentView\(|cowork\.harness\.intatis-cowork-ui' \
  Sources/KuzioApp/KuzioCoworkConversationView.swift

rg -n 'CoworkShell\(|IntatisThreadHeaderAction\(|systemImage: "xmark"|TextEditor\(|ScrollView|confirmationDialog\(|KuzioCircleIconButton\(' \
  Sources/KuzioApp/KuzioCoworkConversationView.swift

rg -n 'OPENAI_API_KEY|sk-[A-Za-z0-9]|bearerToken\s*[:=]\s*"' \
  Sources/KuzioApp Package.swift project.yml
```

预期：第一条源码目录、provider definitions与文档tool names完全对应；第二条无结果，证明控制面/provider仍不含runtime/transport。第三条证明SwiftPM/XcodeGen/generated project使用同一七个实际products和Runtime/UI两个API v1 gate。第四条证明入口安装Kuzio identity、session显式冻结它，而shared provider config候选由`.intatis` identity派生。第五条必须同时出现`.cowork`、`readStructure`、`readContent` 与 `mutateStructure`，证明 Cowork 逐个注册完整 capability surface。第六条证明App唯一`WindowGroup`、detail `HSplitView`、稳定空态和callback activation。第七条证明right pane直接mount `IntatisCoworkContentView`；第八条必须无结果，证明Kuzio没有重新组装CoworkShell、model menu或关闭叉号。最后credential检查必须无结果。

## 手动窗口验收矩阵

使用最新成功构建的 App：

```sh
open -n DerivedData/Build/Products/Debug/Kuzio.app --args -KuzioPreviewData -KuzioAppearanceLight
open -n DerivedData/Build/Products/Debug/Kuzio.app --args -KuzioPreviewData -KuzioAppearanceDark
```

| 场景 | 必查事实 | 最新状态 |
| --- | --- | --- |
| sidebar brand | `Kuzio` 为 28pt JetBrains Mono semibold，单行 header 为 18/22/12 padding | Light/Dark 通过 |
| global typography | Latin/数字统一字体；中文正常回退、无 tofu | 本轮可见页面通过 |
| native folder icon | folder tile 与“此文件夹为空”均为 Finder 原生 icon，无 `folder.fill` | Light/Dark 通过 |
| icon controls | 所有 header/trash action 为共享 36pt visible control / 15pt semibold symbol、组间距 8pt；36pt 可见圆面与 interaction hit shape 一致 | browser Back 左/右边缘、Forward 边缘、reader Back 左边缘坐标点击通过 |
| sidebar controls | destination row 为 13pt symbol / 20pt slot、8pt 图文间距、12×10pt padding 与 15pt selected glass corner | Light/Dark 通过 |
| native surfaces | sidebar/window/sheet 由系统 surface 拥有，无自定义背景 | Light/Dark 通过 |
| Liquid Glass | 只出现 Apple 原生 glass，Light/Dark 均清晰 | 通过 |
| arbitrary depth | 连续进入多层 folder，breadcrumb/history 正确 | root → 数学 → 概率论通过 |
| current folder title | root 大标题保持“资料库”；进入子文件夹后 32pt 大标题同步当前 virtual folder，breadcrumb 仍显示祖先路径 | 2026-08-30 Light 隔离 preview：root“资料库”→“数学”通过；Dark 待运行 |
| equal-size grid tiles | 短名称、两行长名称、folder detail 与 resource-link 空 detail 均不改变 glass rectangle 尺寸 | Light/Dark 隔离 preview 长短 folder 名称通过；resource-link 空 detail 由固定槽源码/构建覆盖 |
| long resource-link title | 两行文件名中间截断以保留首尾，hover help 显示完整标题，tile 仍为 152pt | 当前源码/Swift/Xcode build 通过；本轮窗口控制在 PDF 层中断，Light/Dark 截断截图与 tooltip 弹出待运行 |
| CRUD | create、rename、move、edit、trash、restore、delete 更新 UI | 部分通过：create document → trash → restore；rename/move/save/permanent-delete 未运行 |
| reader | Markdown/纯文本阅读、选择、编辑、保存正常 | 部分通过：Markdown 阅读与 edit/cancel 状态通过；save 未运行 |
| persistence | 退出重开后默认 package 内容与稳定 ID 保持 | 待运行 |
| error state | conflict/corruption 显式报错，不出现 preview fallback | 待运行 |
| resource-link picker | 右上角只有一个 `+`，普通点击打开文件/文件夹多选 panel | Light/Dark 隔离 App 通过 |
| recursive folder link | 一次选择生成完整 virtual subtree、空目录和逐文件链接；单 transaction、无 raw path、嵌套文件可打开 | Light 结果窗口通过；Dark transaction 通过 |
| broken/stale resource-link | moved/offline/revoked 明确失败；stale bookmark 保持 identity 并事务更新 | 源码路径已实现；真实 moved/revoked/stale fixture 待运行 |
| explicit relink | file/folder context menu 只有一个“重新链接”；取消不 mutation；batch 一次提交、不重复 node、不改外部文件 | 安装版 165-file legacy batch、重启与嵌套文件打开通过 |
| single-window split | App只有一个标准窗口；detail为左学习库/右harness；空态不启动runtime；激活态右栏必须是dependency `IntatisCoworkContentView`且无Kuzio叉号 | 本轮Light/Dark DEBUG与build 2安装版通过；AX出现`cowork.harness.intatis-cowork-ui` |
| Cowork folder entry | folder context menu首项“AI对话”；同窗右栏默认`.cowork`，Intatis composer/model menu ready | Light/Dark“数学”和installed production `UCB-CS61A`通过：多provider/model菜单可见，选择标签更新，未发送草稿启用Send后已清空；未发送turn |
| Cowork file entry | internal document/resource-link共用context action；reader“更多”复用；selected virtual path正确 | 既有callback源码、43-test与Xcode build覆盖；installed production真实`Syllabus.md`外部链接打开通过，file-target Cowork本轮未单独激活 |
| Cowork model boundary | 配置只读、options secret-free；选择只改变下一次`@main`route；session/workspace/runtime root和8-tool surface不变 | 两模型fixture测试通过；Light真实菜单/标签通过；切换后远端turn未发送 |
| Cowork tool boundary | Kuzio host identity、selected`NodeID` instructions无raw path/credential；8 个独立最小工具；reviewed/read-write session workspace；target替换/window close process drain | fixture tests确认specs/toolset ID顺序、read与单次create callback；Light target替换和window-close后无Kuzio App Server残留 |
| Cowork data plane | root/child streaming、tool callback、approval、usage通过public state/actions/thread source交给IntatisCoworkUI，Kuzio不渲染UI | 旧installed root turn已显示user/`READY`/reasoning/usage；本轮bridge/provider mutation callback由测试覆盖、runtime ready，但未发送turn，model-driven App Server callback、child、逐工具approval未触发 |
| source refresh / HTTPS / File Provider | 不把尚未实现的 refresh、HTTPS picker/open 或 download state 描述为可用 | 待实现 / 待运行 |

无参数启动不覆盖系统 appearance，也不加载 DEBUG seed。

## 文档与 Git 最低检查

```sh
git diff --check
git status --short
```

必须报告所有未提交文件，且不得执行 add、commit、push 或清理。

## 失败分类

- compiler error：保留首个真实 Swift diagnostic，修复后重跑完整测试/build。
- resource error：先核对 `Fonts` folder resource、bundle path、checksum 与 PostScript name，不允许字体 fallback。
- filesystem test failure：区分 manifest invariant、coordination、revision conflict、IO、path/link 与 recovery；不得跳过测试。
- UI runtime failure：必须以最新 `.app` 实际窗口为证据，不能只凭源码宣称视觉完成。
- signing/package failure：与代码编译结果分开报告；不得降低安全设置冒充成功。
