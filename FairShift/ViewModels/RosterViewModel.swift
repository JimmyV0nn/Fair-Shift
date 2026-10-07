import Foundation
import Observation

@MainActor
@Observable
final class RosterViewModel {
    struct Row: Identifiable {
        let shift: WorkShift
        let workplaceName: String
        var id: UUID { shift.id }
    }

    private let environment: AppEnvironment

    var rows: [Row] = []
    var errorMessage: String?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    // 2 weeks back (so I can still record them) and 2 months ahead
    func refresh(now: Date = Date()) {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: now))!
        let end = calendar.date(byAdding: .day, value: 60, to: now)!

        do {
            let names = Dictionary(uniqueKeysWithValues: try environment.workplaces.allWorkplaces().map { ($0.id, $0.name) })
            rows = try environment.shifts.shifts(startingFrom: start, before: end)
                .map { Row(shift: $0, workplaceName: names[$0.workplaceID] ?? "Unknown workplace") }
                .reversed()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ shift: WorkShift) {
        do {
            try environment.shifts.delete(id: shift.id)
            environment.widgetPublisher.publish()
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
