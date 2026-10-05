import Foundation
import Observation

// one form for both "put a future shift on my roster" and "record a shift I worked".
// the mode decides which use case runs.
@MainActor
@Observable
final class ShiftEditorViewModel {
    enum Mode: Equatable {
        case roster
        case recordWorked(rosteredShiftID: UUID?)
    }

    private let environment: AppEnvironment
    let mode: Mode

    var workplaces: [Workplace] = []
    var workplaceID: UUID?
    var startsAt: Date
    var endsAt: Date
    var unpaidBreakMinutes = 30

    var errorMessage: String?
    var limitWarning: String?
    var didSave = false

    init(environment: AppEnvironment, mode: Mode, prefill: WorkShift? = nil, now: Date = Date()) {
        self.environment = environment
        self.mode = mode

        let calendar = Calendar.current
        if let prefill {
            workplaceID = prefill.workplaceID
            startsAt = prefill.startsAt
            endsAt = prefill.endsAt
            unpaidBreakMinutes = prefill.unpaidBreakMinutes
        } else if mode == .roster {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
            startsAt = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: tomorrow)!
            endsAt = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: tomorrow)!
        } else {
            let hourAgo = calendar.date(byAdding: .hour, value: -1, to: now)!
            startsAt = calendar.date(byAdding: .hour, value: -5, to: hourAgo)!
            endsAt = hourAgo
        }
    }

    var title: String {
        switch mode {
        case .roster: return "Roster a shift"
        case .recordWorked: return "Record a worked shift"
        }
    }

    var saveButtonTitle: String {
        mode == .roster ? "Add to roster" : "Record shift"
    }

    func load() {
        workplaces = (try? environment.workplaces.allWorkplaces()) ?? []
        if workplaceID == nil { workplaceID = workplaces.first?.id }
    }

    func save(now: Date = Date()) {
        errorMessage = nil
        limitWarning = nil

        guard let workplaceID else {
            errorMessage = RosterUpcomingShiftUseCase.Failure.workplaceNotFound.localizedDescription
            return
        }

        do {
            switch mode {
            case .roster:
                try environment.rosterShift.execute(workplaceID: workplaceID, startsAt: startsAt, endsAt: endsAt,
                                                    unpaidBreakMinutes: unpaidBreakMinutes, now: now)
            case .recordWorked(let rosteredShiftID):
                let outcome = try environment.recordWorkedShift.execute(
                    rosteredShiftID: rosteredShiftID, workplaceID: workplaceID, startsAt: startsAt,
                    endsAt: endsAt, unpaidBreakMinutes: unpaidBreakMinutes, now: now)
                if outcome.fortnight.isOverLimit {
                    limitWarning = "Recorded — but that's \(HoursFormat.string(outcome.fortnight.hoursOverLimit)) hours over your \(HoursFormat.string(outcome.fortnight.limitHours))-hour fortnight limit. Talk to your employer about cutting back your next shifts."
                }
            }
            didSave = true
            environment.widgetPublisher.publish(now: now)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
