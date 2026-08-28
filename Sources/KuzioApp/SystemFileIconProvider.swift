import AppKit
import UniformTypeIdentifiers

@MainActor
enum SystemFileIconProvider {
    private static let folderImage: NSImage = {
        let source = NSWorkspace.shared.icon(for: .folder)
        guard let image = source.copy() as? NSImage else {
            fatalError("The native macOS folder icon could not be copied.")
        }
        image.size = NSSize(width: 96, height: 96)
        image.isTemplate = false
        return image
    }()

    static func folder() -> NSImage {
        folderImage
    }

    static func file(contentTypeIdentifier: String?, filename: String) -> NSImage {
        let filenameExtension = (filename as NSString).pathExtension
        let contentType = contentTypeIdentifier.flatMap(UTType.init)
            ?? UTType(filenameExtension: filenameExtension)
            ?? .data
        let source = NSWorkspace.shared.icon(for: contentType)
        guard let image = source.copy() as? NSImage else {
            fatalError("The native macOS file icon could not be copied.")
        }
        image.size = NSSize(width: 96, height: 96)
        image.isTemplate = false
        return image
    }
}
