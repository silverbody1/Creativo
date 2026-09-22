import SwiftUI
import SwiftData

/// One editable line of the screenplay.
///
/// The leading gutter carries the element's type: discreet when the line is at
/// rest, tappable at any time. That is what makes the format reachable on iPad
/// without a keyboard, while ⌘1…⌘6 keep it instant on a Mac.
struct ScreenplayElementRow: View {
    @Bindable var element: ScreenplayElement
    var previousType: ScreenplayElementType?
    var isCompact: Bool
    @FocusState.Binding var focusedElementID: UUID?

    let onChangeType: (ScreenplayElementType) -> Void
    let onInsertAfter: () -> Void
    let onDelete: () -> Void
    let onMove: (Int) -> Void
    let onEndEditing: () -> Void

    private var isFocused: Bool { focusedElementID == element.id }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            typeGutter
            field
                .padding(ScreenplayStyle.insets(for: element.type, compact: isCompact))
        }
        .padding(.top, ScreenplayStyle.topSpacing(for: element.type, previous: previousType))
        .contentShape(Rectangle())
        .onTapGesture { focusedElementID = element.id }
        .contextMenu { menu }
        .id(element.id)
    }

    // MARK: Field

    @ViewBuilder
    private var field: some View {
        if element.type == .parenthetical {
            HStack(alignment: .top, spacing: 0) {
                Text("(")
                textField
                Text(")")
            }
            .font(ScreenplayStyle.font(for: element.type))
            .foregroundStyle(.secondary)
        } else if element.type == .note {
            textField
                .padding(Spacing.sm)
                .background(
                    Color.yellow.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                )
        } else {
            textField
        }
    }

    private var textField: some View {
        TextField(
            ScreenplayStyle.placeholder(for: element.type),
            text: $element.text,
            axis: .vertical
        )
        .textFieldStyle(.plain)
        .font(ScreenplayStyle.font(for: element.type))
        .multilineTextAlignment(ScreenplayStyle.textAlignment(for: element.type))
        .foregroundStyle(element.type == .note ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(Color.primary))
        .frame(maxWidth: .infinity, alignment: alignment)
        .focused($focusedElementID, equals: element.id)
        .onChange(of: isFocused) { _, focused in
            if !focused { normalise() }
        }
    }

    private var alignment: Alignment {
        element.type == .transition ? .trailing : .leading
    }

    // MARK: Gutter

    private var typeGutter: some View {
        Menu {
            typeButtons
        } label: {
            Image(systemName: element.type.symbolName)
                .font(.caption)
                .foregroundStyle(ScreenplayStyle.tint(for: element.type))
                .frame(width: 26, height: 26)
                .background(
                    ScreenplayStyle.tint(for: element.type).opacity(isFocused ? 0.16 : 0.06),
                    in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                )
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .opacity(isFocused ? 1 : 0.45)
        .accessibilityLabel("Type de l'élément, \(element.type.displayName)")
    }

    @ViewBuilder
    private var typeButtons: some View {
        ForEach(ScreenplayElementType.allCases) { type in
            Button {
                onChangeType(type)
            } label: {
                Label(type.displayName, systemImage: type.symbolName)
            }
        }
    }

    @ViewBuilder
    private var menu: some View {
        Menu("Type") { typeButtons }
        Button("Nouvel élément en dessous", action: onInsertAfter)
        Divider()
        Button("Monter") { onMove(-1) }
        Button("Descendre") { onMove(1) }
        Divider()
        Button("Supprimer", role: .destructive, action: onDelete)
    }

    // MARK: Normalisation

    /// Applies the format's casing when the line loses focus, rather than
    /// while typing, so the caret never jumps under the writer's fingers.
    private func normalise() {
        switch element.type {
        case .character, .transition:
            let upper = element.text.uppercased()
            if element.text != upper { element.text = upper }
        case .parenthetical:
            let stripped = element.text.trimmingCharacters(in: CharacterSet(charactersIn: "() "))
            if element.text != stripped { element.text = stripped }
        case .action, .dialogue, .note:
            break
        }
        onEndEditing()
    }
}
