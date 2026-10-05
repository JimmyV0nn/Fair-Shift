import Foundation
import WidgetKit

protocol WidgetTimelineReloading {
    func reloadAllTimelines()
}

struct SystemWidgetReloader: WidgetTimelineReloading {
    func reloadAllTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// called after every change that could alter what the widget shows (a shift added,
// removed or recorded, a workplace added, the visa limit changed). it rebuilds the
// snapshot in the App Group and tells WidgetKit to redraw.
struct WidgetSnapshotPublisher {
    let checkHours: CheckFortnightHoursUseCase
    let shifts: ShiftRepository
    let workplaces: WorkplaceRepository
    let reloader: WidgetTimelineReloading
    var write: (WidgetSnapshot) throws -> Void = WidgetSnapshotStore.save

    func publish(now: Date = Date()) {
        let snapshot = makeSnapshot(now: now)
        try? write(snapshot)
        reloader.reloadAllTimelines()
    }

    func makeSnapshot(now: Date) -> WidgetSnapshot {
        guard let status = try? checkHours.execute(now: now) else {
            return .notSetUp(now: now)
        }

        var next: WidgetSnapshot.NextShift?
        if let shift = try? shifts.nextRosteredShift(after: now),
           let workplace = try? workplaces.workplace(id: shift.workplaceID) {
            next = .init(workplaceName: workplace.name, startsAt: shift.startsAt, endsAt: shift.endsAt)
        }

        return WidgetSnapshot(
            isSetUp: true,
            hoursWorked: NSDecimalNumber(decimal: status.hoursWorked).doubleValue,
            hoursRostered: NSDecimalNumber(decimal: status.hoursRostered).doubleValue,
            limitHours: NSDecimalNumber(decimal: status.limitHours).doubleValue,
            windowStart: status.window.start,
            windowEnd: status.window.end,
            nextShift: next,
            generatedAt: now)
    }
}
