import SwiftUI

/// The state of the project's track, and what to do about it.
///
/// A media file can always go missing. Rather than crashing or pretending, the
/// panel says so plainly and offers the one action that fixes it.
struct AudioTrackPanel: View {
    let project: Project
    let playback: AudioPlaybackController
    let isLoadingWaveform: Bool
    let waveformError: String?

    let onImport: () -> Void
    let onReplace: () -> Void
    let onRemove: () -> Void

    private var asset: ProjectMediaAsset? { project.primaryAudioAsset }

    var body: some View {
        HStack(spacing: Spacing.md) {
            if let asset {
                IconTile(
                    symbolName: asset.isAvailable ? "waveform" : "exclamationmark.triangle",
                    tint: asset.isAvailable ? .teal : .orange,
                    size: 30
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(asset.title)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(subtitle(for: asset))
                        .font(.caption)
                        .foregroundStyle(asset.isAvailable ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(Color.orange))
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.sm)

                if isLoadingWaveform {
                    ProgressView()
                        .controlSize(.small)
                        .help("Analyse de la forme d'onde")
                }

                Menu {
                    Button("Remplacer le morceau…", action: onReplace)
                    Divider()
                    if asset.isAvailable {
                        Text(asset.fileURL.lastPathComponent)
                    }
                    Text("Importé \(AppFormat.relative(asset.importedAt))")
                    Text("Durée \(AppFormat.preciseTimecode(asset.duration))")
                    Text("Échantillonnage \(asset.sampleRateText)")
                    Text("Taille \(asset.fileSizeText)")
                    Divider()
                    Button("Retirer le morceau…", role: .destructive, action: onRemove)
                } label: {
                    Label("Morceau", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                }
                .menuIndicator(.hidden)
                .accessibilityLabel("Options du morceau")
            } else {
                IconTile(symbolName: "waveform.badge.plus", tint: .secondary, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Aucun morceau")
                        .font(.callout.weight(.medium))
                    Text("Importez le master pour caler les sections dessus.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Spacing.sm)
                Button(action: onImport) {
                    Label("Importer un audio", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .overlay(alignment: .bottom) {
            if let message = problemMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(y: 12)
            }
        }
    }

    private var problemMessage: String? {
        if let asset, !asset.isAvailable {
            return "Fichier introuvable. Remplacez le morceau pour retrouver la forme d'onde ; vos sections sont conservées."
        }
        if let waveformError { return waveformError }
        if let failure = playback.failureMessage { return failure }
        return nil
    }

    private func subtitle(for asset: ProjectMediaAsset) -> String {
        guard asset.isAvailable else { return "Fichier introuvable" }
        return [
            AppFormat.preciseTimecode(asset.duration),
            asset.sampleRateText,
            asset.fileSizeText
        ].joined(separator: " · ")
    }
}
