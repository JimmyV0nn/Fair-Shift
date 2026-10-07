import Foundation

// records what really happened: either turns a rostered shift into a worked one
// (with the real finish time) or logs a shift that was never on the roster.
// unlike rostering, going over the visa limit is NOT refused here - the hours are
// already worked, so the record has to be honest. it hands back the fortnight status
// so the screen can warn about it instead.
struct RecordWorkedShiftUseCase {
    let workplaces: WorkplaceRepository
    let shifts: ShiftRepository
    let workLimit: WorkLimitSettingsRepository
    var calendar: Calendar = .current

    struct Outcome: Equatable {
        let shift: WorkShift
        let fortnight: FortnightHoursStatus
    }

    enum Failure: LocalizedError, Equatable {
        case workplaceNotFound
        case rosteredShiftNotFound
        case shiftAlreadyRecorded
        case shiftEndsBeforeItStarts
        case breakLongerThanShift
        case shiftNotFinishedYet
        case overlapsAnotherShift(startsAt: Date, endsAt: Date)

        var errorDescription: String? {
            switch self {
            case .workplaceNotFound:
                return "Pick the workplace you worked at. If it isn't in the list, add it under Workplaces first."
            case .rosteredShiftNotFound:
                return "That rostered shift isn't there any more — it may have been removed. Log the shift again as a new one."
            case .shiftAlreadyRecorded:
                return "You've already recorded this shift as worked, so it won't be counted twice."
            case .shiftEndsBeforeItStarts:
                return "This shift finishes before it starts. Check the start and finish times."
            case .breakLongerThanShift:
                return "The unpaid break is as long as the whole shift, so there'd be no paid hours. Shorten the break or check the times."
            case .shiftNotFinishedYet:
                return "That shift hasn't finished yet. Come back and record it once you've clocked off."
            case .overlapsAnotherShift(let startsAt, let endsAt):
                return "You've already got a shift from \(DateText.dayAndTime(startsAt)) to \(DateText.dayAndTime(endsAt)) that overlaps this one. Check the times, or remove the other shift."
            }
        }
    }

    @discardableResult
    func execute(rosteredShiftID: UUID? = nil,
                 workplaceID: UUID,
                 startsAt: Date,
                 endsAt: Date,
                 unpaidBreakMinutes: Int,
                 now: Date = Date()) throws -> Outcome {
        guard try workplaces.workplace(id: workplaceID) != nil else { throw Failure.workplaceNotFound }

        var shiftID = UUID()
        if let rosteredShiftID {
            guard let existing = try shifts.shift(id: rosteredShiftID) else { throw Failure.rosteredShiftNotFound }
            guard existing.status == .rostered else { throw Failure.shiftAlreadyRecorded }
            shiftID = existing.id
        }

        guard endsAt > startsAt else { throw Failure.shiftEndsBeforeItStarts }
        guard endsAt <= now else { throw Failure.shiftNotFinishedYet }

        let shift = WorkShift(id: shiftID, workplaceID: workplaceID, startsAt: startsAt, endsAt: endsAt,
                              unpaidBreakMinutes: unpaidBreakMinutes, status: .worked)
        guard shift.paidMinutes > 0 else { throw Failure.breakLongerThanShift }

        let nearby = try shifts.shifts(startingFrom: startsAt.addingTimeInterval(-86_400),
                                       before: endsAt.addingTimeInterval(86_400))
        if let clash = nearby.first(where: { $0.id != shiftID && $0.overlaps(shift) }) {
            throw Failure.overlapsAnotherShift(startsAt: clash.startsAt, endsAt: clash.endsAt)
        }

        try shifts.save(shift)

        let limit = workLimit.currentLimit()
        let window = limit.window(containing: startsAt, calendar: calendar)
        let inWindow = try shifts.shifts(startingFrom: window.start, before: window.end)
        let status = FortnightHoursStatus.make(window: window, limit: limit.hoursPerFortnight, shifts: inWindow)
        return Outcome(shift: shift, fortnight: status)
    }
}
