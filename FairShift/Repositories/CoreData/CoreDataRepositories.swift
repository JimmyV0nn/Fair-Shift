import CoreData

// the Core Data versions of the repository protocols. every fetch / save goes through
// fetchAll and commit, so any Core Data failure just comes out as one RepositoryError
// instead of leaking Core Data errors up to the use cases.

private extension NSManagedObjectContext {
    func fetchAll<T: NSManagedObject>(_ type: T.Type,
                                      entityName: String,
                                      predicate: NSPredicate? = nil,
                                      sort: [NSSortDescriptor] = [],
                                      limit: Int = 0) throws -> [T] {
        var result: [T] = []
        var failure: Error?
        performAndWait {
            let request = NSFetchRequest<T>(entityName: entityName)
            request.predicate = predicate
            request.sortDescriptors = sort
            request.fetchLimit = limit
            do { result = try fetch(request) } catch { failure = error }
        }
        if failure != nil { throw RepositoryError.storeUnavailable }
        return result
    }

    func commit() throws {
        var failure: Error?
        performAndWait {
            guard hasChanges else { return }
            do { try save() } catch { failure = error; rollback() }
        }
        if failure != nil { throw RepositoryError.storeUnavailable }
    }
}

struct CoreDataWorkplaceRepository: WorkplaceRepository {
    let context: NSManagedObjectContext

    func allWorkplaces() throws -> [Workplace] {
        try context.fetchAll(WorkplaceEntity.self, entityName: "WorkplaceEntity",
                             sort: [NSSortDescriptor(key: "name", ascending: true)]).map(\.domain)
    }

    func workplace(id: UUID) throws -> Workplace? {
        try entity(id: id)?.domain
    }

    func save(_ workplace: Workplace) throws {
        let entity = try entity(id: workplace.id) ?? WorkplaceEntity(context: context)
        entity.apply(workplace)
        try context.commit()
    }

    private func entity(id: UUID) throws -> WorkplaceEntity? {
        try context.fetchAll(WorkplaceEntity.self, entityName: "WorkplaceEntity",
                             predicate: NSPredicate(format: "id == %@", id as CVarArg), limit: 1).first
    }
}

struct CoreDataShiftRepository: ShiftRepository {
    let context: NSManagedObjectContext

    func shift(id: UUID) throws -> WorkShift? {
        try entity(id: id)?.domain
    }

    func save(_ shift: WorkShift) throws {
        guard let workplace = try context.fetchAll(WorkplaceEntity.self, entityName: "WorkplaceEntity",
                                                   predicate: NSPredicate(format: "id == %@", shift.workplaceID as CVarArg),
                                                   limit: 1).first
        else { throw RepositoryError.storeUnavailable }

        let entity = try entity(id: shift.id) ?? WorkShiftEntity(context: context)
        entity.apply(shift, workplace: workplace)
        try context.commit()
    }

    func delete(id: UUID) throws {
        guard let entity = try entity(id: id) else { return }
        context.performAndWait { context.delete(entity) }
        try context.commit()
    }

    func shifts(startingFrom start: Date, before end: Date) throws -> [WorkShift] {
        let predicate = NSPredicate(format: "startsAt >= %@ AND startsAt < %@", start as NSDate, end as NSDate)
        return try context.fetchAll(WorkShiftEntity.self, entityName: "WorkShiftEntity", predicate: predicate,
                                    sort: [NSSortDescriptor(key: "startsAt", ascending: true)]).compactMap(\.domain)
    }

    func workedShifts(atWorkplace workplaceID: UUID, startingFrom start: Date, before end: Date) throws -> [WorkShift] {
        let predicate = NSPredicate(
            format: "workplace.id == %@ AND statusRaw == %@ AND startsAt >= %@ AND startsAt < %@",
            workplaceID as CVarArg, ShiftStatus.worked.rawValue, start as NSDate, end as NSDate)
        return try context.fetchAll(WorkShiftEntity.self, entityName: "WorkShiftEntity", predicate: predicate,
                                    sort: [NSSortDescriptor(key: "startsAt", ascending: true)]).compactMap(\.domain)
    }

