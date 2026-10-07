import Foundation
import Observation

// the Payslips tab: filed payslips with their pay check result, plus any payslip
// files shared in that still need the numbers typed up.
@MainActor
@Observable
final class PayslipsViewModel {
    struct Row: Identifiable {
        let payslip: Payslip
        let workplaceName: String
        let review: PayslipReview?
        let reviewProblem: String?
        var id: UUID { payslip.id }
    }

    private let environment: AppEnvironment

    var rows: [Row] = []
    var sharedItems: [SharedPayslipItem] = []
    var errorMessage: String?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func refresh() {
        do {
            let names = Dictionary(uniqueKeysWithValues: try environment.workplaces.allWorkplaces().map { ($0.id, $0.name) })
            rows = try environment.payslips.allPayslips().map { payslip in
                do {
                    let review = try environment.reviewPayslip.execute(payslipID: payslip.id)
                    return Row(payslip: payslip, workplaceName: names[payslip.workplaceID] ?? "Unknown workplace",
                               review: review, reviewProblem: nil)
                } catch {
                    return Row(payslip: payslip, workplaceName: names[payslip.workplaceID] ?? "Unknown workplace",
                               review: nil, reviewProblem: error.localizedDescription)
                }
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        sharedItems = environment.inbox.pendingItems()
    }

    func discard(_ item: SharedPayslipItem) {
        environment.inbox.discard(item)
        refresh()
    }
}
