# PROJECT_MAP

最近自查日期：2026-08-23

本文描述当前仓库结构。判断依据来自 Git 状态和现有文档；仓库当前没有 Xcode project、`Package.swift`、`project.yml`、`package.json`、`pyproject.toml`、Makefile 或其他构建清单。

## 目录结构总览

```text
Kuzio/
├── AGENTS.md              # Codex 与通用 Agent 的项目入口和修改边界
├── CLAUDE.md              # Claude 只读审查入口
├── GEMINI.md              # Gemini 只读审查入口
└── docs/
    ├── ARCHITECTURE.md    # 当前架构事实与依赖决策约束
    ├── CURRENT_STATE.md   # 项目真实状态、风险与未完成项
    ├── DO_NOT_BREAK.md    # 工程禁区和不可降级约束
    ├── NEXT_TARGET.md     # 临时单一下一目标记录
    ├── PROJECT_MAP.md     # 本文件
    └── TESTING.md         # 构建、测试和验证契约
```

`.git/` 是仓库元数据，不属于业务源码，不应由 Agent 直接编辑。

## Target / 模块

| Target / 模块 | 类型 | 平台 | 入口 | 职责 |
|---|---|---|---|---|
| 尚未定义 | `UNKNOWN` | `UNKNOWN` | `UNKNOWN` | 等待用户确认产品范围与技术栈 |

## 关键文件

- 产品入口：当前不存在。
- 核心链路：当前不存在。
- 构建配置：当前不存在。
- 测试：当前不存在。
- 项目治理入口：`AGENTS.md`、`CLAUDE.md`、`GEMINI.md`。
- 状态与约束：`docs/CURRENT_STATE.md`、`docs/ARCHITECTURE.md`、`docs/DO_NOT_BREAK.md`、`docs/TESTING.md`。

## 生成物 / 产物

- 构建产物：无。
- 脚本生成物：无。
- 报告：未来 Codex、Claude、Gemini、Cursor 报告分别只能写入工作区政策规定的各自报告目录；当前尚未创建任何报告目录。

## 脚本与工具

当前没有项目脚本或项目专属工具。

## 不确定项

- 产品形态、用户场景和业务边界：`UNKNOWN`。
- 目标平台、语言、框架和构建工具：`UNKNOWN`。
- 模块、target、源码目录、入口和测试结构：`UNKNOWN`。
- 交付、部署、签名和发布方式：`UNKNOWN`。
