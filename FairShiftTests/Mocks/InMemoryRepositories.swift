import Foundation
@testable import FairShift

// mock repositories: plain dictionaries, no Core Data. the use cases can't tell
// the difference because they only know the protocols.

final class InMemoryWorkplaceRepository: WorkplaceRepository {
    private(set) var stored: [UUID: Workplace] = [:]

    init(_ workplaces: [Workplace] = []) {
        workplaces.forEach { stored[$0.id] = $0 }
    }

    func allWorkplaces() throws -> [Workplace] { stored.values.sorted { $0.name < $1.name } }
    func workplace(id: UUID) throws -> Workplace? { stored[id] }
    func save(_ workplace: Workplace) throws { stored[workplace.id] = workplace }
}

final class InMemoryShiftRepository: ShiftRepository {
    private(set) var stored: [UUID: WorkShift] = [:]

    init(_ shifts: [WorkShift] = []) {
        shifts.forEach { stored[$0.id] = $0 }
    }

    func shift(id: UUID) throws -> WorkShift? { stored[id] }
    func save(_ shift: WorkShift) throws { stored[shift.id] = shift }
    func delete(id: UUID) throws { stored[id] = nil }

    func shifts(startingFrom start: Date, before end: Date) throws -> [WorkShift] {
        stored.values.filter { $0.startsAt >= start && $0.startsAt < end }.sorted { $0.startsAt < $1.startsAt }
    }

    func workedShifts(atWorkplace workplaceID: UUID, startingFrom start: Date, before end: Date) throws -> [WorkShift] {
        try shifts(startingFrom: start, before: end)
            .filter { $0.workplaceID == workplaceID && $0.status == .worked }
    }

    func nextRosteredShift(after date: Date) throws -> WorkShift? {
        stored.values.filter { $0.status == .rostered && $0.startsAt > date }.min { $0.startsAt < $1.startsAt }
    }
}

final class InMemoryPayslipRepository: PayslipRepository {
    private(set) var stored: [UUID: Payslip] = [:]

    init(_ payslips: [Payslip] = []) {
        payslips.forEach { stored[$0.id] = $0 }
    }

    func allPayslips() throws -> [Payslip] { stored.values.sorted { $0.periodEnd > $1.periodEnd } }
    func payslip(id: UUID) throws -> Payslip? { stored[id] }
    func payslips(atWorkplace workplaceID: UUID) throws -> [Payslip] {
        stored.values.filter { $0.workplaceID == workplaceID }
    }
    func save(_ payslip: Payslip) throws { stored[payslip.id] = payslip }
}

final class FixedWorkLimitSettings: WorkLimitSettingsRepository {
    var limit: VisaWorkLimit

    init(hours: Decimal = 48, anchor: Date = TestDates.fortnightStart) {
        limit = VisaWorkLimit(hoursPerFortnight: hours, fortnightAnchor: anchor)
    }

    func currentLimit() -> VisaWorkLimit { limit }
    func save(_ limit: VisaWorkLimit) { self.limit = limit }
}

final class RecordingWidgetReloader: WidgetTimelineReloading {
    private(set) var reloadCount = 0
    func reloadAllTimelines() { reloadCount += 1 }
}
