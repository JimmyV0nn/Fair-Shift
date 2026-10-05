import Foundation

// the point of the whole app: compares what the employer paid with what the
// student's own shift log says they were owed. only shifts that were really worked
// at that workplace count - rostered-but-not-worked shifts don't get paid.
struct ReviewPayslipAgainstShiftsUseCase {
    let workplaces: WorkplaceRepository
    let shifts: ShiftRepository
    let payslips: PayslipRepository

    // a few cents of rounding on a payslip isn't an underpayment
    static let tolerance: Decimal = 0.50

    enum Failure: LocalizedError, Equatable {
        case payslipNotFound
        case workplaceNotFound
        case noWorkedShiftsInPeriod(workplaceName: String, from: Date, to: Date)

        var errorDescription: String? {
            switch self {
            case .payslipNotFound:
                return "That payslip isn't in your list any more. Pick another one, or file it again."
            case .workplaceNotFound:
                return "The workplace for this payslip has been removed, so there's no pay rate to check it against. Add the workplace again under Workplaces."
            case .noWorkedShiftsInPeriod(let workplaceName, let from, let to):
                return "You haven't recorded any worked shifts at \(workplaceName) between \(DateText.day(from)) and \(DateText.day(to)), so there's nothing to compare. Record the shifts you worked in that period, then check again."
            }
        }
    }

    func execute(payslipID: UUID, calendar: Calendar = .current) throws -> PayslipReview {
        guard let payslip = try payslips.payslip(id: payslipID) else { throw Failure.payslipNotFound }
        guard let workplace = try workplaces.workplace(id: payslip.workplaceID) else { throw Failure.workplaceNotFound }

        let start = calendar.startOfDay(for: payslip.periodStart)
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: payslip.periodEnd))!
        let worked = try shifts.workedShifts(atWorkplace: workplace.id, startingFrom: start, before: endExclusive)
        guard !worked.isEmpty else {
            throw Failure.noWorkedShiftsInPeriod(workplaceName: workplace.name,
                                                 from: payslip.periodStart, to: payslip.periodEnd)
        }

        let hoursRecorded = worked.reduce(Decimal(0)) { $0 + $1.paidHours }
        let expectedPay = hoursRecorded * workplace.awardHourlyRate
        let difference = expectedPay - payslip.amountPaid

        let verdict: PayslipReview.Verdict
        if difference > Self.tolerance {
            verdict = .underpaid(shortfall: difference)
        } else if -difference > Self.tolerance {
            verdict = .overpaid(excess: -difference)
        } else {
            verdict = .paidCorrectly
        }
        return PayslipReview(payslip: payslip, hoursRecorded: hoursRecorded,
                             expectedPay: expectedPay, verdict: verdict)
    }
}
