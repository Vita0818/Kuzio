import IntatisSharedUI
import SwiftUI

enum LibraryNameOperation: Identifiable {
    case createFolder
    case createDocument
    case rename(LibraryEntry)

    var id: String {
        switch self {
        case .createFolder: return "create-folder"
        case .createDocument: return "create-document"
        case .rename(let entry): return "rename-\(entry.id.description)"
        }
    }

    var title: String {
        switch self {
        case .createFolder: return "新建文件夹"
        case .createDocument: return "新建文档"
        case .rename: return "重命名"
        }
    }

    var actionTitle: String {
        switch self {
        case .createFolder, .createDocument: return "新建"
        case .rename: return "保存"
        }
    }

    var initialValue: String {
        switch self {
        case .createFolder, .createDocument: return ""
        case .rename(let entry): return entry.title
        }
    }
}

struct LibraryNameSheet: View {
    let operation: LibraryNameOperation
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: String

    init(operation: LibraryNameOperation, onSubmit: @escaping (String) -> Void) {
        self.operation = operation
        self.onSubmit = onSubmit
        _value = State(initialValue: operation.initialValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("名称", text: $value)
                    .font(IntatisTypography.body(14, .regular))
            }
            .formStyle(.grouped)
            .navigationTitle(operation.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(operation.actionTitle) {
                        onSubmit(value)
                        dismiss()
                    }
                    .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .font(IntatisTypography.body(14, .regular))
        .frame(width: 420, height: 190)
    }
}

struct LibraryFolderDestination: Identifiable, Hashable {
    let entry: LibraryEntry
    let path: String

    var id: NodeID { entry.id }
}

struct LibraryMoveSheet: View {
    let entry: LibraryEntry
    let destinations: [LibraryFolderDestination]
    let onMove: (NodeID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: NodeID?

    var body: some View {
        NavigationStack {
            List(destinations, selection: $selection) { destination in
                HStack(spacing: 12) {
                    Image(nsImage: SystemFileIconProvider.folder())
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(destination.entry.title)
                            .font(IntatisTypography.body(13, .semibold))
                            .lineLimit(1)
                        Text(destination.path)
                            .font(IntatisTypography.caption(11, .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(minHeight: KuzioControlMetrics.iconButtonSize)
                .tag(destination.id)
            }
            .navigationTitle("移动“\(entry.title)”")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("移动") {
                        if let selection {
                            onMove(selection)
                            dismiss()
                        }
                    }
                    .disabled(selection == nil)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .font(IntatisTypography.body(14, .regular))
        .frame(width: 520, height: 460)
    }
}

enum LibraryMetadataFormatter {
    static func typeName(for entry: LibraryEntry) -> String {
        switch entry.kind {
        case .folder:
            return "文件夹"
        case .document:
            guard let mediaType = entry.document?.mediaType else { return "文档" }
            if mediaType.hasPrefix("text/markdown") { return "Markdown" }
            if mediaType.hasPrefix("text/plain") { return "文本" }
            return mediaType
        case .resourceLink:
            switch entry.externalResource?.kind {
            case .file: return "文件链接"
            case .directory: return "文件夹链接"
            case .https: return "网页链接"
            case nil: return "资源链接"
            }
        }
    }

    static func byteCount(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .file)
    }

    static func date(_ value: Date) -> String {
        value.formatted(date: .abbreviated, time: .shortened)
    }

    static func metadataLine(for entry: LibraryEntry) -> String {
        if entry.isFolder {
            return "\(entry.childIDs.count) 项 · \(date(entry.modifiedAt))"
        }
        if entry.isResourceLink {
            let target = entry.externalResource?.lastKnownName ?? "外部资源"
            return "\(typeName(for: entry)) · \(target) · \(date(entry.modifiedAt))"
        }
        let bytes = byteCount(entry.document?.byteCount ?? 0)
        return "\(typeName(for: entry)) · \(bytes) · \(date(entry.modifiedAt))"
    }
}
