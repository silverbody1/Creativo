import SwiftUI
import SwiftData

/// First version of the schedule: an ordered list of shooting days.
///
/// The calendar, the day-by-day strip board and the call sheets are separate
/// phases. `ShootDay` already carries the relationships they will need.
struct ScheduleView: View {
    @Bindable var project: Project

    @Environment(\.modelContext) private var modelContext
    @State private var dayBeingEdited: ShootDay?
    @State private var dayPendingDeletion: ShootDay?

    private var days: [ShootDay] { project.sortedShootDays }

    var body: some View {
        Group {
            if days.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Planning")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addDay()
                } label: {
                    Label("Nouvelle journée", systemImage: "plus")
                }
            }
        }
        .sheet(item: $dayBeingEdited) { day in
            ShootDayEditorSheet(day: day)
        }
        .confirmationDialog(
            "Supprimer cette journée ?",
            isPresented: deletionBinding,
            presenting: dayPendingDeletion
        ) { day in
            Button("Supprimer", role: .destructive) {
                ScheduleService.delete(day, in: modelContext)
                dayPendingDeletion = nil
            }
            Button("Annuler", role: .cancel) { dayPendingDeletion = nil }
        } message: { day in
            Text("« \(day.displayTitle) » sera retirée du planning.")
        }
    }

    private var list: some View {
        List {
            Section {
                HStack {
                    Text(AppFormat.count(days.count, singular: "journée", plural: "journées", zero: "Aucune journée"))
                    Spacer()
                    if let first = days.first, let last = days.last, days.count > 1 {
                        Text("\(AppFormat.shortDate(first.date)) → \(AppFormat.shortDate(last.date))")
                            .monospacedDigit()
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(nil)
            }

            ForEach(days) { day in
                Button {
                    dayBeingEdited = day
                } label: {
                    ShootDayRow(day: day)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Modifier") { dayBeingEdited = day }
                    Divider()
                    Button("Supprimer…", role: .destructive) { dayPendingDeletion = day }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        dayPendingDeletion = day
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            symbolName: "calendar",
            title: "Aucune journée de tournage",
            message: "Posez vos dates de tournage, leurs horaires de convocation et leurs notes logistiques.",
            tint: .orange
        ) {
            Button {
                addDay()
            } label: {
                Label("Ajouter une journée", systemImage: "plus")
                    .touchTarget()
                    .padding(.horizontal, Spacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { dayPendingDeletion != nil },
            set: { if !$0 { dayPendingDeletion = nil } }
        )
    }

    private func addDay() {
        let suggestedDate = days.last.map {
            Calendar.current.date(byAdding: .day, value: 1, to: $0.date) ?? $0.date
        } ?? .now
        dayBeingEdited = ScheduleService.createDay(in: project, date: suggestedDate, in: modelContext)
    }
}

/// One shooting day row: date block, title, hours.
struct ShootDayRow: View {
    let day: ShootDay

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(spacing: 0) {
                Text(day.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(day.isToday ? Color.orange : Color.secondary)
                Text(day.date.formatted(.dateTime.day()))
                    .font(.title3.monospacedDigit().weight(.semibold))
            }
            .frame(width: 48, height: 48)
            .background(
                (day.isToday ? Color.orange : Color.primary).opacity(day.isToday ? 0.14 : 0.05),
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
            .opacity(day.isPast ? 0.55 : 1)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(day.displayTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: Spacing.xs) {
                    Text(day.date.formatted(.dateTime.weekday(.wide)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if day.callTime != nil || day.estimatedWrapTime != nil {
                        Text("· \(AppFormat.optionalTime(day.callTime)) → \(AppFormat.optionalTime(day.estimatedWrapTime))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: Spacing.sm)

            if !day.scenes.isEmpty {
                Chip(text: "\(day.scenes.count) sc.", style: .neutral)
            }
            if day.isToday {
                Chip(text: "Aujourd'hui", tint: .orange)
            }
        }
        .touchTarget()
    }
}

#Preview {
    NavigationStack {
        ScheduleView(project: SampleData.previewProject())
    }
    .modelContainer(SampleData.previewContainer)
}
