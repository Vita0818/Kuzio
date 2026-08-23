# DO_NOT_BREAK

本文列出不可破坏的工程禁区、数据格式、协议、路径和回归要求。修改前必须确认不违反下列任一条目。

## 工程禁区

- 不执行破坏性 Git 操作：`git reset --hard`、`git clean -fd`、`git checkout .`、强制 push、删除未提交文件。
- 未经用户明文要求具体 Git 操作，不 add、不 commit、不 push、不创建 PR；编辑、整理、修复、验证或准备工作都不等于提交请求。
- 若用户要求提交，只提交当前 Git root 中与本任务相关的文件；不得递归进入、暂存、提交或推送子仓库、submodule、nested Git repo 或依赖 checkout。
- 不引入新依赖，不改构建脚本，不改测试源码，除非任务明确要求。
- 不直接编辑 `.git/`，不把 Kuzio 文件暂存到 `/Users/vita/Vitemis` 父仓库。
- 不改写已有 `v0.0` 提交历史，除非用户明确要求对应的历史改写操作并确认目标。
- 不绕过安全机制；当前安全机制尚未定义，新增安全边界时必须先写入架构与验证文档。
- 不把 `UNKNOWN`、模板示例或推测当成已经确认的产品要求。

## 外部依赖与禁止兜底禁区

- 当外部依赖已经提供同等能力时，必须直接使用其官方 API/扩展点；不得自行重写，也不得新增替代 adapter、shim、compatibility layer、wrapper、proxy、facade、parallel backend、preview backend、shadow implementation 或临时 fallback。
- exact 依赖不可用或不兼容时必须明确失败并停止该能力；不得静默切换 legacy、另一 provider/backend、缓存、mock、简化实现或不完整路径。
- 本地代码只能是官方 API 必需的最薄生命周期、类型、权限、配置和 bundle 接线，不能复制或重新解释依赖核心行为。
- 现有 fallback 或重复实现不得扩张。安全 fail-closed 与明确要求的旧数据解码/迁移必须保持最窄范围，不能成为备用产品实现。

## 数据格式禁区

当前尚未定义持久化文件、配置、跨端报文或资源包格式。首次引入任何格式时，必须记录路径、schema、版本、编码、兼容性和迁移规则；在此之前不得假定存在稳定格式。

## 协议禁区

当前尚未定义通信、同步或迁移协议。首次引入协议时，必须记录 route、method、header、body schema、安全校验、状态机、冲突处理和兼容边界。

## 路径禁区

- Git root 固定为 `/Users/vita/Vitemis/Kuzio`；所有项目级修改必须限制在此仓库中。
- `.git/` 是 Git 管理的内部路径，不得直接编辑。
- 文件根目录、容器目录、资源打包路径和构建产物路径当前均为 `UNKNOWN`；确定后必须同步记录。

## 回归要求

- 保持 `pwd` 与 `git rev-parse --show-toplevel` 指向 `/Users/vita/Vitemis/Kuzio`。
- 保持项目入口文档继承 `/Users/vita/Vitemis/AGENTS.md` 和 `/Users/vita/Vitemis/docs/DEPENDENCY_POLICY.md`。
- 新增工程事实后及时更新 `CURRENT_STATE.md`、`PROJECT_MAP.md`、`ARCHITECTURE.md`、`DO_NOT_BREAK.md` 与 `TESTING.md`，不得让模板状态冒充真实状态。

## 不可降级项

- 不得削弱 Codex、Claude、Gemini、Cursor 的角色和写入边界。
- 不得把 dependency-first / no-fallback 合同降级为建议项。
- 不得因缺少需求而擅自选择产品范围、平台、技术栈或替代实现。

## 验证要求

文档改动至少运行：

```sh
git diff --check
git status --short
```

代码、构建或依赖改动的验证命令当前尚未定义；建立技术栈时必须在 `docs/TESTING.md` 中补齐。
