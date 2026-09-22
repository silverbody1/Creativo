import SwiftUI

/// Reports the width of its container to its content.
///
/// Used instead of `horizontalSizeClass`, which does not exist on macOS.
/// Measuring the real container also behaves correctly under Stage Manager and
/// in iPad multitasking, where the window can be any width at all.
struct WidthReader<Content: View>: View {
    @ViewBuilder var content: (CGFloat) -> Content
    @State private var width: CGFloat = 0

    var body: some View {
        content(width)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onChange(of: proxy.size.width, initial: true) { _, newWidth in
                            // Ignore sub-pixel jitter, which would otherwise
                            // bounce the layout between its two arrangements.
                            if abs(newWidth - width) > 0.5 { width = newWidth }
                        }
                }
            }
    }
}

extension CGFloat {
    /// `true` when a container this wide should use its compact arrangement.
    /// Zero means "not measured yet", which must not flip the layout.
    var prefersCompactLayout: Bool {
        self > 0 && self < LayoutMetrics.compactWidthThreshold
    }
}
