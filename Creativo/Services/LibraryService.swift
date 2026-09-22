import Foundation
import SwiftData

/// Creation, deletion and project assignment for the global library.
///
/// The rule enforced here: library entities outlive projects. Removing someone
/// from a production detaches the assignment, it never deletes the person.
enum LibraryService {
    // MARK: People

    @discardableResult
    static func createPerson(
        firstName: String = "",
        lastName: String = "",
        role: CrewRole = .other,
        context: ModelContext
    ) -> Person {
        let person = Person(firstName: firstName, lastName: lastName, role: role)
        context.insert(person)
        PersistenceActions.save(context)
        return person
    }

    /// Deletes a person from the library and, by cascade, all their assignments.
    static func deletePerson(_ person: Person, context: ModelContext) {
        let touched = Set(person.assignments.compactMap { $0.project })
        context.delete(person)
        for project in touched { project.touch() }
        PersistenceActions.save(context)
    }

    // MARK: Locations

    @discardableResult
    static func createLocation(name: String = "", context: ModelContext) -> ProductionLocation {
        let location = ProductionLocation(name: name)
        context.insert(location)
        PersistenceActions.save(context)
        return location
    }

    static func deleteLocation(_ location: ProductionLocation, context: ModelContext) {
        let touched = Set(location.projects)
        context.delete(location)
        for project in touched { project.touch() }
        PersistenceActions.save(context)
    }

    // MARK: Equipment

    @discardableResult
    static func createEquipment(
        name: String = "",
        category: EquipmentCategory = .other,
        context: ModelContext
    ) -> EquipmentItem {
        let item = EquipmentItem(name: name, category: category)
        context.insert(item)
        PersistenceActions.save(context)
        return item
    }

    static func deleteEquipment(_ item: EquipmentItem, context: ModelContext) {
        let touched = Set(item.assignments.compactMap { $0.project })
        context.delete(item)
        for project in touched { project.touch() }
        PersistenceActions.save(context)
    }

    // MARK: Assignments

    /// Adds a person to a project. Adding twice is a no-op.
    @discardableResult
    static func assign(
        _ person: Person,
        to project: Project,
        role: CrewRole? = nil,
        context: ModelContext
    ) -> ProjectPersonAssignment {
        if let existing = project.peopleAssignments.first(where: { $0.person?.id == person.id }) {
            return existing
        }
        let assignment = ProjectPersonAssignment(
            project: project,
            person: person,
            roleOverride: role
        )
        context.insert(assignment)
        project.touch()
        PersistenceActions.save(context)
        return assignment
    }

    /// Detaches a person from a project. The person stays in the library.
    static func unassign(_ assignment: ProjectPersonAssignment, context: ModelContext) {
        let project = assignment.project
        context.delete(assignment)
        project?.touch()
        PersistenceActions.save(context)
    }

    @discardableResult
    static func assign(
        _ item: EquipmentItem,
        to project: Project,
        quantity: Int = 1,
        context: ModelContext
    ) -> ProjectEquipmentAssignment {
        if let existing = project.equipmentAssignments.first(where: { $0.equipment?.id == item.id }) {
            return existing
        }
        let assignment = ProjectEquipmentAssignment(
            project: project,
            equipment: item,
            quantity: max(quantity, 1)
        )
        context.insert(assignment)
        project.touch()
        PersistenceActions.save(context)
        return assignment
    }

    static func unassign(_ assignment: ProjectEquipmentAssignment, context: ModelContext) {
        let project = assignment.project
        context.delete(assignment)
        project?.touch()
        PersistenceActions.save(context)
    }

    static func attach(_ location: ProductionLocation, to project: Project, context: ModelContext) {
        guard !project.locations.contains(where: { $0.id == location.id }) else { return }
        project.locations.append(location)
        project.touch()
        PersistenceActions.save(context)
    }

    /// Removes a location from a project and from the scenes of that project only.
    static func detach(_ location: ProductionLocation, from project: Project, context: ModelContext) {
        project.locations.removeAll { $0.id == location.id }
        for scene in project.scenes where scene.location?.id == location.id {
            scene.location = nil
        }
        project.touch()
        PersistenceActions.save(context)
    }

    static func commitEdits(context: ModelContext) {
        PersistenceActions.save(context)
    }

    // MARK: Search

    static func filter(_ people: [Person], query: String) -> [Person] {
        guard !query.isBlank else { return people }
        return people.filter { $0.searchHaystack.matches(query) }
    }

    static func filter(_ locations: [ProductionLocation], query: String) -> [ProductionLocation] {
        guard !query.isBlank else { return locations }
        return locations.filter { $0.searchHaystack.matches(query) }
    }

    static func filter(_ items: [EquipmentItem], query: String) -> [EquipmentItem] {
        guard !query.isBlank else { return items }
        return items.filter { $0.searchHaystack.matches(query) }
    }
}
