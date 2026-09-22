import Foundation
import SwiftData

/// Demonstration content for SwiftUI previews, tests and the development mode.
///
/// It only ever writes into a container the caller owns. The previews use an
/// in-memory store, so nothing here can reach the user's real data unless they
/// explicitly ask for it from the development section of the settings.
enum SampleData {
    // MARK: Containers

    @MainActor static let previewContainer: ModelContainer = {
        let container = makeContainer()
        populate(container.mainContext)
        return container
    }()

    @MainActor static let emptyPreviewContainer: ModelContainer = makeContainer()

    static func makeContainer() -> ModelContainer {
        do {
            return try PersistenceController.makeInMemoryContainer()
        } catch {
            fatalError("Conteneur de prévisualisation impossible à créer: \(error)")
        }
    }

    // MARK: Preview accessors

    @MainActor static func previewProject() -> Project {
        let context = previewContainer.mainContext
        let existing = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        if let partenaire = existing.first(where: { $0.name == "PARTENAIRE" }) { return partenaire }
        if let first = existing.first { return first }
        return populate(context)
    }

    @MainActor static func previewScene() -> StoryScene {
        previewProject().sortedScenes.first ?? StoryScene(sceneNumber: "1", title: "Intro")
    }

    // MARK: Population

    /// Inserts a full production into `context` and returns its main project.
    @discardableResult
    static func populate(_ context: ModelContext) -> Project {
        let people = insertPeople(into: context)
        let locations = insertLocations(into: context)
        let equipment = insertEquipment(into: context)

        let project = Project(
            name: "PARTENAIRE",
            type: .musicVideo,
            status: .preProduction,
            synopsis: """
            Un clip nocturne en deux territoires : un studio noir où l'artiste est seul face caméra, \
            et un rooftop au petit matin où la ville se réveille. Le montage alterne les deux jusqu'à \
            les faire se rejoindre sur le dernier refrain.
            """,
            notes: "Tournage sur deux jours. Prévoir une autorisation pour le rooftop.",
            targetBudget: 12_000,
            isFavorite: true
        )
        context.insert(project)

        project.locations = [locations.studio, locations.rooftop]

        insertScenes(into: project, locations: locations, context: context)
        insertCrew(into: project, people: people, context: context)
        insertGear(into: project, equipment: equipment, context: context)
        insertBudget(into: project, context: context)
        insertShootDays(into: project, context: context)

        insertSecondProject(into: context, locations: locations)

        PersistenceActions.save(context)
        return project
    }

    // MARK: Library

    private struct SamplePeople {
        let director: Person
        let dop: Person
        let artist: Person
        let gaffer: Person
        let stylist: Person
    }

    private static func insertPeople(into context: ModelContext) -> SamplePeople {
        let director = Person(
            firstName: "Léa",
            lastName: "Moreau",
            email: "lea.moreau@example.com",
            phone: "+33 6 12 34 56 78",
            notes: "Préfère les repérages la veille.",
            defaultRate: 600,
            role: .director
        )
        let dop = Person(
            firstName: "Camille",
            lastName: "Roux",
            email: "camille.roux@example.com",
            defaultRate: 450,
            role: .directorOfPhotography
        )
        let artist = Person(
            firstName: "Naïma",
            lastName: "Belkacem",
            nickname: "NAYRA",
            email: "contact@nayra.example",
            role: .artist
        )
        let gaffer = Person(
            firstName: "Yanis",
            lastName: "Bouchard",
            defaultRate: 280,
            role: .gaffer
        )
        let stylist = Person(
            firstName: "Sofia",
            lastName: "Lentz",
            notes: "Travaille avec un stock de costumes personnel.",
            defaultRate: 320,
            role: .stylist
        )
        for person in [director, dop, artist, gaffer, stylist] {
            context.insert(person)
        }
        return SamplePeople(director: director, dop: dop, artist: artist, gaffer: gaffer, stylist: stylist)
    }

    private struct SampleLocations {
        let studio: ProductionLocation
        let rooftop: ProductionLocation
        let parking: ProductionLocation
    }

    private static func insertLocations(into context: ModelContext) -> SampleLocations {
        let studio = ProductionLocation(
            name: "Studio Est",
            address: "12 rue des Lilas, 93100 Montreuil",
            latitude: 48.8630,
            longitude: 2.4410,
            contactName: "Marc Vidal",
            contactEmail: "resa@studioest.example",
            contactPhone: "+33 1 48 00 00 00",
            pricePerDay: 700,
            notes: "Cyclo noir, hauteur sous plafond 5 m.",
            parkingNotes: "Deux places devant le portail, badge à récupérer à l'accueil.",
            powerAvailable: true,
            toiletsAvailable: true,
            indoorAvailable: true,
            nightShootingAllowed: true
        )
        let rooftop = ProductionLocation(
            name: "Rooftop Belleville",
            address: "Rue Piat, 75020 Paris",
            latitude: 48.8720,
            longitude: 2.3830,
            contactName: "Syndic Piat",
            pricePerDay: 0,
            notes: "Golden hour vers 7 h 15 en mars. Vue plein ouest.",
            parkingNotes: "Stationnement difficile, prévoir une navette.",
            outdoorAvailable: true
        )
        let parking = ProductionLocation(
            name: "Parking souterrain Nation",
            address: "Place de la Nation, 75012 Paris",
            contactName: "Gestion Indigo",
            pricePerDay: 250,
            notes: "Niveau -2 le plus photogénique, béton brut.",
            powerAvailable: false,
            indoorAvailable: true,
            nightShootingAllowed: true
        )
        for location in [studio, rooftop, parking] {
            context.insert(location)
        }
        return SampleLocations(studio: studio, rooftop: rooftop, parking: parking)
    }

