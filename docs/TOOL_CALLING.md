# TOOL_CALLING

本文定义 Kuzio 当前 provider-neutral 工具调用契约。当前版本提供强类型 `LibraryToolControlPlane`，以及可组合的 `LibraryToolProvider` 工具目录、JSON Schema、严格参数解码和统一结果 envelope；不包含模型 SDK、提示词、聊天界面、网络服务、MCP server、工具总和聚合器或其他 AI runtime。

## 执行边界

```text
未来 runtime 工具总和聚合器
        |
        | 合并其他工具来源与 Kuzio definitions
        v
LibraryToolProvider
        |
        | strict JSON object -> LibraryToolCall
        v
LibraryToolControlPlane
        |
        | capability check / argument validation
        v
LibraryStore actor
        |
        | expected revision / transaction / validation
        v
manifest.json + immutable objects
```

- 调用方只使用 canonical lowercase `NodeID`、`ResourceID` 和 manifest revision。
- 工具参数不接受文件系统路径、URL、bookmark bytes、manifest fragment 或 object-store key。
- `LibraryToolControlPlane` 是工具调用的受控执行入口；调用方不得直接修改 `manifest.json` 或 object store。
- 结构 mutation 全部复用现有 `LibraryStore` transaction，不存在第二套 backend、shadow state 或 AI 专用数据层。
- 工具结果不返回真实路径或 bookmark；读取外部文件时，控制面内部解析现有只读 app-scoped security-scoped bookmark，并平衡 security-scope 生命周期。
- 当前不提供永久删除、外部文件写入、任意路径读取、自动重连、文件夹刷新/镜像或网络资源下载工具。

## 工具提供者

- `LibraryToolProvider.providerID` 当前固定为 `com.vitemis.kuzio.library-tools.v1`；任何不兼容的名称、schema、默认值或 wire 语义变化都必须提升该版本。
- `definitions` 按固定顺序提供当前实例获授权的工具名称、model-facing description、标准 JSON Schema object 与所需 capability。schema 全部使用 `additionalProperties: false`。
- `LibraryToolProvider` 只是未来完整模型工具面的一个 contributor，不声明这 8 个工具是模型唯一可用的工具。未来 runtime 负责把它们与其他已授权工具来源合并，并对名称冲突 fail closed。
- provider 接收 `LibraryToolInvocation(name:argumentsJSON:)`。`argumentsJSON` 必须是最多 65,536 bytes 的 JSON object；未知字段、缺少必填字段、错误类型、非 canonical UUID、负 index、超限内容参数和未知 tool name 都返回 `invalid_arguments`。
- capability 不仅过滤 `definitions`；调用方即使绕过目录直接请求未授权的已知工具，provider 也会在参数解码和 Store 调用前返回 `permission_denied`。
- provider 只做目录发布、严格 JSON→强类型转换、控制面分发与强类型→JSON envelope 编码。它不重试、不修改参数、不实现模型循环，也不拥有第二份权限或资料库状态。

## Capability

创建控制面时必须显式授予 capability；没有默认全权限。

| Capability | 允许的工具 |
| --- | --- |
| `read_structure` | `library_get_state`、`library_list_children` |
| `read_content` | `library_read_content` |
| `mutate_structure` | `library_create_folder`、`library_rename_node`、`library_move_node`、`library_trash_node`、`library_restore_node` |

缺少 capability 时返回 `permission_denied`，控制面不会调用 Store。

## Wire 约定

调用方应把 function call 映射成以下 provider-neutral invocation：

```json
{
  "name": "library_list_children",
  "arguments": {
    "parent_node_id": "00000000-0000-0000-0000-000000000000"
  }
}
```

约定：

- `name` 必须是本文列出的精确工具名。
- `arguments` 必须是 JSON object；没有参数时传 `{}`。
- 所有 ID 必须是 canonical lowercase UUID string。
- `index` 是从 `0` 开始的 child index；省略或 `null` 表示追加到目标文件夹末尾。恢复到原位置的特殊规则见 `library_restore_node`。
- 所有结构 mutation 都必须传 `expected_revision`。调用方应使用最近一次读取或 mutation 成功结果中的 revision；不得猜测 revision。
- `LibraryToolProvider` 已负责 JSON 与 `LibraryToolCall` 的严格转换，以及 `LibraryToolExecutionResult` 的 JSON 编码。未来 runtime adapter 只负责把其原生 tool spec/call/result 类型接到 provider，不得自行执行、重试或改写库操作。

建议的成功 envelope：

```json
{
  "ok": true,
  "tool": "library_create_folder",
  "result": {}
}
```

建议的失败 envelope：

```json
{
  "ok": false,
  "tool": "library_create_folder",
  "error": {
    "code": "revision_conflict",
    "expected_revision": 17,
    "actual_revision": 18
  }
}
```

