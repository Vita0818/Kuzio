# TESTING

最近自查日期：2026-08-23

## 环境

- 操作系统 / 平台：项目目标平台 `UNKNOWN`；本次文档初始化环境为 macOS。
- 工具链版本：`UNKNOWN`，尚未选择 Xcode、Swift、Node、Python 或其他工具链。
- 依赖管理：无。
- 凭据 / 配置：当前不需要；不得读取或写入 `.env`、密钥、token、账号凭据或系统 Keychain 内容。

## 构建

当前没有构建清单、构建 target 或构建命令。不得用占位命令冒充可构建状态。

- 配置：不适用。
- 目标：尚未定义。
- 产物位置：尚未定义。

## 测试

当前没有单元测试、UI 测试、集成测试或测试命令。

- 单元测试：无。
- UI 测试：无。
- 集成测试：无。
- 只跑特定测试：不适用。

## Lint / Format

当前没有项目级 lint 或 format 工具。选择技术栈后必须记录实际命令，未经用户明确要求不得为此擅自引入依赖。

文档任务的最低验证命令为：

```sh
git diff --check
git status --short
```

## 手动验证矩阵

| 场景 | 步骤 | 预期 | 状态 |
|---|---|---|---|
| 仓库边界 | 在项目根运行 `pwd` 与 `git rev-parse --show-toplevel` | 两者均为 `/Users/vita/Vitemis/Kuzio` | 已验证 |
| 远程连接 | 运行 `git remote -v` | fetch/push 均指向 `https://github.com/Vita0818/Kuzio.git` | 已验证 |
| 模板占位符 | 搜索双花括号占位语法 | 项目文档不残留模板占位符 | 已验证 |
| 文档格式 | 运行 `git diff --check` 并检查所有新增 Markdown | 无空白错误 | 已验证 |

## 验证边界声明

- 文档任务至少运行 `git diff --check` 与 `git status --short`。
- 当前没有业务工程，无法也无需运行构建、单元测试、UI 测试或集成测试。
- 后续代码任务必须按改动风险运行相称的 build、test 与 lint；未运行时必须说明原因。

## 外部依赖与禁止兜底验证

- 验证 exact 外部依赖可用时只调用其官方 API/扩展点，不调用第一方重复实现。
- 验证依赖缺失、版本不兼容、构建/签名/许可证/平台/安全条件不成立时产生明确、可诊断失败并停止该能力。
- 验证失败路径不会切换到 legacy、另一 provider/backend、adapter/shim、cache、mock、简化实现或不完整路径。
- 测试 double 只能存在于测试 target，不得进入 production selection 或 runtime fallback。
- Review 必须检查新增 wrapper/adapter/facade 是否仅为官方 API 必需的最薄接线；任何核心能力复制都必须拒绝。

## 常见问题

- 技术栈未确定时，不创建虚假的构建或测试命令，明确记录 `UNKNOWN`。
- 未来若缺少真机、模拟器或特定平台，只能报告未覆盖的验证边界，不能把替代路径描述为等价验证。
- 测试基础设施失败时，记录原始失败类型与影响范围，不得通过跳过安全或质量检查让结果看似成功。