    private struct SampleEquipment {
        let camera: EquipmentItem
        let lens: EquipmentItem
        let light: EquipmentItem
        let gimbal: EquipmentItem
        let recorder: EquipmentItem
    }

    private static func insertEquipment(into context: ModelContext) -> SampleEquipment {
        let camera = EquipmentItem(
            name: "FX3",
            category: .camera,
            brand: "Sony",
            model: "ILME-FX3",
            owned: true,
            quantity: 1,
            defaultDailyRate: 150,
            notes: "Deux batteries NP-FZ100 et un chargeur double."
        )
        let lens = EquipmentItem(
            name: "35 mm T1.5",
            category: .lens,
            brand: "Sigma",
            model: "Cine FF",
            owned: false,
            quantity: 1,
            defaultDailyRate: 90
        )
        let light = EquipmentItem(
            name: "600d Pro",
            category: .lighting,
            brand: "Aputure",
            owned: false,
            quantity: 2,
            defaultDailyRate: 70
        )
        let gimbal = EquipmentItem(
            name: "RS 4 Pro",
            category: .grip,
            brand: "DJI",
            owned: true,
            quantity: 1,
            defaultDailyRate: 60
        )
        let recorder = EquipmentItem(
            name: "H6",
            category: .sound,
            brand: "Zoom",
            owned: true,
            quantity: 1,
            defaultDailyRate: 25
        )
        for item in [camera, lens, light, gimbal, recorder] {
            context.insert(item)
        }
        return SampleEquipment(camera: camera, lens: lens, light: light, gimbal: gimbal, recorder: recorder)
    }

    // MARK: Project content

    private static func insertScenes(
        into project: Project,
        locations: SampleLocations,
        context: ModelContext
    ) {
        let definitions: [(String, SceneEnvironment, TimeOfDay, TimeInterval, SceneStatus, ProductionLocation, String)] = [
            ("Intro", .interior, .night, 22, .locked, locations.studio,
             "Noir. Un souffle. Le visage apparaît par la droite, une seule source."),
            ("Couplet 1", .interior, .night, 48, .revised, locations.studio,
             "Face caméra, très peu de mouvement. On laisse le texte porter."),
            ("Refrain 1", .exterior, .goldenHour, 38, .written, locations.rooftop,
             "Le rooftop s'ouvre, la ville derrière. Gimbal en orbite lente."),
            ("Couplet 2", .interior, .night, 46, .draft, locations.studio,
             "Retour studio, cadre plus serré qu'au premier couplet."),
            ("Refrain 2", .exterior, .dawn, 52, .draft, locations.rooftop,
             "Même axe que le premier refrain mais la lumière a basculé.")
        ]

        for (index, definition) in definitions.enumerated() {
            let scene = StoryScene(
                sceneNumber: "\(index + 1)",
                title: definition.0,
                synopsis: definition.6,
                environment: definition.1,
                timeOfDay: definition.2,
                estimatedDuration: definition.3,
                status: definition.4,
                orderIndex: index
            )
            scene.project = project
            scene.location = definition.5
            context.insert(scene)
            insertShots(into: scene, context: context)
        }
    }

    private static func insertShots(into scene: StoryScene, context: ModelContext) {
        let definitions: [(String, ShotSize, CameraMovement, String, ShotStatus)]

        switch scene.title {
        case "Intro":
            definitions = [
                ("Apparition", .extremeCloseUp, .fixed, "85 mm", .shot),
                ("Souffle", .closeUp, .fixed, "85 mm", .shot)
            ]
        case "Couplet 1":
            definitions = [
                ("Face caméra", .mediumCloseUp, .fixed, "50 mm", .shot),
                ("Profil", .medium, .pan, "35 mm", .ready),
                ("Mains", .insert, .fixed, "50 mm", .planned)
            ]
        case "Refrain 1":
            definitions = [
                ("Orbite rooftop", .wide, .gimbal, "24 mm", .ready),
                ("Contre-plongée ciel", .full, .tilt, "24 mm", .planned),
                ("Regard ville", .mediumCloseUp, .handheld, "35 mm", .planned)
            ]
        case "Couplet 2":
            definitions = [
                ("Serré studio", .closeUp, .fixed, "85 mm", .planned),
                ("Amorce épaule", .overTheShoulder, .fixed, "50 mm", .planned)
            ]
        default:
            definitions = [
                ("Lever de jour", .extremeWide, .drone, "24 mm", .planned),
                ("Dernier regard", .closeUp, .fixed, "85 mm", .planned)
            ]
        }

        for (index, definition) in definitions.enumerated() {
            let shot = Shot(
                shotNumber: "\(scene.displayNumber)\(ShotService.letter(for: index))",
                title: definition.0,
                shotSize: definition.1,
                cameraMovement: definition.2,
                lens: definition.3,
                frameRate: 25,
                status: definition.4,
                orderIndex: index
            )
            shot.scene = scene
            context.insert(shot)
        }
    }