失败后 adapter 不得把错误转换成另一项 mutation。`revision_conflict` 的正确处理是重新读取结构，再由调用方重新决定是否发起操作。

## 通用 node 输出

结构读取中的 node 使用以下字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `node_id` | UUID string | 库内虚拟节点身份 |
| `parent_node_id` | UUID string 或 `null` | 当前虚拟 parent；root 和 trash root 可以为 `null` |
| `kind` | `folder`、`document`、`resource_link` | 节点类型 |
| `title` | string | 显示名称，不是路径或 identity |
| `child_count` | integer | folder 的直接 child 数量；其他类型为 `0` |
| `last_modified_revision` | integer | 节点最后一次修改所在的 library revision |
| `resource_id` | UUID string 或 `null` | 仅 resource link 存在 |
| `media_type` | string 或 `null` | 仅内部 document 存在 |
| `byte_count` | integer 或 `null` | 仅内部 document 的当前 payload 大小 |
| `is_trashed_root` | boolean | 是否为废纸篓中的 subtree root |

输出中的 `parent_node_id`、`title` 和 child 顺序只描述 Kuzio 虚拟结构，不代表本机或云端真实目录。

## 工具

### `library_get_state`

读取当前 library identity、revision、root node 和 trash roots。

所需 capability：`read_structure`

参数：

```json
{}
```

结果：

```json
{
  "library_id": "uuid",
  "revision": 18,
  "root": {},
  "trash": []
}
```

`root` 和 `trash` 元素使用通用 node 输出。调用方取得 `root.node_id` 后，再通过 `library_list_children` 遍历任意深度结构。

### `library_list_children`

按 manifest 中保存的顺序列出一个虚拟文件夹的直接 children。

所需 capability：`read_structure`

参数：

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `parent_node_id` | UUID string | 是 | 要读取的虚拟 folder `NodeID` |

结果：

```json
{
  "revision": 18,
  "parent": {},
  "children": []
}
```

`parent` 和 `children` 使用通用 node 输出。目标不存在时返回 `node_not_found`；目标不是 folder 时返回 `kind_mismatch`。

### `library_read_content`

分段读取内部 document 或已经链接的本机文件内容。当前工具只返回 UTF-8 文本，不解析 PDF、Office、图片、音频或其他二进制格式。

所需 capability：`read_content`

参数：

| 参数 | 类型 | 必填 | 默认值 | 说明 |
| --- | --- | --- | --- | --- |
| `node_id` | UUID string | 是 | — | document 或 resource-link `NodeID` |
| `byte_offset` | non-negative integer | 否 | `0` | UTF-8 byte offset；后续调用必须使用上次返回的 `next_byte_offset` |
| `maximum_bytes` | integer | 否 | `65536` | 本次最多读取的 bytes；允许范围 `4...262144` |

结果：

```json
{
  "revision": 18,
  "node_id": "uuid",
  "source": "document",
  "media_type": "text/markdown; charset=utf-8",
  "content_type_identifier": null,
  "text": "...",
  "byte_offset": 0,
  "next_byte_offset": 65534,
  "total_byte_count": 120000,
  "truncated": true
}
```

- `source` 是 `document` 或 `resource_link`。
- 内部 document 使用 `media_type`；外部链接使用 `content_type_identifier`。
- 控制面会避免在一个 UTF-8 scalar 中间截断，因此 `next_byte_offset` 可能小于 `byte_offset + maximum_bytes`。
- `truncated == true` 时继续使用精确的 `next_byte_offset`；为 `false` 时读取完成且 `next_byte_offset` 为 `null`。
- 外部链接只按已有 `ResourceID` 和 locator 读取，不接受替代路径。链接失效或目标不可达时返回 `resource_unavailable`。
- directory/HTTPS locator 和非 UTF-8 内容分别返回 `unsupported_content` 或 `content_not_utf8`，不会调用替代解析器或网络 backend。
- 读取工具不会刷新 stale bookmark、写入 external target 或修改 library revision。

### `library_create_folder`

在一个虚拟 folder 下创建空的虚拟 folder。

所需 capability：`mutate_structure`

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `parent_node_id` | UUID string | 是 | 目标虚拟 folder |
| `title` | string | 是 | 新 folder 的显示名称 |
| `index` | integer 或 `null` | 否 | 目标 child index；省略时追加 |
| `expected_revision` | integer | 是 | 调用方最近确认的 library revision |

### `library_rename_node`

只修改虚拟节点名称，保持 `NodeID`、`ResourceID` 和外部目标不变。

