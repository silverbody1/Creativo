import SwiftUI

extension Binding {
    /// Presents an optional value as a non-optional one for form controls.
    init(_ source: Binding<Value?>, replacingNilWith nilValue: Value) {
        self.init(
            get: { source.wrappedValue ?? nilValue },
            set: { newValue in source.wrappedValue = newValue }
        )
    }
}

extension Binding where Value == Decimal {
    /// Maps an optional amount to a text field: empty and zero both mean "not set".
    static func optionalAmount(_ source: Binding<Decimal?>) -> Binding<Decimal> {
        Binding<Decimal>(
            get: { source.wrappedValue ?? 0 },
            set: { newValue in source.wrappedValue = newValue == 0 ? nil : newValue }
        )
    }
}

extension Binding where Value == Date {
    /// Maps an optional date to a date picker, using `fallback` while unset.
    static func optionalDate(_ source: Binding<Date?>, fallback: Date) -> Binding<Date> {
        Binding<Date>(
            get: { source.wrappedValue ?? fallback },
            set: { newValue in source.wrappedValue = newValue }
        )
    }
}

extension String {
    /// Whitespace-only strings count as empty everywhere in the app.
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Case- and diacritic-insensitive containment, for the search fields.
    func matches(_ query: String) -> Bool {
        let needle = query.trimmed
        guard !needle.isEmpty else { return true }
        return range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

extension Binding where Value == String {
    /// Text binding over an optional `Double`: an empty or invalid field means
    /// "not set". Used for coordinates, where zero is a real value and cannot
    /// stand in for nil.
    static func optionalDouble(_ source: Binding<Double?>) -> Binding<String> {
        Binding<String>(
            get: {
                guard let value = source.wrappedValue else { return "" }
                return value.formatted(.number.precision(.fractionLength(0...6)).grouping(.never))
            },
            set: { newValue in
                let normalised = newValue
                    .replacingOccurrences(of: ",", with: ".")
                    .trimmingCharacters(in: .whitespaces)
                source.wrappedValue = normalised.isEmpty ? nil : Double(normalised)
            }
        )
    }
}

extension Binding where Value == TimeInterval {
    /// Presents an optional timecode as a duration field, treating "not set"
    /// as zero while the field is on screen. The caller decides when the value
    /// goes back to nil, because zero is a legitimate timecode.
    static func optionalDuration(_ source: Binding<TimeInterval?>) -> Binding<TimeInterval> {
        Binding<TimeInterval>(
            get: { source.wrappedValue ?? 0 },
            set: { newValue in source.wrappedValue = newValue }
        )
    }
}
