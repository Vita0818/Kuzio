import Foundation
import SwiftUI

@main
struct KuzioApp: App {
    @State private var library = LibraryViewModel()

    init() {
        KuzioTypography.ensureAvailable()
    }

    var body: some Scene {
        WindowGroup {
            LibraryRootView(library: library)
                .frame(minWidth: 1_040, minHeight: 690)
                .font(KuzioTypography.body())
                .preferredColorScheme(debugAppearanceOverride)
                .task {
                    await library.start()
                }
        }
        .defaultSize(width: 1_100, height: 760)
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
