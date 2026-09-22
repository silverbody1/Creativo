import SwiftUI

/// Transport controls for the track.
///
/// The shortcuts are removed, not disabled, while a text field has focus:
/// nothing is more infuriating than a space bar that plays music instead of
/// typing a space.
struct TimelineTransportBar: View {
    let playback: AudioPlaybackController
    var shortcutsEnabled: Bool = true

    var body: some View {
        HStack(spacing: Spacing.md) {
            Button {
                playback.restart()
            } label: {
                Image(systemName: "backward.end.fill")
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(shortcut(.home, modifiers: []))
            .help("Retour au début")
            .accessibilityLabel("Retour au début")

            Button {
                playback.skip(by: -PlaybackMath.coarseStep)
            } label: {
                Image(systemName: "gobackward.5")
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(shortcut(.leftArrow, modifiers: .shift))
            .help("Reculer de 5 secondes")
            .accessibilityLabel("Reculer de cinq secondes")

            Button {
                playback.toggle()
            } label: {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 38, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!playback.hasAudio)
            .keyboardShortcut(shortcut(.space, modifiers: []))
            .help(playback.isPlaying ? "Pause (Espace)" : "Lecture (Espace)")
            .accessibilityLabel(playback.isPlaying ? "Pause" : "Lecture")

            Button {
                playback.skip(by: PlaybackMath.coarseStep)
            } label: {
                Image(systemName: "goforward.5")
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(shortcut(.rightArrow, modifiers: .shift))
            .help("Avancer de 5 secondes")
            .accessibilityLabel("Avancer de cinq secondes")

            // Frame-by-frame nudging has no button of its own: it is a
            // keyboard gesture, not something to click.
            Button("Reculer d'une image") { playback.skip(by: -PlaybackMath.fineStep) }
                .buttonStyle(.plain)
                .keyboardShortcut(shortcut(.leftArrow, modifiers: []))
                .frame(width: 1, height: 1)
                .opacity(0.02)
                .accessibilityHidden(true)
            Button("Avancer d'une image") { playback.skip(by: PlaybackMath.fineStep) }
                .buttonStyle(.plain)
                .keyboardShortcut(shortcut(.rightArrow, modifiers: []))
                .frame(width: 1, height: 1)
                .opacity(0.02)
                .accessibilityHidden(true)

            TransportTimecodeView(playback: playback)
        }
    }

    /// `nil` removes the shortcut entirely while the user is typing.
    private func shortcut(_ key: KeyEquivalent, modifiers: EventModifiers) -> KeyboardShortcut? {
        shortcutsEnabled ? KeyboardShortcut(key, modifiers: modifiers) : nil
    }
}

/// The running timecode.
///
/// Its own view so that thirty updates a second redraw one label rather than
/// the whole transport.
struct TransportTimecodeView: View {
    let playback: AudioPlaybackController

    var body: some View {
        Text(AppFormat.transportTimecode(playback.currentTime, of: playback.duration))
            .font(.system(.callout, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .accessibilityLabel("Position de lecture")
            .accessibilityValue(
                "\(AppFormat.preciseTimecode(playback.currentTime)) sur \(AppFormat.preciseTimecode(playback.duration))"
            )
    }
}