所需 capability：`mutate_structure`

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `node_id` | UUID string | 是 | 要重命名的虚拟节点；不能是 library root |
| `title` | string | 是 | 新显示名称 |
| `expected_revision` | integer | 是 | 调用方最近确认的 library revision |

### `library_move_node`

把一个 active 虚拟 subtree 移到另一个 active 虚拟 folder。移动只改变 virtual hierarchy。

所需 capability：`mutate_structure`

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `node_id` | UUID string | 是 | 要移动的 subtree root；不能是 library root |
| `destination_parent_node_id` | UUID string | 是 | 目标虚拟 folder |
| `index` | integer 或 `null` | 否 | 目标 child index；省略时追加 |
| `expected_revision` | integer | 是 | 调用方最近确认的 library revision |

目标位于被移动 subtree 内时返回 `cycle_detected`。

### `library_trash_node`

把一个 active 虚拟 subtree 移到 Kuzio 废纸篓。不会删除或修改外部目标。

所需 capability：`mutate_structure`

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `node_id` | UUID string | 是 | 要移到废纸篓的 subtree root；不能是 library root |
| `expected_revision` | integer | 是 | 调用方最近确认的 library revision |

### `library_restore_node`

恢复一个 trash root。

所需 capability：`mutate_structure`

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `node_id` | UUID string | 是 | `library_get_state.trash` 中的 trash root `NodeID` |
| `destination_parent_node_id` | UUID string 或 `null` | 否 | 省略时恢复到原 parent；指定时恢复到该 active folder |
| `index` | integer 或 `null` | 否 | 指定 destination 时省略表示追加；恢复到原 parent 时省略表示尽量恢复原 index |
| `expected_revision` | integer | 是 | 调用方最近确认的 library revision |

原 parent 已不存在时必须显式提供 `destination_parent_node_id`，否则返回 `invalid_restore_destination`。

## Mutation 结果

五个结构 mutation 都返回同一结果形状：

```json
{
  "revision": 19,
  "transaction_id": "uuid",
  "primary_node_id": "uuid",
  "created_node_ids": ["uuid"],
  "changed_node_ids": ["uuid"],
  "deleted_node_ids": [],
  "cleanup_pending": false
}
```

- `primary_node_id` 目前只由 `library_create_folder` 返回；其他 mutation 为 `null`。
- `revision` 是成功发布后的新 revision，也是下一次 mutation 必须使用的 `expected_revision`。
- `created_node_ids`、`changed_node_ids`、`deleted_node_ids` 只表示库内虚拟节点。
- `cleanup_pending` 表示 mutation 已经发布，但库内不可达 immutable object 仍需后续维护；它不表示回滚或外部文件变化。

## 稳定错误码

| code | 含义 |
| --- | --- |
| `invalid_arguments` | 参数值、名称、index、offset 或大小不合法 |
| `permission_denied` | 当前控制面实例没有所需 capability |
| `node_not_found` | 找不到指定 `NodeID` |
| `resource_not_found` | 找不到指定 `ResourceID` |
| `parent_not_found` | 找不到目标 parent |
| `parent_not_folder` | 目标 parent 不是 folder |
| `kind_mismatch` | 节点类型不支持该工具 |
| `root_mutation_forbidden` | 调用试图修改 library root |
| `cycle_detected` | 移动会产生 hierarchy cycle |
| `already_trashed` | 节点已经在废纸篓中 |
| `not_in_trash` | 恢复目标不是 trash root |
| `invalid_restore_destination` | 无法使用原 parent 或指定恢复目标 |
| `revision_conflict` | `expected_revision` 与当前 manifest revision 不一致 |
| `resource_unavailable` | 外部 locator 无法解析、目标离线或读取失败 |
| `unsupported_content` | 当前内容来源或文件类型不受读取工具支持 |
| `content_not_utf8` | 内容片段不是有效 UTF-8 文本 |
| `store_failure` | Store 完整性、协调、IO、recovery 或其他 fail-closed 错误 |

错误对象只包含稳定 code，以及适用时的 `argument`、`node_id`、`resource_id`、`expected_revision`、`actual_revision`；不得把本机路径、bookmark、底层完整错误响应或凭据放进工具结果。

## 推荐调用顺序

```text
library_get_state
    -> 取得 root NodeID 与 revision
library_list_children
    -> 按需递归读取虚拟结构
library_read_content
    -> 按 next_byte_offset 分段读取已授权内容
结构 mutation
    -> 携带最近 revision
mutation result
    -> 使用返回的新 revision 继续，或重新读取结构
```

未来接入具体模型时，由 runtime 把 `LibraryToolProvider.definitions` 并入其他工具来源形成完整工具总和，再以最薄 adapter 转发 invocation/result；不得把 provider 类型、prompt、重试策略或模型状态写入 `LibraryStore`、manifest schema 或虚拟 hierarchy。
