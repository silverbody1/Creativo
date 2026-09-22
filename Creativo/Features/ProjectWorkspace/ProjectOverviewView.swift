import SwiftUI
import SwiftData

/// Project dashboard: identity, key figures and what is left to prepare.
struct ProjectOverviewView: View {
    @Bindable var project: Project

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingSettings = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.xxl) {
                identityCard
                statsSection
                if !project.synopsis.isBlank {
                    synopsisSection
                }
                insightsSection
            }
            .padding(Spacing.xl)
            .readableContentWidth()
        }
        .navigationTitle("Vue d'ensemble")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingSettings = true
                } label: {
                    Label("Modifier", systemImage: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $isPresentingSettings) {
            ProjectSettingsSheet(project: project)
        }
    }

    // MARK: Identity

    private var identityCard: some View {
        WidthReader { width in
            let compact = width.prefersCompactLayout
            Group {
                if compact {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        ProjectCoverView(project: project)
                        identityDetails
                    }
                } else {
                    HStack(alignment: .top, spacing: Spacing.xl) {
                        ProjectCoverView(project: project)
                            .frame(width: 260)
                        identityDetails
                    }
                }
            }
            .cardSurface(padding: Spacing.lg)
        }
    }

    private var identityDetails: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(project.displayName)
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .lineLimit(2)
                Button {
                    ProjectService.toggleFavorite(project, in: modelContext)
                } label: {
                    Image(systemName: project.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(project.isFavorite ? Color.yellow : Color.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(project.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
            }

            HStack(spacing: Spacing.sm) {
                Chip(
                    text: project.type.displayName,
                    symbolName: project.type.symbolName,
                    tint: project.type.tint
                )
                statusMenu
            }

            Grid(alignment: .leading, horizontalSpacing: Spacing.xl, verticalSpacing: Spacing.sm) {
                GridRow {
                    metadata("Budget cible", AppFormat.optionalCurrency(project.targetBudget, placeholder: "Non défini"))
                    metadata("Dernière modification", AppFormat.relative(project.updatedAt))
                }
                GridRow {
                    metadata("Créé le", AppFormat.shortDate(project.createdAt))
                    metadata("Prochain tournage", nextShootDayText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusMenu: some View {
        Menu {
            ForEach(ProjectStatus.allCases) { status in
                Button {
                    ProjectService.setStatus(status, on: project, in: modelContext)
                } label: {
                    Label(status.displayName, systemImage: status.symbolName)
                }
            }
        } label: {
            Chip(
                text: project.status.displayName,
                symbolName: project.status.symbolName,
                tint: project.status.tint
            )
        }
        .fixedSize()
        .accessibilityLabel("Statut du projet, \(project.status.displayName)")
    }

    private func metadata(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .lineLimit(1)
        }
    }

    private var nextShootDayText: String {
        guard let next = project.nextShootDay else { return "Non planifié" }
        return AppFormat.longDate(next.date)
    }

    // MARK: Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeaderView("Chiffres clés")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: LayoutMetrics.statCardMinWidth), spacing: Spacing.md)],
                spacing: Spacing.md
            ) {
                sceneCard
                shotCard
                budgetCard
                locationCard
                crewCard
                shootDayCard
            }
        }
    }

    private var sceneCard: some View {
        let totalDuration = project.scenes.reduce(0) { $0 + $1.estimatedDuration }
        return StatCard(
            title: "Scènes",
            value: "\(project.scenes.count)",
            caption: totalDuration > 0 ? "≈ \(AppFormat.duration(totalDuration))" : "Durée non estimée",
            symbolName: "list.bullet.rectangle",
            tint: .blue
        )
    }

    private var shotCard: some View {
        let progress = project.shotProgress
        return StatCard(
            title: "Plans",
            value: "\(project.allShots.count)",
            caption: progress.total > 0 ? "\(progress.completed)/\(progress.total) tournés" : "Aucun plan prévu",
            symbolName: "camera.viewfinder",
            tint: .teal,
            progress: progress.total > 0 ? Double(progress.completed) / Double(progress.total) : nil
        )
    }

    private var budgetCard: some View {
        let summary = project.budgetSummary
        return StatCard(
            title: "Budget",
            value: AppFormat.currency(summary.forecast),
            caption: summary.target.map { "sur \(AppFormat.currency($0))" } ?? "Pas de cible définie",
            symbolName: "eurosign.circle",
            tint: summary.isOverTarget ? .red : .green,
            progress: summary.forecastRatio
        )
    }

    private var locationCard: some View {
        StatCard(
            title: "Lieux",
            value: "\(project.locations.count)",
            caption: AppFormat.count(
                project.scenes.filter { $0.location != nil }.count,
                singular: "scène localisée",
                plural: "scènes localisées",
                zero: "Aucune scène localisée"
            ),
            symbolName: "mappin.and.ellipse",
            tint: .pink
        )
    }

    private var crewCard: some View {
        let departments = Set(project.peopleAssignments.map(\.effectiveRole.department)).count
        return StatCard(
            title: "Équipe",
            value: "\(project.peopleAssignments.count)",
            caption: AppFormat.count(departments, singular: "département", plural: "départements", zero: "Aucun département"),
            symbolName: "person.2",
            tint: .indigo
        )
    }

    private var shootDayCard: some View {
        StatCard(
            title: "Jours de tournage",
            value: "\(project.shootDays.count)",
            caption: nextShootDayText,
            symbolName: "calendar",
            tint: .orange
        )
    }

    // MARK: Synopsis

    private var synopsisSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeaderView("Synopsis")
            Text(project.synopsis)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
        }
    }

    // MARK: Insights

    private var insightsSection: some View {
        let insights = ProjectInsights.insights(for: project)
        return VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeaderView(
                "À préparer",
                subtitle: insights.isEmpty ? nil : AppFormat.count(insights.count, singular: "point", plural: "points", zero: "")
            )

            if insights.isEmpty {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Tout est en place")
                            .font(.headline)
                        Text("Scènes, plans, budget, lieux, équipe et planning sont renseignés.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .cardSurface()
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(insights) { insight in
                        Button {
                            appState.workspaceSection = insight.section
                        } label: {
                            HStack(spacing: Spacing.md) {
                                IconTile(symbolName: insight.symbolName, tint: .orange, size: 36)
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(insight.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(insight.message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: Spacing.sm)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .cardSurface(radius: CornerRadius.medium, padding: Spacing.md)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProjectOverviewView(project: SampleData.previewProject())
    }
    .environment(AppState())
    .modelContainer(SampleData.previewContainer)
}
