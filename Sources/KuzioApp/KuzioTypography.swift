import AppKit
import CoreText
import CryptoKit
import Foundation
import SwiftUI

@MainActor
enum KuzioTypography {
    private struct FontResource: Sendable {
        let fileName: String
        let postScriptName: String
        let sha256: String
    }

    private static let resources = [
        FontResource(
            fileName: "JetBrainsMono-Regular",
            postScriptName: "JetBrainsMono-Regular",
            sha256: "a0bf60ef0f83c5ed4d7a75d45838548b1f6873372dfac88f71804491898d138f"
        ),
        FontResource(
            fileName: "JetBrainsMono-Medium",
            postScriptName: "JetBrainsMono-Medium",
            sha256: "31c92d01a8a08528b718a43addf0ad3df0af2ca4b7b3290a452f70f358e14d3d"
        ),
        FontResource(
            fileName: "JetBrainsMono-SemiBold",
            postScriptName: "JetBrainsMono-SemiBold",
            sha256: "1b3bfa1ed5665a4ce3f9feb68d2d4e40e70bf8b4b7d9a3edd418f321b4e166a0"
        ),
        FontResource(
            fileName: "JetBrainsMono-Bold",
            postScriptName: "JetBrainsMono-Bold",
            sha256: "5590990c82e097397517f275f430af4546e1c45cff408bde4255dad142479dcb"
        ),
    ]

    static func ensureAvailable() {
        _ = registrationCheck
    }

    static func brand(size: CGFloat = 28) -> Font {
        font(size: size, weight: .semibold)
    }

    static func pageTitle(size: CGFloat = 32) -> Font {
        font(size: size, weight: .bold)
    }

    static func sectionTitle(size: CGFloat = 17) -> Font {
        font(size: size, weight: .semibold)
    }

    static func cardTitle(size: CGFloat = 16, weight: Font.Weight = .semibold) -> Font {
        font(size: size, weight: weight)
    }

    static func body(size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
        font(size: size, weight: weight)
    }

    static func metadata(size: CGFloat = 12, weight: Font.Weight = .medium) -> Font {
        font(size: size, weight: weight)
    }

    static func caption(size: CGFloat = 11, weight: Font.Weight = .semibold) -> Font {
        font(size: size, weight: weight)
    }

    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        ensureAvailable()
        return .custom(postScriptName(for: weight), fixedSize: size)
    }

    private static let registrationCheck: Void = {
        for resource in resources {
            guard let url = resourceBundle.url(
                forResource: resource.fileName,
                withExtension: "ttf",
                subdirectory: "Fonts"
            ) else {
                fatalError("Required font resource Fonts/\(resource.fileName).ttf is missing.")
            }

            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
                fatalError("Required font resource \(resource.fileName).ttf cannot be read.")
            }

            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard digest == resource.sha256 else {
                fatalError("Required font resource \(resource.fileName).ttf failed its SHA-256 check.")
            }

            var registrationError: Unmanaged<CFError>?
            guard CTFontManagerRegisterFontsForURL(
                url as CFURL,
                .process,
                &registrationError
            ) else {
                let detail = registrationError
                    .map { String(describing: $0.takeRetainedValue()) }
                    ?? "unknown Core Text error"
                fatalError("Required font \(resource.postScriptName) could not be registered: \(detail)")
            }

            guard NSFont(name: resource.postScriptName, size: 12) != nil else {
                fatalError("Required font \(resource.postScriptName) is unavailable after registration.")
            }
        }
    }()

    private static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }

    private static func postScriptName(for weight: Font.Weight) -> String {
        if weight == .bold || weight == .heavy || weight == .black {
            return "JetBrainsMono-Bold"
        }
        if weight == .semibold {
            return "JetBrainsMono-SemiBold"
        }
        if weight == .medium {
            return "JetBrainsMono-Medium"
        }
        return "JetBrainsMono-Regular"
    }
}
