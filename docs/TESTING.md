# TESTING

最近自查日期：2026-08-24

## 当前验证状态

- 本轮已运行 repository path check、source/resource audit、font source checksum、`xcodegen generate` 与 `git diff --check`。
- 用户提供的 Xcode 构建截图显示 `NSWorkspace.shared.icon(forContentType: .folder)` 参数标签错误，SDK diagnostic 要求 `for:`；源码和 API 文档已统一修为 `NSWorkspace.shared.icon(for: .folder)`。
- 2026-08-24 最新字体、原生图标、重新校准的 36pt macOS control、协调读取和垃圾回收改动之后，尚未运行 `swift build`、`swift test` 或 `xcodebuild`。
- 原因：当前会话此前的 build approval 已达到限制，系统要求在用户明确允许后才能再次运行构建；不得用 `swiftc`、另一编译器或 sub-agent 绕过。
- 所以下文命令是验证合同，不是本轮已经通过的结果。

## 环境与工程

- 产品平台：macOS 26+。
- SwiftPM manifest：swift-tools-version 6.2。
- Xcode target setting：Swift 6.0，deployment target 26.0。
- XcodeGen：本轮已使用本机 2.45.4 根据 `project.yml` 重新生成 `Kuzio.xcodeproj`。
- production runtime 没有第三方 Swift package；bundled font dependency 见 `docs/FONT_DEPENDENCY.md`。
- 不需要 `.env`、token、账号凭据或 Keychain 读取。

## 构建合同

SwiftPM 编译：

```sh
swift build
```

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

## Swift 测试合同

```sh
swift test
```

`LibraryStoreTests.swift` 当前有 18 个测试方法，覆盖：

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

当前没有 XCUITest；不得把 Swift unit/filesystem tests 描述成窗口或 accessibility 验证。

## 字体资源验证

Source checksum：

```sh
shasum -a 256 \
  Sources/KuzioApp/Fonts/JetBrainsMono-Regular.ttf \
  Sources/KuzioApp/Fonts/JetBrainsMono-Medium.ttf \
  Sources/KuzioApp/Fonts/JetBrainsMono-SemiBold.ttf \
  Sources/KuzioApp/Fonts/JetBrainsMono-Bold.ttf
```

锁定结果：

| 文件 | SHA-256 |
| --- | --- |
| Regular | `a0bf60ef0f83c5ed4d7a75d45838548b1f6873372dfac88f71804491898d138f` |
| Medium | `31c92d01a8a08528b718a43addf0ad3df0af2ca4b7b3290a452f70f358e14d3d` |
| SemiBold | `1b3bfa1ed5665a4ce3f9feb68d2d4e40e70bf8b4b7d9a3edd418f321b4e166a0` |
| Bold | `5590990c82e097397517f275f430af4546e1c45cff408bde4255dad142479dcb` |

成功构建后还必须验证：

```sh
find DerivedData/Build/Products/Debug/Kuzio.app -path '*/Fonts/JetBrainsMono-*.ttf' -print
shasum -a 256 DerivedData/Build/Products/Debug/Kuzio.app/Contents/Resources/Fonts/JetBrainsMono-*.ttf
```

Runtime 验收：

- App init 的四项 resource checksum 与 Core Text registration 不触发 fatal diagnostic。
- PostScript names 为 `JetBrainsMono-Regular`、`JetBrainsMono-Medium`、`JetBrainsMono-SemiBold`、`JetBrainsMono-Bold`。
- 中英混排的 Latin run 使用 JetBrains Mono，CJK run 继续使用系统 PingFang；SF Symbols 仍使用 system symbol font。
- source 中剩余 `.font(.system...)` 只能位于 `Image(systemName:)` 的 symbol size/weight 路径。

## 静态 UI 边界检查

```sh
rg -n 'Capsule|capsule|LinearGradient|RadialGradient|AngularGradient|Color\\(|\\.shadow\\(|folder\\.fill' \
  Sources/KuzioApp --glob '*.swift'

rg -n '\\.font\\(\\.system' Sources/KuzioApp --glob '*.swift'

rg -n -B 14 -A 5 '\\.buttonStyle\\(\\.glass\\)' \
  Sources/KuzioApp --glob '*.swift'
```

预期：

- 第一条无结果。
- 第二条结果都对应 SF Symbols，不对应 `Text` / `TextField` / `TextEditor`。
- 每个 glass icon control 都在 button style 外层使用 `KuzioControlMetrics.iconButtonSize` 36pt frame，并使用 15pt symbol；label 本身不得再塞入 44pt frame。
- folder tile、move sheet 与 trash folder 都调用 `SystemFileIconProvider.folder()`。

## 文件系统静态检查

```sh
rg -n 'type|subject|chapter|topic|录音|转写|AI|Recording|transcript' \
  Sources Tests --glob '*.swift'

rg -n 'LibraryCatalog|LibraryPreviewCatalog|folder\\.fill' \
  Sources Tests --glob '*.swift'
```

允许的 `type` 只应是 Swift 类型语义、media type 或 metadata label；不得出现固定课程层级 schema 或旧内存 catalog。

## 手动窗口验收矩阵

使用最新成功构建的 App：

```sh
open -n DerivedData/Build/Products/Debug/Kuzio.app --args -KuzioPreviewData -KuzioAppearanceLight
open -n DerivedData/Build/Products/Debug/Kuzio.app --args -KuzioPreviewData -KuzioAppearanceDark
```

| 场景 | 必查事实 | 最新状态 |
| --- | --- | --- |
| sidebar brand | `Kuzio` 为 28pt JetBrains Mono semibold，单行 header 为 18/22/12 padding | 待运行 |
| global typography | Latin/数字统一字体；中文正常回退、无 tofu | 待运行 |
| native folder icon | folder tile 为 Finder 原生 icon，无 `folder.fill` | 待运行 |
| icon controls | 所有 header/trash action 为 36pt control / 15pt symbol，无二次放大 | 待运行 |
| native surfaces | sidebar/window/sheet 由系统 surface 拥有，无自定义背景 | 待运行 |
| Liquid Glass | 只出现 Apple 原生 glass，Light/Dark 均清晰 | 待运行 |
| arbitrary depth | 连续进入多层 folder，breadcrumb/history 正确 | 待运行 |
| CRUD | create、rename、move、edit、trash、restore、delete 更新 UI | 待运行 |
| reader | Markdown/纯文本阅读、选择、编辑、保存正常 | 待运行 |
| persistence | 退出重开后默认 package 内容与稳定 ID 保持 | 待运行 |
| error state | conflict/corruption 显式报错，不出现 preview fallback | 待运行 |

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
