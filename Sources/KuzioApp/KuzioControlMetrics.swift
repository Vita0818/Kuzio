import SwiftUI

enum KuzioControlMetrics {
    static let iconButtonSize: CGFloat = 36
    static let iconSymbolSize: CGFloat = 15
    static let iconButtonSpacing: CGFloat = 8
    static let disabledIconButtonOpacity: Double = 0.46

    static let sidebarRowSpacing: CGFloat = 6
    static let sidebarContentSpacing: CGFloat = 8
    static let sidebarIconSize: CGFloat = 13
    static let sidebarIconFrameWidth: CGFloat = 20
    static let sidebarHorizontalPadding: CGFloat = 12
    static let sidebarVerticalPadding: CGFloat = 10
    static let sidebarCornerRadius: CGFloat = 15

    static let folderIconWidth: CGFloat = 58
    static let folderIconHeight: CGFloat = 50
    static let folderIconContainerHeight: CGFloat = 52
    static let gridTileHeight: CGFloat = 152
    static let gridTileTitleHeight: CGFloat = 34
    static let gridTileDetailHeight: CGFloat = 13
    static let cardSymbolSize: CGFloat = 21
    static let cardIconFrameSize: CGFloat = 42
}

struct KuzioCircleIconLabel: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: KuzioControlMetrics.iconSymbolSize, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .frame(
                width: KuzioControlMetrics.iconButtonSize,
                height: KuzioControlMetrics.iconButtonSize
            )
            .contentShape(.interaction, Circle())
    }
}

private struct KuzioCircleIconControlModifier: ViewModifier {
    let accessibilityTitle: String
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .frame(
                width: KuzioControlMetrics.iconButtonSize,
                height: KuzioControlMetrics.iconButtonSize
            )
            .contentShape(.interaction, Circle())
            .glassEffect(Glass.regular.interactive(), in: .circle)
            .opacity(isEnabled ? 1 : KuzioControlMetrics.disabledIconButtonOpacity)
            .help(accessibilityTitle)
            .accessibilityLabel(accessibilityTitle)
    }
}

extension View {
    func kuzioCircleIconControl(accessibilityTitle: String) -> some View {
        modifier(KuzioCircleIconControlModifier(accessibilityTitle: accessibilityTitle))
    }
}

struct KuzioCircleIconButton: View {
    let systemImage: String
    let accessibilityTitle: String
    var isEnabled = true
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            KuzioCircleIconLabel(systemImage: systemImage)
        }
        .kuzioCircleIconControl(accessibilityTitle: accessibilityTitle)
        .disabled(!isEnabled)
    }
}
