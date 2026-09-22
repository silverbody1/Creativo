import Foundation
import SwiftData

/// A shooting location in the **global library**.
///
/// Named `ProductionLocation` rather than `Location` to stay clear of
/// `CoreLocation` and of SwiftUI's own naming. Coordinates are plain optional
/// doubles so that nothing here depends on MapKit being linked.
@Model
final class ProductionLocation {
    var id: UUID = UUID()
    var name: String = ""
    var address: String = ""
    var latitude: Double?
    var longitude: Double?
    var contactName: String = ""
    var contactEmail: String = ""
    var contactPhone: String = ""
    var pricePerDay: Decimal?
    var notes: String = ""
    var parkingNotes: String = ""
    var powerAvailable: Bool = false
    var toiletsAvailable: Bool = false
    var indoorAvailable: Bool = false
    var outdoorAvailable: Bool = false
    var nightShootingAllowed: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// Many-to-many with projects; the inverse lives on `Project.locations`.
    var projects: [Project] = []

    @Relationship(deleteRule: .nullify, inverse: \StoryScene.location)
    var scenes: [StoryScene] = []

    init(
        name: String = "",
        address: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        contactName: String = "",
        contactEmail: String = "",
        contactPhone: String = "",
        pricePerDay: Decimal? = nil,
        notes: String = "",
        parkingNotes: String = "",
        powerAvailable: Bool = false,
        toiletsAvailable: Bool = false,
        indoorAvailable: Bool = false,
        outdoorAvailable: Bool = false,
        nightShootingAllowed: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.contactName = contactName
        self.contactEmail = contactEmail
        self.contactPhone = contactPhone
        self.pricePerDay = pricePerDay
        self.notes = notes
        self.parkingNotes = parkingNotes
        self.powerAvailable = powerAvailable
        self.toiletsAvailable = toiletsAvailable
        self.indoorAvailable = indoorAvailable
        self.outdoorAvailable = outdoorAvailable
        self.nightShootingAllowed = nightShootingAllowed
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension ProductionLocation {
    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Lieu sans nom"
            : name
    }

    /// Amenity chips shown on the location row.
    var amenities: [LocationAmenity] {
        var result: [LocationAmenity] = []
        if powerAvailable { result.append(.power) }
        if toiletsAvailable { result.append(.toilets) }
        if indoorAvailable { result.append(.indoor) }
        if outdoorAvailable { result.append(.outdoor) }
        if nightShootingAllowed { result.append(.night) }
        return result
    }

    var searchHaystack: String {
        [name, address, contactName, contactEmail, contactPhone, notes, parkingNotes]
            .joined(separator: " ")
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
    }
}

/// Presentation-only description of a location facility.
enum LocationAmenity: String, Identifiable, CaseIterable, Sendable {
    case power
    case toilets
    case indoor
    case outdoor
    case night

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .power: return "Électricité"
        case .toilets: return "Sanitaires"
        case .indoor: return "Intérieur"
        case .outdoor: return "Extérieur"
        case .night: return "Tournage de nuit"
        }
    }

    var symbolName: String {
        switch self {
        case .power: return "bolt"
        case .toilets: return "toilet"
        case .indoor: return "house"
        case .outdoor: return "tree"
        case .night: return "moon.stars"
        }
    }
}