    private static func insertCrew(into project: Project, people: SamplePeople, context: ModelContext) {
        let definitions: [(Person, CrewRole?, Int)] = [
            (people.director, nil, 2),
            (people.dop, nil, 2),
            (people.artist, nil, 2),
            (people.gaffer, nil, 2),
            (people.stylist, nil, 1)
        ]
        for definition in definitions {
            let assignment = ProjectPersonAssignment(
                project: project,
                person: definition.0,
                roleOverride: definition.1,
                numberOfDays: definition.2
            )
            context.insert(assignment)
        }
    }

    private static func insertGear(into project: Project, equipment: SampleEquipment, context: ModelContext) {
        let definitions: [(EquipmentItem, Int, Int)] = [
            (equipment.camera, 1, 2),
            (equipment.lens, 1, 2),
            (equipment.light, 2, 1),
            (equipment.gimbal, 1, 1),
            (equipment.recorder, 1, 2)
        ]
        for definition in definitions {
            let assignment = ProjectEquipmentAssignment(
                project: project,
                equipment: definition.0,
                quantity: definition.1,
                numberOfDays: definition.2
            )
            context.insert(assignment)
        }
    }

    private static func insertBudget(into project: Project, context: ModelContext) {
        let definitions: [(BudgetCategory, String, Int, Decimal, Int, BudgetLineStatus, Decimal?)] = [
            (.crew, "Réalisation", 1, 600, 2, .committed, nil),
            (.crew, "Direction photo", 1, 450, 2, .committed, 900),
            (.crew, "Chef électricien", 1, 280, 2, .quoted, nil),
            (.cast, "Danseurs", 3, 150, 1, .estimated, nil),
            (.locations, "Studio Est", 1, 700, 1, .paid, 700),
            (.equipment, "Pack caméra + optique", 1, 240, 2, .committed, nil),
            (.equipment, "Lumière", 2, 70, 1, .quoted, nil),
            (.transport, "Camion 12 m³", 1, 180, 2, .estimated, nil),
            (.catering, "Repas équipe", 12, 18, 2, .estimated, nil),
            (.postProduction, "Étalonnage", 1, 900, 1, .estimated, nil),
            (.wardrobe, "Costumes", 1, 400, 1, .estimated, nil),
            (.insurance, "Assurance production", 1, 320, 1, .quoted, nil)
        ]
        for definition in definitions {
            let line = BudgetLine(
                category: definition.0,
                title: definition.1,
                quantity: definition.2,
                unitPrice: definition.3,
                numberOfDays: definition.4,
                actualAmount: definition.6,
                status: definition.5
            )
            line.project = project
            context.insert(line)
        }
    }

    private static func insertShootDays(into project: Project, context: ModelContext) {
        let calendar = Calendar.current
        let baseDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 12, to: .now) ?? .now)

        let definitions: [(Int, String, Int, Int, String)] = [
            (0, "Jour 1 — Studio", 9, 20, "Cyclo noir, deux services lumière. Prévoir le brumisateur."),
            (1, "Jour 2 — Rooftop", 5, 12, "Convocation avant l'aube pour le lever de jour. Café chaud obligatoire.")
        ]

        for definition in definitions {
            let date = calendar.date(byAdding: .day, value: definition.0, to: baseDate) ?? baseDate
            let day = ShootDay(
                date: date,
                title: definition.1,
                callTime: calendar.date(bySettingHour: definition.2, minute: 0, second: 0, of: date),
                estimatedWrapTime: calendar.date(bySettingHour: definition.3, minute: 0, second: 0, of: date),
                notes: definition.4
            )
            day.project = project
            context.insert(day)
        }
    }

    private static func insertSecondProject(into context: ModelContext, locations: SampleLocations) {
        let project = Project(
            name: "LISIÈRE",
            type: .film,
            status: .writing,
            synopsis: "Court-métrage. Deux adolescents s'enfoncent dans une forêt qu'ils croient connaître.",
            targetBudget: 28_000
        )
        context.insert(project)
        project.locations = [locations.parking]

        let titles = ["Séquence d'ouverture", "La clairière", "Le retour"]
        for (index, title) in titles.enumerated() {
            let scene = StoryScene(
                sceneNumber: "\(index + 1)",
                title: title,
                environment: index == 1 ? .exterior : .interiorExterior,
                timeOfDay: index == 2 ? .dusk : .day,
                estimatedDuration: TimeInterval(120 + index * 30),
                status: .draft,
                orderIndex: index
            )
            scene.project = project
            context.insert(scene)
        }
    }
}
