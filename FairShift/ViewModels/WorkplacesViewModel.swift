import Foundation
import Observation

@MainActor
@Observable
final class WorkplacesViewModel {
    private let environment: AppEnvironment

    var workplaces: [Workplace] = []
    var errorMessage: String?

    // add-workplace form
    var newName = ""
    var newRateText = ""

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func refresh() {
        do {
            workplaces = try environment.workplaces.allWorkplaces()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // returns true when the workplace was saved
    func addWorkplace() -> Bool {
        errorMessage = nil
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            errorMessage = "Enter the name of the place you work, e.g. the café or shop name on your payslip."
            return false
        }
        guard let rate = Decimal(string: newRateText.trimmingCharacters(in: .whitespaces)), rate > 0 else {
            errorMessage = "Enter your hourly pay rate as a number, e.g. 25.41. It's on your contract or the Fair Work pay guide for your award."
            return false
        }

        do {
            try environment.workplaces.save(Workplace(name: name, awardHourlyRate: rate))
            newName = ""
            newRateText = ""
            environment.widgetPublisher.publish()
            refresh()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
