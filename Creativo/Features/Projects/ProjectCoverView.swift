import SwiftUI

/// Cover art of a project.
///
/// Falls back to a generated gradient keyed on the project type, so a project
/// without a cover still looks deliberate rather than unfinished.
struct ProjectCoverView: View {
    let project: Project
    var cornerRadius: CGFloat = CornerRadius.medium

    var body: some View {
        ZStack {
            if let image = coverImage {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .aspectRatio(LayoutMetrics.coverAspectRatio, contentMode: .fill)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private var coverImage: Image? {
        guard let path = project.coverImagePath else { return nil }
        return Image(fileURL: MediaStore.shared.url(forRelativePath: path))
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [
                project.type.tint.opacity(0.85),
                project.type.tint.opacity(0.35)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: project.type.symbolName)
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(.white.opacity(0.28))
                .padding(Spacing.md)
        }
    }
}

#Preview {
    ProjectCoverView(project: Project(name: "PARTENAIRE", type: .musicVideo))
        .frame(width: 280)
        .padding()
}
