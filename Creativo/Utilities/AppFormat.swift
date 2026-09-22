import Foundation

/// Every user-visible number, amount and date is formatted here.
///
/// Centralised so the app stays locale-correct: currency symbol, decimal
/// separator and date order all follow the user's region instead of being
/// hard-coded to French conventions.
enum AppFormat {
    // MARK: Money

    /// Currency of the user's region, falling back to euro.
    static var currencyCode: String {
        Locale.current.currency?.identifier ?? "EUR"
    }

    /// Rounded amount, e.g. `8 400 €`. Used in headlines and stat cards.
    static func currency(_ value: Decimal, fractionDigits: Int = 0) -> String {
        value.formatted(.currency(code: currencyCode).precision(.fractionLength(fractionDigits)))
    }

    /// Amount with cents, e.g. `8 400,00 €`. Used in budget rows.
    static func currencyDetailed(_ value: Decimal) -> String {
        currency(value, fractionDigits: 2)
    }

    /// Amount that may be unknown.
    static func optionalCurrency(_ value: Decimal?, placeholder: String = "—") -> String {
        guard let value else { return placeholder }
        return currency(value)
    }

    /// Signed amount, e.g. `+ 240 €` / `− 240 €`.
    static func signedCurrency(_ value: Decimal) -> String {
        let magnitude = currency(abs(value))
        if value > 0 { return "+ \(magnitude)" }
        if value < 0 { return "− \(magnitude)" }
        return magnitude
    }

    /// Percentage from a 0...1 ratio, e.g. `84 %`.
    static func percentage(_ ratio: Double) -> String {
        ratio.formatted(.percent.precision(.fractionLength(0)))
    }

    // MARK: Durations

    /// `1 min 30 s`, or `—` when unknown.
    static func duration(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "—" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) h") }
        if minutes > 0 { parts.append("\(minutes) min") }
        if secs > 0 && hours == 0 { parts.append("\(secs) s") }
        return parts.isEmpty ? "—" : parts.joined(separator: " ")
    }

    /// `01:30`, the form used in dense scene rows.
    static func timecode(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded()), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// `01:17.420`, the precision a timeline needs. Frames would be false
    /// precision here: there is no picture yet, only a track.
    static func preciseTimecode(_ seconds: TimeInterval) -> String {
        let safe = max(seconds, 0)
        let total = Int(safe)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        let milliseconds = Int(((safe - Double(total)) * 1000).rounded())
        let clampedMilliseconds = min(milliseconds, 999)
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%03d", hours, minutes, secs, clampedMilliseconds)
        }
        return String(format: "%02d:%02d.%03d", minutes, secs, clampedMilliseconds)
    }

    /// `01:17.420 / 03:04.870`
    static func transportTimecode(_ current: TimeInterval, of total: TimeInterval) -> String {
        "\(preciseTimecode(current)) / \(preciseTimecode(total))"
    }

    // MARK: Dates

    /// `il y a 2 jours`, for "last modified" labels.
    static func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }

    /// `12/03/2026`
    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.twoDigits).year())
    }

    /// `jeudi 12 mars`
    static func longDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    /// `07:30`
    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    static func optionalTime(_ date: Date?, placeholder: String = "—") -> String {
        guard let date else { return placeholder }
        return time(date)
    }

    // MARK: Misc

    /// `23,976 fps`, trailing zeros removed.
    static func frameRate(_ value: Double) -> String {
        let rounded = (value * 1000).rounded() / 1000
        let text = rounded == rounded.rounded()
            ? String(Int(rounded))
            : rounded.formatted(.number.precision(.fractionLength(0...3)))
        return "\(text) fps"
    }

    /// `3 scènes` / `1 scène` / `Aucune scène`
    static func count(_ value: Int, singular: String, plural: String, zero: String) -> String {
        switch value {
        case 0: return zero
        case 1: return "1 \(singular)"
        default: return "\(value) \(plural)"
        }
    }
}
