import Foundation
import Observation

// files a payslip - either typed in from scratch or finishing one that was shared in.
@MainActor
@Observable
final class PayslipEntryViewModel {
    private let environment: AppEnvironment
    let sharedItem: SharedPayslipItem?

    var workplaces: [Workplace] = []
    var workplaceID: UUID?
    var periodStart: Date
    var periodEnd: Date
    var hoursText = ""
    var amountText = ""

    var errorMessage: String?
    var didSave = false

    init(environment: AppEnvironment, sharedItem: SharedPayslipItem? = nil, now: Date = Date()) {
        self.environment = environment
        self.sharedItem = sharedItem
        let calendar = Calendar.current
        periodEnd = calendar.startOfDay(for: now)
        periodStart = calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: now))!
    }

    var attachmentURL: URL? {
        sharedItem.flatMap { environment.inbox.url(for: $0) }
    }

    func load() {
        workplaces = (try? environment.workplaces.allWorkplaces()) ?? []
        if workplaceID == nil { workplaceID = workplaces.first?.id }
    }

    func save() {
        errorMessage = nil

        guard let workplaceID else {
            errorMessage = RecordPayslipUseCase.Failure.workplaceNotFound.localizedDescription
            return
        }
        guard let hours = Decimal(string: hoursText.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = RecordPayslipUseCase.Failure.hoursNotPositive.localizedDescription
            return
        }
        guard let amount = Decimal(string: amountText.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = RecordPayslipUseCase.Failure.amountNotPositive.localizedDescription
            return
        }

        do {
            // use case validates first, and only then does the file leave the inbox -
            // so a rejected payslip doesn't lose its attachment
            try environment.recordPayslip.execute(workplaceID: workplaceID, periodStart: periodStart,
                                                  periodEnd: periodEnd, hoursPaid: hours, amountPaid: amount,
                                                  attachmentFileName: sharedItem?.fileName)
            if let sharedItem {
                _ = try? environment.inbox.adopt(sharedItem)
            }
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
