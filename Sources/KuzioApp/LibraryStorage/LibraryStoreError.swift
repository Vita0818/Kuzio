import Foundation

enum LibraryStoreError: Error, Equatable, Sendable {
    case invalidRootURL
    case storeNotFound
    case storeAlreadyExists
    case unsupportedFormat
    case unsupportedLayoutVersion(UInt32)
    case unsupportedSchema(UInt32)
    case malformedManifest
    case invariantViolation(String)
    case invalidTitle
    case nodeNotFound(NodeID)
    case parentNotFound(NodeID)
    case parentNotFolder(NodeID)
    case kindMismatch(NodeID)
    case rootMutationForbidden
    case cycleDetected
    case alreadyTrashed(NodeID)
    case notInTrash(NodeID)
    case invalidRestoreDestination(NodeID)
    case revisionConflict(expected: UInt64, actual: UInt64)
    case coordinationFailed(Int)
    case unsafePath(String)
    case symbolicLinkDetected(String)
    case unexpectedFileType(String)
    case missingObject(ObjectID)
    case objectSizeMismatch(ObjectID)
    case objectDigestMismatch(ObjectID)
    case corruptPayload(ObjectID)
    case recoveryRequired
    case recoveryFailed
    case purgeIncomplete
    case permissionDenied(String)
    case io(operation: String, relativePath: String, code: Int)
}

extension LibraryStoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidRootURL:
            return "资料库位置无效。"
        case .storeNotFound:
            return "找不到资料库。"
        case .storeAlreadyExists:
            return "此位置已经存在内容。"
        case .unsupportedFormat:
            return "这不是 Kuzio 资料库。"
        case .unsupportedLayoutVersion(let version):
            return "不支持资料库布局版本 \(version)。"
        case .unsupportedSchema(let version):
            return "不支持资料库数据版本 \(version)。"
        case .malformedManifest:
            return "资料库清单已损坏。"
        case .invariantViolation:
            return "资料库结构不一致。"
        case .invalidTitle:
            return "名称无效。"
        case .nodeNotFound:
            return "找不到此项目。"
        case .parentNotFound:
            return "找不到目标文件夹。"
        case .parentNotFolder:
            return "目标不是文件夹。"
        case .kindMismatch:
            return "项目类型不匹配。"
        case .rootMutationForbidden:
            return "不能修改资料库根目录。"
        case .cycleDetected:
            return "不能把文件夹移动到自身或其子目录。"
        case .alreadyTrashed:
            return "此项目已在废纸篓中。"
        case .notInTrash:
            return "此项目不在废纸篓中。"
        case .invalidRestoreDestination:
            return "无法恢复到原位置。"
        case .revisionConflict:
            return "资料库已在其他位置发生变化，请刷新后重试。"
        case .coordinationFailed:
            return "无法协调资料库写入。"
        case .unsafePath:
            return "资料库包含不安全路径。"
        case .symbolicLinkDetected:
            return "资料库内部不允许符号链接。"
        case .unexpectedFileType:
            return "资料库包含不支持的文件类型。"
        case .missingObject:
            return "文档内容缺失。"
        case .objectSizeMismatch, .objectDigestMismatch, .corruptPayload:
            return "文档内容校验失败。"
        case .recoveryRequired:
            return "资料库需要显式恢复。"
        case .recoveryFailed:
            return "资料库恢复失败。"
        case .purgeIncomplete:
            return "永久删除已经提交，但残留对象仍需清理。"
        case .permissionDenied:
            return "没有资料库访问权限。"
        case .io:
            return "资料库文件操作失败。"
        }
    }
}
