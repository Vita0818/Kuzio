import AppKit
import IntatisSharedUI
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
    let onOpenCowork: (LibraryEntry) -> Void
    @State private var nameOperation: LibraryNameOperation?
    @State private var moveEntry: LibraryEntry?

    private let layout = LibraryBrowserLayout.mac

    private var folders: [LibraryEntry] {
        library.displayedEntries.filter(\.isFolder)
    }

    private var resourceLinks: [LibraryEntry] {
        library.displayedEntries.filter(\.isResourceLink)
    }

    private var documents: [LibraryEntry] {
        library.displayedEntries.filter(\.isDocument)
    }

    private var query: String {
        library.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.rootSpacing) {
            Text("资料库")
                .font(IntatisTypography.largeTitle(32, .bold))
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
        HStack(spacing: KuzioControlMetrics.iconButtonSpacing) {
            KuzioCircleIconButton(
                systemImage: "chevron.left",
                accessibilityTitle: "后退",
                isEnabled: library.canGoBack
            ) {
                library.goBack()
            }

            KuzioCircleIconButton(
                systemImage: "chevron.right",
                accessibilityTitle: "前进",
                isEnabled: library.canGoForward
            ) {
                library.goForward()
            }
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
                .font(IntatisTypography.body(13, .semibold))
        }
    }

    private var creationButtons: some View {
        Menu {
            Button {
                chooseResourcesToLink()
            } label: {
                Label("添加文件或文件夹", systemImage: "doc")
            }

            Divider()

            Button {
                nameOperation = .createFolder
            } label: {
                Label("新建文件夹", systemImage: "folder")
            }

            Button {
                nameOperation = .createDocument
            } label: {
                Label("新建文档", systemImage: "doc.text")
            }
        } label: {
            KuzioCircleIconLabel(systemImage: "plus")
        } primaryAction: {
            chooseResourcesToLink()
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .kuzioCircleIconControl(accessibilityTitle: "添加")
        .disabled(library.snapshot == nil || library.isAddingResources)
    }

    private func chooseResourcesToLink() {
        let panel = NSOpenPanel()
        panel.title = "选择文件或文件夹"
        panel.prompt = "添加"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
        panel.canDownloadUbiquitousContents = true
        panel.canResolveUbiquitousConflicts = true

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        let selectedURLs = panel.urls
        Task {
            await library.createExternalLinks(to: selectedURLs)
        }
    }

    private func chooseFileToRelink(_ entry: LibraryEntry) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.canDownloadUbiquitousContents = true
        panel.canResolveUbiquitousConflicts = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            await library.relinkFile(entry.id, to: url)
        }
    }

    private func chooseFolderToRelink(_ entry: LibraryEntry) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.canDownloadUbiquitousContents = true
        panel.canResolveUbiquitousConflicts = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            await library.relinkFolder(entry.id, to: url)
        }
    }

    @ViewBuilder
    private var browserContent: some View {
        if folders.isEmpty && resourceLinks.isEmpty && documents.isEmpty {
            if query.isEmpty {
                ContentUnavailableView {
                    VStack(spacing: 12) {
                        Image(nsImage: SystemFileIconProvider.folder())
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 72, height: 64)
                            .accessibilityHidden(true)

                        Text("此文件夹为空")
                            .font(IntatisTypography.body(14, .semibold))
                    }
                }
            } else {
                ContentUnavailableView("没有结果", systemImage: "magnifyingglass")
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: layout.contentSpacing) {
                    if !folders.isEmpty || !resourceLinks.isEmpty {
                        LazyVGrid(
                            columns: layout.folderColumns,
                            alignment: .leading,
                            spacing: layout.folderSpacing
                        ) {
                            ForEach(folders) { folder in
                                LibraryGridItemTile(
                                    entry: folder,
                                    icon: SystemFileIconProvider.folder(),
                                    detail: "\(folder.childIDs.count) 项"
                                ) {
                                    library.selectFolder(folder.id)
                                }
                                .contextMenu {
                                    entryContextMenu(folder)
                                }
                            }

                            ForEach(resourceLinks) { resourceLink in
                                LibraryGridItemTile(
                                    entry: resourceLink,
                                    icon: SystemFileIconProvider.file(
                                        contentTypeIdentifier: resourceLink.externalResource?
                                            .contentTypeIdentifier,
                                        filename: resourceLink.externalResource?.lastKnownName
                                            ?? resourceLink.title
                                    ),
                                    detail: nil
                                ) {
                                    Task { await library.openEntry(resourceLink.id) }
                                }
                                .contextMenu {
                                    entryContextMenu(resourceLink)
                                }
                            }
                        }
                    }

                    if !documents.isEmpty {
                        LazyVStack(alignment: .leading, spacing: layout.documentSpacing) {
                            ForEach(documents) { document in
                                LibraryDocumentCard(document: document) {
                                    Task { await library.openEntry(document.id) }
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
            onOpenCowork(entry)
        } label: {
            Label(
                "AI 对话",
                systemImage: "bubble.left.and.bubble.right"
            )
        }

        Divider()

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

        if entry.externalResource?.kind == .file {
            Button {
                chooseFileToRelink(entry)
            } label: {
                Label("重新链接", systemImage: "link")
            }
        } else if entry.isFolder, library.canRelinkFolder(entry.id) {
            Button {
                chooseFolderToRelink(entry)
            } label: {
                Label("重新链接", systemImage: "link")
            }
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
                            .font(IntatisTypography.metadata(12, .semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }

                    Button {
                        onSelect(entry)
                    } label: {
                        Text(entry.title)
                            .font(IntatisTypography.metadata(
                                12,
                                index == path.count - 1 ? .semibold : .medium
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

private struct LibraryGridItemTile: View {
    let entry: LibraryEntry
    let icon: NSImage
    let detail: String?
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .center, spacing: 10) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(
                        width: KuzioControlMetrics.folderIconWidth,
                        height: KuzioControlMetrics.folderIconHeight
                    )
                    .frame(height: KuzioControlMetrics.folderIconContainerHeight)
                    .accessibilityHidden(true)

                Text(entry.title)
                    .font(IntatisTypography.body(14, .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
                    .frame(
                        height: KuzioControlMetrics.gridTileTitleHeight,
                        alignment: .top
                    )
                    .minimumScaleFactor(0.82)

                if let detail {
                    Text(detail)
                        .font(IntatisTypography.caption(11, .semibold))
                        .foregroundStyle(.secondary)
                        .frame(height: KuzioControlMetrics.gridTileDetailHeight)
                } else {
                    Spacer(minLength: 0)
                        .frame(height: KuzioControlMetrics.gridTileDetailHeight)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .frame(height: KuzioControlMetrics.gridTileHeight)
            .contentShape(Rectangle())
            .glassEffect(
                Glass.regular.interactive(),
                in: .rect(cornerRadius: 18)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.title)
        .accessibilityValue(detail ?? "")
    }
}

private struct LibraryDocumentCard: View {
    let document: LibraryEntry
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                Image(systemName: "doc.text")
                    .font(.system(size: KuzioControlMetrics.cardSymbolSize, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .frame(
                        width: KuzioControlMetrics.cardIconFrameSize,
                        height: KuzioControlMetrics.cardIconFrameSize
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text(document.title)
                        .font(IntatisTypography.headline(16, .semibold))
                        .lineLimit(1)

                    Text(LibraryMetadataFormatter.metadataLine(for: document))
                        .font(IntatisTypography.metadata(12, .medium))
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
