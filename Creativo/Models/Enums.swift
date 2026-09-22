import Foundation

// MARK: - Project

/// The kind of production a project describes.
///
/// Each case carries its own presentation metadata so that pickers, cards and
/// badges never have to switch on the enum themselves.
enum ProjectType: String, Codable, CaseIterable, Identifiable, Sendable {
    case musicVideo
    case youtube
    case film
    case commercial
    case social
    case blank

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .musicVideo: return "Clip musical"
        case .youtube: return "Vidéo YouTube"
        case .film: return "Film / Court-métrage"
        case .commercial: return "Publicité"
        case .social: return "Contenu social"
        case .blank: return "Projet vierge"
        }
    }

    var symbolName: String {
        switch self {
        case .musicVideo: return "music.note.tv"
        case .youtube: return "play.rectangle.on.rectangle"
        case .film: return "film.stack"
        case .commercial: return "megaphone"
        case .social: return "iphone.gen3"
        case .blank: return "square.dashed"
        }
    }

    var shortDescription: String {
        switch self {
        case .musicVideo: return "Clip, performance, narratif musical."
        case .youtube: return "Format éditorial, vlog, chaîne."
        case .film: return "Fiction, court ou long métrage."
        case .commercial: return "Film de marque, spot, corporate."
        case .social: return "Vertical, TikTok, Reels, Shorts."
        case .blank: return "Partez d'une page blanche."
        }
    }
}

/// Where a project stands in the production pipeline.
enum ProjectStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case idea
    case writing
    case preProduction
    case production
    case postProduction
    case completed
    case archived

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .idea: return "Idée"
        case .writing: return "Écriture"
        case .preProduction: return "Préproduction"
        case .production: return "Tournage"
        case .postProduction: return "Postproduction"
        case .completed: return "Terminé"
        case .archived: return "Archivé"
        }
    }

    var symbolName: String {
        switch self {
        case .idea: return "lightbulb"
        case .writing: return "pencil.and.scribble"
        case .preProduction: return "list.bullet.clipboard"
        case .production: return "camera"
        case .postProduction: return "wand.and.stars"
        case .completed: return "checkmark.seal"
        case .archived: return "archivebox"
        }
    }
}

// MARK: - Scene

/// Interior / exterior classification of a scene.
enum SceneEnvironment: String, Codable, CaseIterable, Identifiable, Sendable {
    case interior
    case exterior
    case interiorExterior

    var id: String { rawValue }

    /// Screenplay-style abbreviation shown in dense lists.
    var abbreviation: String {
        switch self {
        case .interior: return "INT."
        case .exterior: return "EXT."
        case .interiorExterior: return "INT./EXT."
        }
    }

    var displayName: String {
        switch self {
        case .interior: return "Intérieur"
        case .exterior: return "Extérieur"
        case .interiorExterior: return "Intérieur / Extérieur"
        }
    }
}

/// Moment of the day a scene is meant to be shot in.
enum TimeOfDay: String, Codable, CaseIterable, Identifiable, Sendable {
    case dawn
    case morning
    case day
    case afternoon
    case goldenHour
    case dusk
    case night
    case continuous
    case unspecified

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dawn: return "Aube"
        case .morning: return "Matin"
        case .day: return "Jour"
        case .afternoon: return "Après-midi"
        case .goldenHour: return "Golden hour"
        case .dusk: return "Crépuscule"
        case .night: return "Nuit"
        case .continuous: return "Continu"
        case .unspecified: return "Non précisé"
        }
    }

    var symbolName: String {
        switch self {
        case .dawn: return "sunrise"
        case .morning: return "sun.haze"
        case .day: return "sun.max"
        case .afternoon: return "sun.min"
        case .goldenHour: return "sun.horizon"
        case .dusk: return "sunset"
        case .night: return "moon.stars"
        case .continuous: return "arrow.triangle.2.circlepath"
        case .unspecified: return "questionmark.circle"
        }
    }
}

