import SwiftUI
import SwiftData

/// A scene in the screenplay editor: its heading, then its lines.
struct ScreenplaySceneBlock: View {
    @Bindable var scene: StoryScene
    var isCompact: Bool
    @FocusState.Binding var focusedElementID: UUID?

    let onAddElement: (ScreenplayElementType) -> Void
    let onDeleteScene: () -> Void

    @Environment(\.modelContext) private var modelContext

    private var elements: [ScreenplayElement] { scene.sortedScreenplayElements }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenplaySceneHeadingRow(scene: scene, onDelete: onDeleteScene)
                .padding(.bottom, Spacing.sm)

            ForEach(Array(elements.enumerated()), id: \.element.id) { index, element in
                ScreenplayElementRow(
                    element: element,
                    previousType: index > 0 ? elements[index - 1].type : nil,
                    isCompact: isCompact,
                    focusedElementID: $focusedElementID,
                    onChangeType: { type in
                        ScreenplayService.setType(type, on: element, context: modelContext)
                    },
                    onInsertAfter: {
                        if let inserted = ScreenplayService.insert(after: element, context: modelContext) {
                            focusedElementID = inserted.id
                        }
                    },
                    onDelete: {
                        if focusedElementID == element.id { focusedElementID = nil }
                        ScreenplayService.delete(element, context: modelContext)
                    },
                    onMove: { delta in
                        ScreenplayService.shift(element, by: delta, context: modelContext)
                    },
                    onEndEditing: {
                        ScreenplayService.commitEdits(to: element, context: modelContext)
                    }
                )
            }

            addLineButton
                .padding(.top, Spacing.md)
        }
        .padding(.vertical, Spacing.lg)
        .id(scene.id)
    }

    private var addLineButton: some View {
        Menu {
            ForEach(ScreenplayElementType.allCases) { type in
                Button {
                    onAddElement(type)
                } label: {
                    Label(type.displayName, systemImage: type.symbolName)
                }
            }
        } label: {
            Label(elements.isEmpty ? "Commencer à écrire" : "Ajouter une ligne", systemImage: "plus")
                .font(.callout)
                .touchTarget(36)
        } primaryAction: {
            onAddElement(elements.last?.type.naturalSuccessor ?? .action)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
    }
}

/// The scene heading, bound to the scene's real fields rather than to free text.
///
/// Editing the slug line therefore edits the breakdown: the same interior,
/// location and time of day drive the schedule, the shot list and the budget.
struct ScreenplaySceneHeadingRow: View {
    @Bindable var scene: StoryScene
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext

    private var locations: [ProductionLocation] {
        scene.project?.sortedLocations ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Text(scene.displayNumber)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 26, alignment: .leading)

                Menu {
                    ForEach(SceneEnvironment.allCases) { value in
                        Button(value.displayName) {
                            scene.environment = value
                            commit()
                        }
                    }
                } label: {
                    Text(scene.environment.abbreviation)
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .fixedSize()

                TextField("LIEU", text: $scene.title)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .onSubmit(commit)

                Text("—")
                    .foregroundStyle(.tertiary)

                Menu {
                    ForEach(TimeOfDay.allCases) { value in
                        Button(value.displayName) {
                            scene.timeOfDay = value
                            commit()
                        }
                    }
                } label: {
                    Text(scene.timeOfDay.displayName.uppercased())
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .fixedSize()

                Spacer(minLength: Spacing.sm)

                Menu {
                    Menu("Lieu de tournage") {
                        Button("Aucun") {
                            scene.location = nil
                            commit()
                        }
                        ForEach(locations) { location in
                            Button(location.displayName) {
                                scene.location = location
                                commit()
                            }
                        }
                    }
                    Menu("Statut") {
                        ForEach(SceneStatus.allCases) { status in
                            Button {
                                scene.status = status
                                commit()
                            } label: {
                                Label(status.displayName, systemImage: status.symbolName)
                            }
                        }
                    }
                    Divider()
                    Button("Supprimer la scène", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.tertiary)
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .fixedSize()
            }

            if let location = scene.location {
                Chip(text: location.displayName, symbolName: "mappin", tint: .pink)
                    .padding(.leading, 34)
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .background(Surface.subtle, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
    }

    private func commit() {
        SceneService.commitEdits(to: scene, context: modelContext)
    }
}
