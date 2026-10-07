import Foundation

// use cases and view models only know these protocols - nothing outside
// Repositories/CoreData has any idea Core Data exists. tests swap in in-memory ones.

enum RepositoryError: LocalizedError {
    case storeUnavailable

    var errorDescription: String? {
        "FairShift couldn't read or save your shifts. Close the app and open it again — if it keeps happening, restart your phone."
    }
}

protocol WorkplaceRepository {
    func allWorkplaces() throws -> [Workplace]
    func workplace(id: UUID) throws -> Workplace?
    func save(_ workplace: Workplace) throws
}

protocol ShiftRepository {
    func shift(id: UUID) throws -> WorkShift?
    func save(_ shift: WorkShift) throws
    func delete(id: UUID) throws

    // all shifts (any workplace) that start between start and end
    func shifts(startingFrom start: Date, before end: Date) throws -> [WorkShift]

    // only shifts I really worked at one workplace - used for the pay check
    func workedShifts(atWorkplace workplaceID: UUID, startingFrom start: Date, before end: Date) throws -> [WorkShift]

    // next rostered shift that hasn't started yet
    func nextRosteredShift(after date: Date) throws -> WorkShift?
}

protocol PayslipRepository {
    func allPayslips() throws -> [Payslip]
    func payslip(id: UUID) throws -> Payslip?
    func payslips(atWorkplace workplaceID: UUID) throws -> [Payslip]
    func save(_ payslip: Payslip) throws
}

protocol WorkLimitSettingsRepository {
    func currentLimit() -> VisaWorkLimit
    func save(_ limit: VisaWorkLimit)
}
