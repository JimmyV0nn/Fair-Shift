import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private let environment: AppEnvironment

    var hoursPerFortnight: Double
    var fortnightAnchor: Date
    var message: String?

    init(environment: AppEnvironment) {
        self.environment = environment
        let limit = environment.workLimit.currentLimit()
        hoursPerFortnight = NSDecimalNumber(decimal: limit.hoursPerFortnight).doubleValue
        fortnightAnchor = limit.fortnightAnchor
    }

    func save() {
        environment.workLimit.save(VisaWorkLimit(hoursPerFortnight: Decimal(hoursPerFortnight),
                                                 fortnightAnchor: fortnightAnchor))
        environment.widgetPublisher.publish()
        message = "Saved. Your fortnight count has been updated."
    }

    func loadSampleData() {
        do {
            try SampleData.load(into: environment)
            environment.widgetPublisher.publish()
            message = "Sample shifts and a short-paid payslip added — check the This Fortnight and Payslips tabs."
        } catch {
            message = error.localizedDescription
        }
    }
}
