import Foundation

// puts a future shift on the roster - but only if it's a shift the student can
// actually legally work. the visa rule matters most: a shift that would push the
// fortnight over the limit is refused instead of quietly added.
struct RosterUpcomingShiftUseCase {
    let workplaces: WorkplaceRepository
    let shifts: ShiftRepository
    let workLimit: WorkLimitSettingsRepository
    var calendar: Calendar = .current

    enum Failure: LocalizedError, Equatable {
        case workplaceNotFound
        case shiftEndsBeforeItStarts
        case breakLongerThanShift
        case shiftAlreadyStarted
        case overlapsAnotherShift(startsAt: Date, endsAt: Date)
        case wouldExceedFortnightLimit(hoursOver: Decimal, limitHours: Decimal)

        var errorDescription: String? {
            switch self {
            case .workplaceNotFound:
                return "Pick the workplace this shift is at. If it isn't in the list, add it under Workplaces first."
            case .shiftEndsBeforeItStarts:
                return "This shift finishes before it starts. Check the start and finish times."
            case .breakLongerThanShift:
                return "The unpaid break is as long as the whole shift, so there'd be no paid hours. Shorten the break or lengthen the shift."
            case .shiftAlreadyStarted:
                return "That start time has already passed. Use \"Record a worked shift\" for shifts that have already happened."
            case .overlapsAnotherShift(let startsAt, let endsAt):
                return "You're already on the roster from \(DateText.dayAndTime(startsAt)) to \(DateText.dayAndTime(endsAt)). Change this shift's times or remove the other one."
            case .wouldExceedFortnightLimit(let hoursOver, let limitHours):
                return "This shift would put you \(HoursFormat.string(hoursOver)) hours over your \(HoursFormat.string(limitHours))-hour fortnight limit. Shorten it, or ask your manager to move it to the next fortnight."
            }
        }
    }

    @discardableResult
    func execute(workplaceID: UUID,
                 startsAt: Date,
                 endsAt: Date,
                 unpaidBreakMinutes: Int,
                 now: Date = Date()) throws -> WorkShift {
        guard try workplaces.workplace(id: workplaceID) != nil else { throw Failure.workplaceNotFound }
        guard endsAt > startsAt else { throw Failure.shiftEndsBeforeItStarts }

        let shift = WorkShift(workplaceID: workplaceID, startsAt: startsAt, endsAt: endsAt,
                              unpaidBreakMinutes: unpaidBreakMinutes, status: .rostered)
        guard shift.paidMinutes > 0 else { throw Failure.breakLongerThanShift }
        guard startsAt > now else { throw Failure.shiftAlreadyStarted }

        let nearby = try shifts.shifts(startingFrom: startsAt.addingTimeInterval(-86_400),
                                       before: endsAt.addingTimeInterval(86_400))
        if let clash = nearby.first(where: { $0.overlaps(shift) }) {
            throw Failure.overlapsAnotherShift(startsAt: clash.startsAt, endsAt: clash.endsAt)
        }

        let limit = workLimit.currentLimit()
        let window = limit.window(containing: startsAt, calendar: calendar)
        let inWindow = try shifts.shifts(startingFrom: window.start, before: window.end)
        let status = FortnightHoursStatus.make(window: window, limit: limit.hoursPerFortnight,
                                               shifts: inWindow + [shift])
        if status.isOverLimit {
            throw Failure.wouldExceedFortnightLimit(hoursOver: status.hoursOverLimit,
                                                    limitHours: limit.hoursPerFortnight)
        }

        try shifts.save(shift)
        return shift
    }
}
