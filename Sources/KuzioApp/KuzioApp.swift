import Foundation
import IntatisSharedUI
import SwiftUI

@main
struct KuzioApp: App {
    @State private var library = LibraryViewModel()

    init() {
        KuzioCodexRuntimeIntegration.configureHost()
        KuzioCodexRuntimeIntegration.validateHostContract()
        IntatisTypography.prepareJetBrainsMonoTypography()
    }

    var body: some Scene {
        WindowGroup {
            LibraryRootView(library: library)
                .frame(minWidth: 1_180, minHeight: 690)
                .font(IntatisTypography.body(14, .regular))
                .preferredColorScheme(debugAppearanceOverride)
                .task {
                    await library.start()
                }
        }
        .defaultSize(width: 1_520, height: 820)
        .windowResizability(.contentMinSize)
    }

    private var debugAppearanceOverride: ColorScheme? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-KuzioAppearanceLight") {
            return .light
        }
        if arguments.contains("-KuzioAppearanceDark") {
            return .dark
        }
        #endif
        return nil
    }
}
