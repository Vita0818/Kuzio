import IntatisSharedUI
import SwiftUI

struct LibraryRootView: View {
    @Bindable var library: LibraryViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var coworkTarget: KuzioCoworkConversationTarget?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            LibrarySidebar(library: library)
                .navigationSplitViewColumnWidth(min: 210, ideal: 236, max: 280)
        } detail: {
            HSplitView {
                learningLibrary
                    .frame(
                        minWidth: 480,
                        idealWidth: 720,
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )

                coworkHarness
                    .frame(
                        minWidth: 440,
                        idealWidth: 620,
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
        }
        .navigationTitle("")
        .toolbar(removing: .title)
        .alert(
            "资料库错误",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { isPresented in
                    if !isPresented { library.dismissError() }
                }
            )
        ) {
            Button("好", role: .cancel) {
                library.dismissError()
            }
        } message: {
            Text(library.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var learningLibrary: some View {
        if library.isLoading || library.snapshot == nil {
            ProgressView()
        } else {
            switch library.destination {
            case .library:
                if let document = library.activeDocument {
                    LibraryReaderView(
                        library: library,
                        document: document,
                        onOpenCowork: activateCowork
                    )
                } else {
                    LibraryBrowserPage(
                        library: library,
                        onOpenCowork: activateCowork
                    )
                }
            case .trash:
                LibraryTrashView(library: library)
            }
        }
    }

    @ViewBuilder
    private var coworkHarness: some View {
        if let target = coworkTarget {
            KuzioCoworkHarnessHost(
                library: library,
                target: target
            )
            .id(target.requestID)
        } else {
            ContentUnavailableView {
                Label(
                    "Cowork Harness",
                    systemImage: "bubble.left.and.bubble.right"
                )
                .font(IntatisTypography.body(15, .semibold))
            } description: {
                Text("在左侧文件夹或文件的菜单中选择“AI 对话”。")
                    .font(IntatisTypography.body(13, .regular))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("cowork.harness.empty")
        }
    }

    private func activateCowork(_ entry: LibraryEntry) {
        let path = library.snapshot?.path(to: entry.id).map(\.title)
            ?? [entry.title]
        coworkTarget = KuzioCoworkConversationTarget(
            entry: entry,
            virtualPath: path
        )
    }
}

private struct LibrarySidebar: View {
    @Bindable var library: LibraryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Kuzio")
                .font(IntatisTypography.brand(28, .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 12)

            VStack(spacing: KuzioControlMetrics.sidebarRowSpacing) {
                ForEach(LibraryDestination.allCases) { destination in
                    let isSelected = library.destination == destination

                    Button {
                        library.selectDestination(destination)
                    } label: {
                        Group {
                            if isSelected {
                                destinationRow(destination, isSelected: true)
                                    .glassEffect(
                                        Glass.regular.interactive(),
                                        in: .rect(cornerRadius: KuzioControlMetrics.sidebarCornerRadius)
                                    )
                            } else {
                                destinationRow(destination, isSelected: false)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(destination.title)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)

            Spacer(minLength: 0)
        }
    }

    private func destinationRow(
        _ destination: LibraryDestination,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: KuzioControlMetrics.sidebarContentSpacing) {
            Image(systemName: destination.systemImage)
                .font(.system(size: KuzioControlMetrics.sidebarIconSize, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .frame(width: KuzioControlMetrics.sidebarIconFrameWidth)

            Text(destination.title)
                .font(IntatisTypography.body(
                    13,
                    isSelected ? .semibold : .medium
                ))

            Spacer(minLength: 0)
        }
        .foregroundStyle(isSelected ? .primary : .secondary)
        .padding(.horizontal, KuzioControlMetrics.sidebarHorizontalPadding)
        .padding(.vertical, KuzioControlMetrics.sidebarVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect(cornerRadius: KuzioControlMetrics.sidebarCornerRadius))
    }
}
