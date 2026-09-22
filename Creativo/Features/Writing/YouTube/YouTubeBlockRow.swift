import SwiftUI
import SwiftData

/// One block of a video script.
///
/// A chapter folds what follows it; every other kind is a small editor with a
/// title and a body. The kind is always one tap away, because a script is
/// rewritten far more often than it is written.
struct YouTubeBlockRow: View {
    @Bindable var block: YouTubeBlock
    var childCount: Int
    var isCompact: Bool

    let onChangeKind: (YouTubeBlockKind) -> Void
    let onToggleCollapse: () -> Void
    let onInsertAfter: () -> Void
    let onMove: (Int) -> Void
    let onPromote: () -> Void
    let onDelete: () -> Void
    let onEndEditing: () -> Void

    var body: some View {
        Group {
            if block.kind.isHeader {
                sectionHeader
            } else {
                blockBody
            }
        }
        .contextMenu { menu }
    }

    // MARK: Section header

    private var sectionHeader: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: onToggleCollapse) {
                Image(systemName: block.isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(block.isCollapsed ? "Déplier le chapitre" : "Replier le chapitre")

            TextField("Titre du chapitre", text: $block.title)
                .textFieldStyle(.plain)
                .font(.headline)
                .onSubmit(onEndEditing)

            if block.isCollapsed && childCount > 0 {
                Chip(
                    text: AppFormat.count(childCount, singular: "bloc", plural: "blocs", zero: ""),
                    style: .neutral
                )
            }

            kindMenu
        }
        .padding(.vertical, Spacing.sm)
        .touchTarget()
    }

    // MARK: Regular block

    private var blockBody: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Chip(
                    text: block.kind.displayName,
                    symbolName: block.kind.symbolName,
                    tint: tint
                )

                TextField("Titre (optionnel)", text: $block.title)
                    .textFieldStyle(.plain)
                    .font(.subheadline.weight(.medium))
                    .onSubmit(onEndEditing)

                Spacer(minLength: Spacing.xs)

                if block.scene != nil {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.caption)
                        .foregroundStyle(.teal)
                        .help("Relié à une scène")
                }

                if block.kind.isSpoken && !isCompact {
                    Text("\(ScriptMetricsCalculator.wordCount(in: block.text)) mots")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                kindMenu
            }

            TextField(placeholder, text: $block.text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(block.kind.isSpoken ? .body : .callout)
                .foregroundStyle(block.kind.isSpoken ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.secondary))
                .lineLimit(2...14)

            if block.kind == .source {
                TextField("https://…", text: $block.urlString)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .rawTextField()
                    .onSubmit(onEndEditing)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var tint: Color {
        switch block.kind {
        case .hook: return .orange
        case .intro: return .blue
        case .section: return .indigo
        case .aRoll: return .teal
        case .bRoll: return .purple
        case .voiceOver: return .pink
        case .callToAction: return .green
        case .editNote: return .yellow
        case .source: return .gray
        }
    }

    private var placeholder: String {
        switch block.kind {
        case .hook: return "Les dix premières secondes qui retiennent."
        case .intro: return "Ce que la vidéo promet."
        case .section: return "Résumé du chapitre."
        case .aRoll: return "Ce que vous dites face caméra."
        case .bRoll: return "Ce que l'on voit pendant."
        case .voiceOver: return "Texte lu en voix off."
        case .callToAction: return "Ce que vous demandez au spectateur."
        case .editNote: return "Indication pour le montage."
        case .source: return "Référence, étude, citation."
        }
    }

    private var kindMenu: some View {
        Menu {
            ForEach(YouTubeBlockKind.commonOrder) { kind in
                Button {
                    onChangeKind(kind)
                } label: {
                    Label(kind.displayName, systemImage: kind.symbolName)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .accessibilityLabel("Type de bloc, \(block.kind.displayName)")
    }

    @ViewBuilder
    private var menu: some View {
        Menu("Type") {
            ForEach(YouTubeBlockKind.commonOrder) { kind in
                Button {
                    onChangeKind(kind)
                } label: {
                    Label(kind.displayName, systemImage: kind.symbolName)
                }
            }
        }
        Button("Insérer un bloc en dessous", action: onInsertAfter)
        Divider()
        Button("Monter") { onMove(-1) }
        Button("Descendre") { onMove(1) }
        if block.kind.canBecomeScene && block.scene == nil {
            Divider()
            Button("Transformer en scène", action: onPromote)
        }
        Divider()
        Button("Supprimer", role: .destructive, action: onDelete)
    }
}
