import SwiftUI

struct LibraryBrowserLayout {
    let maximumContentWidth: CGFloat
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let rootSpacing: CGFloat
    let contentSpacing: CGFloat
    let folderSpacing: CGFloat
    let documentSpacing: CGFloat
    let folderColumns: [GridItem]

    static let mac = LibraryBrowserLayout(
        maximumContentWidth: 1_120,
        horizontalPadding: 34,
        topPadding: 30,
        bottomPadding: 34,
        rootSpacing: 20,
        contentSpacing: 18,
        folderSpacing: 16,
        documentSpacing: 12,
        folderColumns: [
            GridItem(
                .adaptive(minimum: 142, maximum: 210),
                spacing: 16,
                alignment: .top
            ),
        ]
    )
}

struct LibraryBrowserPage: View {
    @Bindable var library: LibraryViewModel
    @State private var nameOperation: LibraryNameOperation?
    @State private var moveEntry: LibraryEntry?

    private let layout = LibraryBrowserLayout.mac

    private var folders: [LibraryEntry] {
        library.displayedEntries.filter(\.isFolder)
    }

    private var documents: [LibraryEntry] {
        library.displayedEntries.filter { !$0.isFolder }
    }

    private var query: String {
        library.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.rootSpacing) {
            Text("资料库")
                .font(KuzioTypography.pageTitle())
                .lineLimit(1)

            navigationRow

            browserContent
        }
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.top, layout.topPadding)
        .padding(.bottom, layout.bottomPadding)
        .frame(maxWidth: layout.maximumContentWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .searchable(text: $library.searchText, prompt: Text("搜索"))
        .sheet(item: $nameOperation) { operation in
            LibraryNameSheet(operation: operation) { value in
                Task {
                    switch operation {
                    case .createFolder:
                        await library.createFolder(title: value)
                    case .createDocument:
                        await library.createDocument(title: value)
                    case .rename(let entry):
                        await library.rename(entry.id, to: value)
                    }
                }
            }
        }
        .sheet(item: $moveEntry) { entry in
            LibraryMoveSheet(
                entry: entry,
                destinations: moveDestinations(for: entry)
            ) { destinationID in
                Task {
                    await library.move(entry.id, to: destinationID)
                }
            }
        }
    }

    private var navigationRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                navigationButtons
                location
                Spacer(minLength: 12)
                creationButtons
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    navigationButtons
                    Spacer(minLength: 12)
                    creationButtons
                }
                location
            }
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 8) {
            Button {
                library.goBack()
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
            .disabled(!library.canGoBack)
            .help("后退")
            .accessibilityLabel("后退")

            Button {
                library.goForward()
            } label: {
                Image(systemName: "chevron.right")
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
            .disabled(!library.canGoForward)
            .help("前进")
            .accessibilityLabel("前进")
        }
    }

    @ViewBuilder
    private var location: some View {
        if query.isEmpty {
            LibraryBreadcrumb(path: library.currentPath) { entry in
                library.selectFolder(entry.id)
            }
        } else {
            Label("搜索", systemImage: "magnifyingglass")
                .font(KuzioTypography.body(size: 13, weight: .semibold))
        }
    }

    private var creationButtons: some View {
        HStack(spacing: 8) {
            Button {
                nameOperation = .createFolder
            } label: {
                Image(systemName: "folder.badge.plus")
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
            .help("新建文件夹")
            .accessibilityLabel("新建文件夹")

            Button {
                nameOperation = .createDocument
            } label: {
                Image(systemName: "doc.badge.plus")
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
            .help("新建文档")
            .accessibilityLabel("新建文档")
        }
    }

    @ViewBuilder
    private var browserContent: some View {
        if folders.isEmpty && documents.isEmpty {
            if query.isEmpty {
                ContentUnavailableView("此文件夹为空", systemImage: "folder")
            } else {
                ContentUnavailableView("没有结果", systemImage: "magnifyingglass")
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: layout.contentSpacing) {
                    if !folders.isEmpty {
                        LazyVGrid(
                            columns: layout.folderColumns,
                            alignment: .leading,
                            spacing: layout.folderSpacing
                        ) {
                            ForEach(folders) { folder in
                                LibraryFolderTile(folder: folder) {
                                    library.selectFolder(folder.id)
                                }
                                .contextMenu {
                                    entryContextMenu(folder)
                                }
                            }
                        }
                    }

                    if !documents.isEmpty {
                        LazyVStack(alignment: .leading, spacing: layout.documentSpacing) {
                            ForEach(documents) { document in
                                LibraryDocumentCard(document: document) {
                                    Task { await library.openDocument(document.id) }
                                }
                                .contextMenu {
                                    entryContextMenu(document)
                                }
                            }
                        }
                    }
                }
                .padding(4)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func entryContextMenu(_ entry: LibraryEntry) -> some View {
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
    }

    private func moveDestinations(for entry: LibraryEntry) -> [LibraryFolderDestination] {
        library.folderDestinations(excluding: entry.isFolder ? entry.id : nil).map { folder in
            let path = library.snapshot?.path(to: folder.id).map(\.title).joined(separator: " / ") ?? folder.title
            return LibraryFolderDestination(entry: folder, path: path)
        }
    }
}

struct LibraryBreadcrumb: View {
    let path: [LibraryEntry]
    let onSelect: (LibraryEntry) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(path.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        Text("/")
                            .font(KuzioTypography.metadata(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }

                    Button {
                        onSelect(entry)
                    } label: {
                        Text(entry.title)
                            .font(KuzioTypography.metadata(
                                size: 12,
                                weight: index == path.count - 1 ? .semibold : .medium
                            ))
                            .foregroundStyle(index == path.count - 1 ? .primary : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(index == path.count - 1)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct LibraryFolderTile: View {
    let folder: LibraryEntry
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .center, spacing: 10) {
                Image(nsImage: SystemFileIconProvider.folder())
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 58, height: 52)
                    .accessibilityHidden(true)

                Text(folder.title)
                    .font(KuzioTypography.body(size: 14, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
                    .minimumScaleFactor(0.82)

                Text("\(folder.childIDs.count) 项")
                    .font(KuzioTypography.caption(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 128)
            .contentShape(Rectangle())
            .glassEffect(
                Glass.regular.interactive(),
                in: .rect(cornerRadius: 18)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(folder.title)
        .accessibilityValue("\(folder.childIDs.count) 项")
    }
}

private struct LibraryDocumentCard: View {
    let document: LibraryEntry
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                Image(systemName: "doc.text")
                    .font(.system(size: 24, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 8) {
                    Text(document.title)
                        .font(KuzioTypography.cardTitle())
                        .lineLimit(1)

                    Text(LibraryMetadataFormatter.metadataLine(for: document))
                        .font(KuzioTypography.metadata())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .glassEffect(
                Glass.regular.interactive(),
                in: .rect(cornerRadius: 20)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(document.title)
        .accessibilityValue(LibraryMetadataFormatter.metadataLine(for: document))
    }
}