/// Writing progress of a scene.
enum SceneStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case draft
    case written
    case revised
    case locked
    case shot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .draft: return "Brouillon"
        case .written: return "Écrite"
        case .revised: return "Révisée"
        case .locked: return "Verrouillée"
        case .shot: return "Tournée"
        }
    }

    var symbolName: String {
        switch self {
        case .draft: return "circle.dashed"
        case .written: return "circle.lefthalf.filled"
        case .revised: return "circle.bottomhalf.filled"
        case .locked: return "lock"
        case .shot: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Shot

/// Framing of a shot, from the widest to the tightest.
enum ShotSize: String, Codable, CaseIterable, Identifiable, Sendable {
    case extremeWide
    case wide
    case full
    case medium
    case mediumCloseUp
    case closeUp
    case extremeCloseUp
    case overTheShoulder
    case twoShot
    case insert

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .extremeWide: return "Très large"
        case .wide: return "Large"
        case .full: return "Plan pied"
        case .medium: return "Plan moyen"
        case .mediumCloseUp: return "Plan rapproché"
        case .closeUp: return "Gros plan"
        case .extremeCloseUp: return "Très gros plan"
        case .overTheShoulder: return "Amorce"
        case .twoShot: return "Plan à deux"
        case .insert: return "Insert"
        }
    }

    /// Compact label used inside dense shot rows.
    var abbreviation: String {
        switch self {
        case .extremeWide: return "TL"
        case .wide: return "PL"
        case .full: return "PP"
        case .medium: return "PM"
        case .mediumCloseUp: return "PR"
        case .closeUp: return "GP"
        case .extremeCloseUp: return "TGP"
        case .overTheShoulder: return "AMO"
        case .twoShot: return "2SH"
        case .insert: return "INS"
        }
    }
}

/// Camera movement applied to a shot.
enum CameraMovement: String, Codable, CaseIterable, Identifiable, Sendable {
    case fixed
    case pan
    case tilt
    case dolly
    case tracking
    case crane
    case handheld
    case steadicam
    case gimbal
    case drone
    case zoom
    case snorricam

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fixed: return "Fixe"
        case .pan: return "Panoramique"
        case .tilt: return "Panoramique vertical"
        case .dolly: return "Travelling avant/arrière"
        case .tracking: return "Travelling latéral"
        case .crane: return "Grue"
        case .handheld: return "Caméra épaule"
        case .steadicam: return "Steadicam"
        case .gimbal: return "Gimbal"
        case .drone: return "Drone"
        case .zoom: return "Zoom"
        case .snorricam: return "Snorricam"
        }
    }
}

/// Production progress of a shot.
enum ShotStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case planned
    case ready
    case shot
    case cancelled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .planned: return "Prévu"
        case .ready: return "Prêt"
        case .shot: return "Tourné"
        case .cancelled: return "Annulé"
        }
    }

    var symbolName: String {
        switch self {
        case .planned: return "circle.dashed"
        case .ready: return "circle.circle"
        case .shot: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    /// Shots that count towards the "shot / total" progress ratio.
    var countsAsCompleted: Bool { self == .shot }

    /// Cancelled shots are excluded from progress denominators.
    var countsInProgress: Bool { self != .cancelled }
}

// MARK: - People

/// Role a person holds on a production.
enum CrewRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case director
    case assistantDirector
    case producer
    case productionManager
    case directorOfPhotography
    case cameraOperator
    case focusPuller
    case gaffer
    case grip
    case soundEngineer
    case artDirector
    case setDesigner
    case stylist
    case makeupArtist
    case hairStylist
    case editor
    case colorist
    case vfxArtist
    case composer
    case artist
    case actor
    case dancer
    case extraTalent
    case driver
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .director: return "Réalisation"
        case .assistantDirector: return "1er assistant réalisateur"
        case .producer: return "Production"
        case .productionManager: return "Direction de production"
        case .directorOfPhotography: return "Direction photo"
        case .cameraOperator: return "Cadre"
        case .focusPuller: return "Assistant caméra"
        case .gaffer: return "Chef électricien"
        case .grip: return "Machiniste"
        case .soundEngineer: return "Son"
        case .artDirector: return "Direction artistique"
        case .setDesigner: return "Décors"
        case .stylist: return "Stylisme"
        case .makeupArtist: return "Maquillage"
        case .hairStylist: return "Coiffure"
        case .editor: return "Montage"
        case .colorist: return "Étalonnage"
        case .vfxArtist: return "VFX"
        case .composer: return "Musique"
        case .artist: return "Artiste"
        case .actor: return "Comédien"
        case .dancer: return "Danseur"
        case .extraTalent: return "Figuration"
        case .driver: return "Transport"
        case .other: return "Autre"
        }
    }

    /// Coarse grouping used to sort and section crew lists.
    var department: CrewDepartment {
        switch self {
        case .director, .assistantDirector: return .direction
        case .producer, .productionManager: return .production
        case .directorOfPhotography, .cameraOperator, .focusPuller: return .camera
        case .gaffer, .grip: return .lighting
        case .soundEngineer: return .sound
        case .artDirector, .setDesigner, .stylist, .makeupArtist, .hairStylist: return .art
        case .editor, .colorist, .vfxArtist, .composer: return .post
        case .artist, .actor, .dancer, .extraTalent: return .cast
        case .driver, .other: return .other
        }
    }
}

