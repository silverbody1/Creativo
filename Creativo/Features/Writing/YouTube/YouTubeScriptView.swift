import SwiftUI
import SwiftData

/// The YouTube writing surface: an outline of blocks, with a live duration.
///
/// A video script is not a scene breakdown, so blocks belong to the project.
/// Any block that deserves a shot list, a location or a shooting day can be
/// promoted into a real scene, which is what keeps the writing connected to
/// the rest of the production.
struct YouTubeScriptView: View {
    @Bindable var project: Project
    var isFocusMode: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var blockPendingDeletion: YouTubeBlock?

    private var blocks: [YouTubeBlock] { project.sortedYouTubeBlocks }
    private var visibleBlocks: [YouTubeBlock] { YouTubeScriptService.visibleBlocks(in: blocks) }
    private var hasCollapsedSection: Bool { blocks.contains { $0.kind.isHeader && $0.isCollapsed } }

    private var metrics: ScriptMetrics {
        ScriptMetricsCalculator.metrics(for: blocks, wordsPerMinute: project.wordsPerMinute)
    }

    var body: some View {
        WidthReader { width in
            let compact = width.prefersCompactLayout
            Group {
                if blocks.isEmpty {
                    emptyState
                } else {
                    list(compact: compact)
                }
            }
        }
        .navigationTitle("Écriture")
        .inlineNavigationTitle()
        .toolbar { toolbarContent }
        .confirmationDialog(
            "Supprimer ce bloc ?",
            isPresented: deletionBinding,
            presenting: blockPendingDeletion
        ) { block in
            Button("Supprimer", role: .destructive) {
                YouTubeScriptService.delete(block, context: modelContext)
                blockPendingDeletion = nil
            }
            Button("Annuler", role: .cancel) { blockPendingDeletion = nil }
        } message: { block in
            Text("« \(block.displayTitle) » sera retiré du script.")
        }
    }

    // MARK: List

    private func list(compact: Bool) -> some View {
        List {
            if !isFocusMode {
                Section {
                    metricsCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach(visibleBlocks) { block in
                    YouTubeBlockRow(
                        block: block,
                        childCount: YouTubeScriptService.childCount(of: block, in: blocks),
                        isCompact: compact,
                        onChangeKind: { kind in
                            YouTubeScriptService.setKind(kind, on: block, context: modelContext)
                        },
                        onToggleCollapse: {
                            YouTubeScriptService.toggleCollapse(block, context: modelContext)
                        },
                        onInsertAfter: {
                            YouTubeScriptService.insert(block.kind.isHeader ? .aRoll : block.kind, after: block, context: modelContext)
                        },
                        onMove: { delta in
                            YouTubeScriptService.shift(block, by: delta, context: modelContext)
                        },
                        onPromote: {
                            YouTubeScriptService.promoteToScene(block, context: modelContext)
                        },
                        onDelete: { blockPendingDeletion = block },
                        onEndEditing: {
                            YouTubeScriptService.commitEdits(to: block, context: modelContext)
                        }
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            blockPendingDeletion = block
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: hasCollapsedSection ? nil : move)
            } footer: {
                if hasCollapsedSection {
                    Text("Dépliez tous les chapitres pour pouvoir réorganiser les blocs par glissement. Monter et descendre restent disponibles dans le menu contextuel.")
                        .font(.caption)
                }
            }

            Section {
                addBlockMenu
            }
        }
    }

    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.lg) {
                figure("Durée estimée", AppFormat.duration(metrics.estimatedDuration), tint: .blue)
                figure("Mots parlés", "\(metrics.spokenWords)", tint: .teal)
                figure("Mots au total", "\(metrics.totalWords)", tint: .secondary)
                figure(
                    "Chapitres",
                    AppFormat.count(metrics.sectionCount, singular: "chapitre", plural: "chapitres", zero: "0"),
                    tint: .indigo
                )
            }

            HStack(spacing: Spacing.md) {
                Picker("Débit de parole", selection: rateBinding) {
                    ForEach(ScriptMetricsCalculator.speakingRates, id: \.self) { rate in
                        Text("\(rate) mots/min").tag(rate)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()

                Spacer(minLength: Spacing.sm)

                AutosaveIndicator(date: project.updatedAt)
            }
        }
        .cardSurface()
        .padding(.vertical, Spacing.sm)
    }

    private func figure(_ label: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addBlockMenu: some View {
        Menu {
            ForEach(YouTubeBlockKind.commonOrder) { kind in
                Button {
                    YouTubeScriptService.append(kind, to: project, context: modelContext)
                } label: {
                    Label(kind.displayName, systemImage: kind.symbolName)
                }
            }
        } label: {
            Label("Ajouter un bloc", systemImage: "plus")
                .touchTarget()
        } primaryAction: {
            YouTubeScriptService.append(.aRoll, to: project, context: modelContext)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
    }

    private var emptyState: some View {
        EmptyStateView(
            symbolName: "play.rectangle.on.rectangle",
            title: "Script vide",
            message: "Écrivez votre vidéo par blocs : accroche, intro, chapitres, A-roll, B-roll, voix off et appel à l'action. La durée se calcule à partir de ce qui sera réellement dit.",
            tint: .red
        ) {
            VStack(spacing: Spacing.sm) {
                Button {
                    YouTubeScriptService.starterOutline(for: project, context: modelContext)
                } label: {
                    Label("Partir d'une structure type", systemImage: "list.bullet.indent")
                        .touchTarget()
                        .padding(.horizontal, Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Commencer avec un bloc vide") {
                    YouTubeScriptService.append(.hook, to: project, context: modelContext)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                ForEach(YouTubeBlockKind.commonOrder) { kind in
                    Button {
                        YouTubeScriptService.append(kind, to: project, context: modelContext)
                    } label: {
                        Label(kind.displayName, systemImage: kind.symbolName)
                    }
                }
            } label: {
                Label("Ajouter un bloc", systemImage: "plus")
            }
        }

        ToolbarItem(placement: .automatic) {
            Button {
                appState.isWritingFocusMode.toggle()
            } label: {
                Label(
                    isFocusMode ? "Quitter le mode focus" : "Mode focus",
                    systemImage: isFocusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
                )
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
        }

        ToolbarItem(placement: .automatic) {
            Menu {
                Button {
                    modelContext.undoManager?.undo()
                } label: {
                    Label("Annuler la dernière modification", systemImage: "arrow.uturn.backward")
                }
                .disabled(modelContext.undoManager?.canUndo != true)

                Button {
                    modelContext.undoManager?.redo()
                } label: {
                    Label("Rétablir", systemImage: "arrow.uturn.forward")
                }
                .disabled(modelContext.undoManager?.canRedo != true)

                Divider()

                Button("Replier tous les chapitres") { setCollapsed(true) }
                Button("Déplier tous les chapitres") { setCollapsed(false) }
            } label: {
                Label("Plus", systemImage: "ellipsis.circle")
            }
        }
    }

    // MARK: Actions

    private var rateBinding: Binding<Int> {
        Binding(
            get: { project.wordsPerMinute },
            set: { newValue in
                project.wordsPerMinute = newValue
                project.touch()
                PersistenceActions.save(modelContext)
            }
        )
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { blockPendingDeletion != nil },
            set: { if !$0 { blockPendingDeletion = nil } }
        )
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        YouTubeScriptService.move(fromOffsets: offsets, toOffset: destination, in: project, context: modelContext)
    }

    private func setCollapsed(_ collapsed: Bool) {
        for block in blocks where block.kind.isHeader && block.isCollapsed != collapsed {
            YouTubeScriptService.toggleCollapse(block, context: modelContext)
        }
    }
}