    func nextRosteredShift(after date: Date) throws -> WorkShift? {
        let predicate = NSPredicate(format: "statusRaw == %@ AND startsAt > %@",
                                    ShiftStatus.rostered.rawValue, date as NSDate)
        return try context.fetchAll(WorkShiftEntity.self, entityName: "WorkShiftEntity", predicate: predicate,
                                    sort: [NSSortDescriptor(key: "startsAt", ascending: true)], limit: 1)
            .compactMap(\.domain).first
    }

    private func entity(id: UUID) throws -> WorkShiftEntity? {
        try context.fetchAll(WorkShiftEntity.self, entityName: "WorkShiftEntity",
                             predicate: NSPredicate(format: "id == %@", id as CVarArg), limit: 1).first
    }
}

struct CoreDataPayslipRepository: PayslipRepository {
    let context: NSManagedObjectContext

    func allPayslips() throws -> [Payslip] {
        try context.fetchAll(PayslipEntity.self, entityName: "PayslipEntity",
                             sort: [NSSortDescriptor(key: "periodEnd", ascending: false)]).compactMap(\.domain)
    }

    func payslip(id: UUID) throws -> Payslip? {
        try entity(id: id)?.domain
    }

    func payslips(atWorkplace workplaceID: UUID) throws -> [Payslip] {
        try context.fetchAll(PayslipEntity.self, entityName: "PayslipEntity",
                             predicate: NSPredicate(format: "workplace.id == %@", workplaceID as CVarArg),
                             sort: [NSSortDescriptor(key: "periodEnd", ascending: false)]).compactMap(\.domain)
    }

    func save(_ payslip: Payslip) throws {
        guard let workplace = try context.fetchAll(WorkplaceEntity.self, entityName: "WorkplaceEntity",
                                                   predicate: NSPredicate(format: "id == %@", payslip.workplaceID as CVarArg),
                                                   limit: 1).first
        else { throw RepositoryError.storeUnavailable }

        let entity = try entity(id: payslip.id) ?? PayslipEntity(context: context)
        entity.apply(payslip, workplace: workplace)
        try context.commit()
    }

    private func entity(id: UUID) throws -> PayslipEntity? {
        try context.fetchAll(PayslipEntity.self, entityName: "PayslipEntity",
                             predicate: NSPredicate(format: "id == %@", id as CVarArg), limit: 1).first
    }
}

// the visa limit is just two values, not worth a table - so it sits in the App Group
// defaults.
struct UserDefaultsWorkLimitSettingsRepository: WorkLimitSettingsRepository {
    var defaults: UserDefaults = AppGroup.userDefaults
    var calendar: Calendar = .current

    private let hoursKey = "visaLimit.hoursPerFortnight"
    private let anchorKey = "visaLimit.fortnightAnchor"

    func currentLimit() -> VisaWorkLimit {
        let hours = defaults.object(forKey: hoursKey) as? Double
        let anchor = defaults.object(forKey: anchorKey) as? Date
        return VisaWorkLimit(
            hoursPerFortnight: hours.map { Decimal($0) } ?? VisaWorkLimit.defaultHoursPerFortnight,
            // no date picked yet? just start counting from last Monday
            fortnightAnchor: anchor ?? Self.mostRecentMonday(calendar: calendar))
    }

    func save(_ limit: VisaWorkLimit) {
        defaults.set(NSDecimalNumber(decimal: limit.hoursPerFortnight).doubleValue, forKey: hoursKey)
        defaults.set(limit.fortnightAnchor, forKey: anchorKey)
    }

    static func mostRecentMonday(calendar: Calendar, now: Date = Date()) -> Date {
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)   // 1 = Sunday
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: today)!
    }
}