/// Department a crew role belongs to.
enum CrewDepartment: String, Codable, CaseIterable, Identifiable, Sendable {
    case direction
    case production
    case camera
    case lighting
    case sound
    case art
    case post
    case cast
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .direction: return "Réalisation"
        case .production: return "Production"
        case .camera: return "Image"
        case .lighting: return "Lumière & machinerie"
        case .sound: return "Son"
        case .art: return "Artistique"
        case .post: return "Postproduction"
        case .cast: return "Casting"
        case .other: return "Autre"
        }
    }

    var symbolName: String {
        switch self {
        case .direction: return "megaphone"
        case .production: return "briefcase"
        case .camera: return "camera"
        case .lighting: return "lightbulb.max"
        case .sound: return "waveform"
        case .art: return "paintpalette"
        case .post: return "slider.horizontal.below.rectangle"
        case .cast: return "person.2"
        case .other: return "ellipsis.circle"
        }
    }

    var sortIndex: Int {
        CrewDepartment.allCases.firstIndex(of: self) ?? 0
    }
}

// MARK: - Equipment

/// Category of a piece of equipment in the global library.
enum EquipmentCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case camera
    case lens
    case lighting
    case grip
    case sound
    case power
    case monitoring
    case drone
    case storage
    case transport
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .camera: return "Caméra"
        case .lens: return "Optique"
        case .lighting: return "Lumière"
        case .grip: return "Machinerie"
        case .sound: return "Son"
        case .power: return "Énergie"
        case .monitoring: return "Retour image"
        case .drone: return "Drone"
        case .storage: return "Stockage"
        case .transport: return "Transport"
        case .other: return "Autre"
        }
    }

    var symbolName: String {
        switch self {
        case .camera: return "camera"
        case .lens: return "camera.aperture"
        case .lighting: return "lightbulb.max"
        case .grip: return "wrench.and.screwdriver"
        case .sound: return "waveform"
        case .power: return "bolt.batteryblock"
        case .monitoring: return "display"
        case .drone: return "airplane"
        case .storage: return "externaldrive"
        case .transport: return "box.truck"
        case .other: return "shippingbox"
        }
    }

    var sortIndex: Int {
        EquipmentCategory.allCases.firstIndex(of: self) ?? 0
    }
}

// MARK: - Budget

/// Budget category, mirroring a standard production cost breakdown.
enum BudgetCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case crew
    case cast
    case locations
    case equipment
    case transport
    case catering
    case artDepartment
    case wardrobe
    case postProduction
    case music
    case insurance
    case permits
    case miscellaneous

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .crew: return "Équipe technique"
        case .cast: return "Casting"
        case .locations: return "Lieux"
        case .equipment: return "Matériel"
        case .transport: return "Transport"
        case .catering: return "Catering"
        case .artDepartment: return "Décors & accessoires"
        case .wardrobe: return "Costumes"
        case .postProduction: return "Postproduction"
        case .music: return "Musique"
        case .insurance: return "Assurances"
        case .permits: return "Autorisations"
        case .miscellaneous: return "Divers"
        }
    }

    var symbolName: String {
        switch self {
        case .crew: return "person.3"
        case .cast: return "theatermasks"
        case .locations: return "mappin.and.ellipse"
        case .equipment: return "camera"
        case .transport: return "box.truck"
        case .catering: return "fork.knife"
        case .artDepartment: return "paintpalette"
        case .wardrobe: return "tshirt"
        case .postProduction: return "slider.horizontal.below.rectangle"
        case .music: return "music.note"
        case .insurance: return "shield"
        case .permits: return "doc.text"
        case .miscellaneous: return "ellipsis.circle"
        }
    }
}

/// Commitment level of a budget line.
enum BudgetLineStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case estimated
    case quoted
    case committed
    case paid
    case cancelled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .estimated: return "Estimé"
        case .quoted: return "Devis reçu"
        case .committed: return "Engagé"
        case .paid: return "Payé"
        case .cancelled: return "Annulé"
        }
    }

    var symbolName: String {
        switch self {
        case .estimated: return "circle.dashed"
        case .quoted: return "doc.text"
        case .committed: return "signature"
        case .paid: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    /// Cancelled lines are excluded from every budget total.
    var countsInTotals: Bool { self != .cancelled }
}

// MARK: - References

/// Media kind of a reference attached to a project.
enum ReferenceType: String, Codable, CaseIterable, Identifiable, Sendable {
    case image
    case video
    case audio
    case link
    case document
    case note

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .image: return "Image"
        case .video: return "Vidéo"
        case .audio: return "Audio"
        case .link: return "Lien"
        case .document: return "Document"
        case .note: return "Note"
        }
    }

    var symbolName: String {
        switch self {
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "waveform"
        case .link: return "link"
        case .document: return "doc"
        case .note: return "note.text"
        }
    }
}
