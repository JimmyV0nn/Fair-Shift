import Foundation

// files a payslip against the pay period it covers. a workplace can only have one
// payslip per period - filing a second one for overlapping dates would make the
// pay check count the same hours twice.
struct RecordPayslipUseCase {
    let workplaces: WorkplaceRepository
    let payslips: PayslipRepository

    static let longestPayPeriodDays = 31

    enum Failure: LocalizedError, Equatable {
        case workplaceNotFound
        case periodEndsBeforeItStarts
        case periodTooLong(maxDays: Int)
        case hoursNotPositive
        case amountNotPositive
        case payslipAlreadyFiledForPeriod(workplaceName: String)

        var errorDescription: String? {
            switch self {
            case .workplaceNotFound:
                return "Pick the workplace this payslip is from. If it isn't in the list, add it under Workplaces first."
            case .periodEndsBeforeItStarts:
                return "The pay period ends before it starts. Check the dates printed at the top of the payslip."
            case .periodTooLong(let maxDays):
                return "That pay period is longer than \(maxDays) days, which is longer than any normal pay cycle. Check the dates on the payslip."
            case .hoursNotPositive:
                return "Enter the hours the payslip says you were paid for — it needs to be more than zero."
            case .amountNotPositive:
                return "Enter the pay amount from the payslip — it needs to be more than zero. Use the gross amount if you're not sure."
            case .payslipAlreadyFiledForPeriod(let workplaceName):
                return "You've already filed a payslip from \(workplaceName) that covers these dates. Open it from the Payslips list instead of adding it again."
            }
        }
    }

    @discardableResult
    func execute(workplaceID: UUID,
                 periodStart: Date,
                 periodEnd: Date,
                 hoursPaid: Decimal,
                 amountPaid: Decimal,
                 attachmentFileName: String? = nil,
                 calendar: Calendar = .current) throws -> Payslip {
        guard let workplace = try workplaces.workplace(id: workplaceID) else { throw Failure.workplaceNotFound }

        let start = calendar.startOfDay(for: periodStart)
        let end = calendar.startOfDay(for: periodEnd)
        guard end >= start else { throw Failure.periodEndsBeforeItStarts }

        let days = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        guard days <= Self.longestPayPeriodDays else { throw Failure.periodTooLong(maxDays: Self.longestPayPeriodDays) }
        guard hoursPaid > 0 else { throw Failure.hoursNotPositive }
        guard amountPaid > 0 else { throw Failure.amountNotPositive }

        let existing = try payslips.payslips(atWorkplace: workplaceID)
        if existing.contains(where: { $0.periodStart <= end && start <= $0.periodEnd }) {
            throw Failure.payslipAlreadyFiledForPeriod(workplaceName: workplace.name)
        }

        let payslip = Payslip(workplaceID: workplaceID, periodStart: start, periodEnd: end,
                              hoursPaid: hoursPaid, amountPaid: amountPaid,
                              attachmentFileName: attachmentFileName)
        try payslips.save(payslip)
        return payslip
    }
}
