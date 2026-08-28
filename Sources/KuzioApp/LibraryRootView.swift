import SwiftUI

struct LibraryRootView: View {
    @Bindable var library: LibraryViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            LibrarySidebar(library: library)
                .navigationSplitViewColumnWidth(min: 210, ideal: 236, max: 280)
        } detail: {
            detail
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
    private var detail: some View {
        if library.isLoading || library.snapshot == nil {
            ProgressView()
        } else {
            switch library.destination {
            case .library:
                if let document = library.activeDocument {
                    LibraryReaderView(library: library, document: document)
                } else {
                    LibraryBrowserPage(library: library)
                }
            case .trash:
                LibraryTrashView(library: library)
            }
        }
    }
}

private struct LibrarySidebar: View {
    @Bindable var library: LibraryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Kuzio")
                .font(KuzioTypography.brand(size: 28))
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
                .font(KuzioTypography.body(
                    size: 13,
                    weight: isSelected ? .semibold : .medium
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
