import SwiftUI

struct LibraryTrashView: View {
    @Bindable var library: LibraryViewModel
    @State private var permanentDeleteTarget: LibraryTrashItem?

    private var items: [LibraryTrashItem] {
        library.snapshot?.trashItems ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("废纸篓")
                .font(KuzioTypography.pageTitle())

            if items.isEmpty {
                ContentUnavailableView("废纸篓为空", systemImage: "trash")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(items) { item in
                            LibraryTrashCard(item: item) {
                                Task { await library.restore(item.id) }
                            } onDelete: {
                                permanentDeleteTarget = item
                            }
                        }
                    }
                    .padding(4)
                    .padding(.bottom, 24)
                }
            }
        }
        .padding(.horizontal, 34)
        .padding(.top, 30)
        .padding(.bottom, 34)
        .frame(maxWidth: 1_120, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .alert(
            "永久删除？",
            isPresented: Binding(
                get: { permanentDeleteTarget != nil },
                set: { isPresented in
                    if !isPresented { permanentDeleteTarget = nil }
                }
            ),
            presenting: permanentDeleteTarget
        ) { target in
            Button("取消", role: .cancel) {}
            Button("永久删除", role: .destructive) {
                Task { await library.permanentlyDelete(target.id) }
            }
        } message: { target in
            if target.kind == .resourceLink {
                Text("只会从 Kuzio 移除“\(target.title)”的链接；外部资源不会被删除。")
            } else {
                Text("“\(target.title)”及其所有子项目将从 Kuzio 管理的资料库中删除。")
            }
        }
    }
}

private struct LibraryTrashCard: View {
    let item: LibraryTrashItem
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            if item.kind == .folder {
                Image(nsImage: SystemFileIconProvider.folder())
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .accessibilityHidden(true)
            } else if item.kind == .resourceLink {
                Image(systemName: "link")
                    .font(.system(size: 24, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 42, height: 42)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "doc.text")
                    .font(.system(size: 24, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 42, height: 42)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(KuzioTypography.cardTitle())
                    .lineLimit(1)

                Text(LibraryMetadataFormatter.date(item.trashedAt))
                    .font(KuzioTypography.metadata())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            KuzioCircleIconButton(
                systemImage: "arrow.uturn.backward",
                accessibilityTitle: "恢复",
                action: onRestore
            )

            KuzioCircleIconButton(
                systemImage: "trash.slash",
                accessibilityTitle: "永久删除",
                role: .destructive,
                action: onDelete
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(Glass.regular, in: .rect(cornerRadius: 20))
    }
}
