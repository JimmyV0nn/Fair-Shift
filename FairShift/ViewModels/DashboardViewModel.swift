import Foundation
import Observation

// drives "This Fortnight": hours used against the visa limit, the next shift, and
// whether there are payslips waiting from the share sheet.
@MainActor
@Observable
final class DashboardViewModel {
    struct NextShift {
        let workplaceName: String
        let startsAt: Date
        let endsAt: Date
    }

    private let environment: AppEnvironment

    var status: FortnightHoursStatus?
    var nextShift: NextShift?
    var needsFirstWorkplace = false
    var pendingPayslipCount = 0
    var errorMessage: String?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func refresh(now: Date = Date()) {
        errorMessage = nil
        do {
            status = try environment.checkFortnightHours.execute(now: now)
            needsFirstWorkplace = false
        } catch CheckFortnightHoursUseCase.Failure.noWorkplaceSetUp {
            status = nil
            needsFirstWorkplace = true
        } catch {
            errorMessage = error.localizedDescription
        }

        nextShift = nil
        if let shift = try? environment.shifts.nextRosteredShift(after: now),
           let workplace = try? environment.workplaces.workplace(id: shift.workplaceID) {
            nextShift = NextShift(workplaceName: workplace.name, startsAt: shift.startsAt, endsAt: shift.endsAt)
        }

        pendingPayslipCount = environment.inbox.pendingItems().count
        environment.widgetPublisher.publish(now: now)
    }
}
