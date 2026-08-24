import SwiftUI

struct LibraryReaderView: View {
    @Bindable var library: LibraryViewModel
    let document: StoredDocument

    @State private var isEditing = false
    @State private var draft = ""
    @State private var nameOperation: LibraryNameOperation?
    @State private var moveEntry: LibraryEntry?

    private var entry: LibraryEntry? {
        library.snapshot?.entry(document.nodeID)
    }

    private var path: [LibraryEntry] {
        guard let snapshot = library.snapshot else { return [] }
        return Array(snapshot.path(to: document.nodeID).dropLast())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                LibraryBreadcrumb(path: path) { folder in
                    library.closeDocument()
                    library.selectFolder(folder.id)
                }

                if let entry {
                    LibraryMetadataDisclosure(entry: entry, path: path)
                }

                contentSurface
            }
            .frame(maxWidth: 780, alignment: .leading)
            .padding(.horizontal, 34)
            .padding(.top, 30)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .sheet(item: $nameOperation) { operation in
            LibraryNameSheet(operation: operation) { value in
                if case .rename(let entry) = operation {
                    Task { await library.rename(entry.id, to: value) }
                }
            }
        }
        .sheet(item: $moveEntry) { entry in
            LibraryMoveSheet(
                entry: entry,
                destinations: moveDestinations(for: entry)
            ) { destinationID in
                Task { await library.move(entry.id, to: destinationID) }
            }
        }
        .onAppear {
            draft = document.text ?? ""
        }
        .onChange(of: document.nodeID) {
            isEditing = false
            draft = document.text ?? ""
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                library.closeDocument()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: KuzioControlMetrics.iconSymbolSize, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .frame(
                width: KuzioControlMetrics.iconButtonSize,
                height: KuzioControlMetrics.iconButtonSize
            )
            .contentShape(Circle())
            .help("返回资料库")
            .accessibilityLabel("返回资料库")

            VStack(alignment: .leading, spacing: 7) {
                Text(entry?.title ?? document.title)
                    .font(KuzioTypography.pageTitle())
                    .lineLimit(2)

                if let entry {
                    Text(LibraryMetadataFormatter.metadataLine(for: entry))
                        .font(KuzioTypography.body(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            if let entry {
                HStack(spacing: 8) {
                    Button {
                        if isEditing {
                            Task {
                                await library.saveActiveDocument(text: draft)
                                isEditing = false
                            }
                        } else {
                            draft = document.text ?? ""
                            isEditing = true
                        }
                    } label: {
                        Image(systemName: isEditing ? "checkmark" : "pencil")
                            .font(.system(size: KuzioControlMetrics.iconSymbolSize, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .frame(
                        width: KuzioControlMetrics.iconButtonSize,
                        height: KuzioControlMetrics.iconButtonSize
                    )
                    .contentShape(Circle())
                    .help(isEditing ? "保存" : "编辑")
                    .accessibilityLabel(isEditing ? "保存" : "编辑")

                    if isEditing {
                        Button {
                            draft = document.text ?? ""
                            isEditing = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: KuzioControlMetrics.iconSymbolSize, weight: .semibold))
                                .symbolRenderingMode(.monochrome)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                        .frame(
                            width: KuzioControlMetrics.iconButtonSize,
                            height: KuzioControlMetrics.iconButtonSize
                        )
                        .contentShape(Circle())
                        .help("取消编辑")
                        .accessibilityLabel("取消编辑")
                    }

                    Menu {
                        Button {
                            nameOperation = .rename(entry)
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }

                        Button {
                            moveEntry = entry
                        } label: {
                            Label("移动", systemImage: "folder")
                        }

                        Divider()

                        Button(role: .destructive) {
                            Task { await library.moveToTrash(entry.id) }
                        } label: {
                            Label("移到废纸篓", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: KuzioControlMetrics.iconSymbolSize, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .frame(
                        width: KuzioControlMetrics.iconButtonSize,
                        height: KuzioControlMetrics.iconButtonSize
                    )
                    .contentShape(Circle())
                    .help("更多")
                    .accessibilityLabel("更多")
                }
            }
        }
    }

    @ViewBuilder
    private var contentSurface: some View {
        if isEditing {
            TextEditor(text: $draft)
                .font(KuzioTypography.body(size: 15))
                .lineSpacing(5)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 420)
                .padding(24)
                .glassEffect(Glass.regular, in: .rect(cornerRadius: 22))
        } else if let text = document.text, !text.isEmpty {
            if let attributed = try? AttributedString(
                markdown: text,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
            ) {
                Text(attributed)
                    .font(KuzioTypography.body(size: 15))
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .glassEffect(Glass.regular, in: .rect(cornerRadius: 22))
            } else {
                ContentUnavailableView("无法显示文档", systemImage: "doc.badge.xmark")
            }
        } else {
            ContentUnavailableView("空文档", systemImage: "doc")
                .frame(maxWidth: .infinity)
                .padding(24)
                .glassEffect(Glass.regular, in: .rect(cornerRadius: 22))
        }
    }

    private func moveDestinations(for entry: LibraryEntry) -> [LibraryFolderDestination] {
        library.folderDestinations(excluding: nil).map { folder in
            let path = library.snapshot?.path(to: folder.id).map(\.title).joined(separator: " / ") ?? folder.title
            return LibraryFolderDestination(entry: folder, path: path)
        }
    }
}

private struct LibraryMetadataDisclosure: View {
    let entry: LibraryEntry
    let path: [LibraryEntry]

    var body: some View {
        DisclosureGroup {
            VStack(spacing: 0) {
                metadataRow("类型", LibraryMetadataFormatter.typeName(for: entry))
                Divider().padding(.leading, 18)
                metadataRow("位置", path.map(\.title).joined(separator: " / "))
                Divider().padding(.leading, 18)
                metadataRow("大小", LibraryMetadataFormatter.byteCount(entry.document?.byteCount ?? 0))
                Divider().padding(.leading, 18)
                metadataRow("创建", LibraryMetadataFormatter.date(entry.createdAt))
                Divider().padding(.leading, 18)
                metadataRow("修改", LibraryMetadataFormatter.date(entry.modifiedAt))
            }
            .padding(.top, 10)
        } label: {
            Text("信息")
                .font(KuzioTypography.body(size: 13, weight: .semibold))
        }
        .padding(16)
        .glassEffect(Glass.clear, in: .rect(cornerRadius: 16))
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(KuzioTypography.metadata())
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(KuzioTypography.metadata())
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, 10)
    }
}
