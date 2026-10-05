import Foundation

// what the employer says they paid for one pay period. hoursPaid and amountPaid are
// typed in from the payslip itself; attachmentFileName points at the saved copy.
struct Payslip: Identifiable, Hashable, Sendable {
    let id: UUID
    var workplaceID: UUID
    var periodStart: Date
    var periodEnd: Date
    var hoursPaid: Decimal
    var amountPaid: Decimal
    var attachmentFileName: String?

    init(id: UUID = UUID(),
         workplaceID: UUID,
         periodStart: Date,
         periodEnd: Date,
         hoursPaid: Decimal,
         amountPaid: Decimal,
         attachmentFileName: String? = nil) {
        self.id = id
        self.workplaceID = workplaceID
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.hoursPaid = hoursPaid
        self.amountPaid = amountPaid
        self.attachmentFileName = attachmentFileName
    }
}

// the answer to "was I paid properly for this period?"
struct PayslipReview: Equatable, Sendable {
    enum Verdict: Equatable, Sendable {
        case paidCorrectly
        case underpaid(shortfall: Decimal)
        case overpaid(excess: Decimal)
    }

    let payslip: Payslip
    let hoursRecorded: Decimal      // hours I logged as worked in the period
    let expectedPay: Decimal        // hoursRecorded x the workplace's award rate
    let verdict: Verdict

    // positive = the payslip counts fewer hours than I actually worked
    var hoursGap: Decimal { hoursRecorded - payslip.hoursPaid }
}
