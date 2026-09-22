import SwiftUI

#if os(macOS)
import AppKit
/// The platform's bitmap image type.
typealias PlatformImage = NSImage
#else
import UIKit
/// The platform's bitmap image type.
typealias PlatformImage = UIImage
#endif

extension Image {
    /// Loads an image from disk, returning `nil` when the file is missing or
    /// unreadable. Callers fall back to a generated placeholder.
    init?(fileURL url: URL) {
        guard
            let data = try? Data(contentsOf: url),
            let image = PlatformImage(data: data)
        else { return nil }
        #if os(macOS)
        self.init(nsImage: image)
        #else
        self.init(uiImage: image)
        #endif
    }
}
