import SwiftUI

/// One line of the people library.
struct PersonRow: View {
    let person: Person
    var roleOverride: CrewRole?
    var trailingText: String?

    private var role: CrewRole { roleOverride ?? person.role }

    var body: some View {
        HStack(spacing: Spacing.md) {
            InitialsAvatar(initials: person.initials, tint: role.department.tint)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(person.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: Spacing.xs) {
                    Text(role.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !person.email.isBlank {
                        Text("· \(person.email)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: Spacing.sm)

            if let trailingText {
                Text(trailingText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if let rate = person.defaultRate {
                Text("\(AppFormat.currency(rate))/j")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .touchTarget()
    }
}

#Preview {
    List {
        PersonRow(person: Person(firstName: "Camille", lastName: "Roux", email: "camille@example.com", defaultRate: 350, role: .directorOfPhotography))
        PersonRow(person: Person(nickname: "NAYRA", role: .artist))
    }
}
