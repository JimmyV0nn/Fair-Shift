import Foundation

// "how many hours have I got left this fortnight?" - the number the whole app
// (dashboard, widget, lock screen) is built around.
struct CheckFortnightHoursUseCase {
    let workplaces: WorkplaceRepository
    let shifts: ShiftRepository
    let workLimit: WorkLimitSettingsRepository
    var calendar: Calendar = .current

    enum Failure: LocalizedError, Equatable {
        case noWorkplaceSetUp

        var errorDescription: String? {
            switch self {
            case .noWorkplaceSetUp:
                return "Add the place you work first, then log your shifts, and FairShift will count your hours against your visa limit."
            }
        }
    }

    func execute(now: Date = Date()) throws -> FortnightHoursStatus {
        guard try !workplaces.allWorkplaces().isEmpty else { throw Failure.noWorkplaceSetUp }

        let limit = workLimit.currentLimit()
        let window = limit.window(containing: now, calendar: calendar)
        let inWindow = try shifts.shifts(startingFrom: window.start, before: window.end)
        return FortnightHoursStatus.make(window: window, limit: limit.hoursPerFortnight, shifts: inWindow)
    }
}
