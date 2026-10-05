import XCTest
@testable import FairShift

final class ReviewPayslipAgainstShiftsUseCaseTests: XCTestCase {
    // cafe pays $25/h. two worked shifts of 6h = 12h = $300 owed
    private let workedShifts = [Fixtures.workedShift(day: 1), Fixtures.workedShift(day: 3)]

    private func makePayslip(hours: Decimal, amount: Decimal, workplace: Workplace = Fixtures.cafe) -> Payslip {
        Payslip(workplaceID: workplace.id, periodStart: TestDates.at(day: 0), periodEnd: TestDates.at(day: 6),
                hoursPaid: hours, amountPaid: amount)
    }

    private func makeUseCase(shifts: [WorkShift], payslip: Payslip) -> ReviewPayslipAgainstShiftsUseCase {
        ReviewPayslipAgainstShiftsUseCase(
            workplaces: InMemoryWorkplaceRepository([Fixtures.cafe, Fixtures.warehouse]),
            shifts: InMemoryShiftRepository(shifts),
            payslips: InMemoryPayslipRepository([payslip]))
    }

    func test_flagsAnUnderpayment_whenThePayslipPaysForFewerHoursThanWereWorked() throws {
        let payslip = makePayslip(hours: 10, amount: 250)   // owed 12h x $25 = $300
        let review = try makeUseCase(shifts: workedShifts, payslip: payslip).execute(payslipID: payslip.id)

        XCTAssertEqual(review.hoursRecorded, 12)
        XCTAssertEqual(review.expectedPay, 300)
        XCTAssertEqual(review.verdict, .underpaid(shortfall: 50))
        XCTAssertEqual(review.hoursGap, 2)
    }

    func test_acceptsAPayslip_thatMatchesWhatWasOwed() throws {
        let payslip = makePayslip(hours: 12, amount: 300)
        let review = try makeUseCase(shifts: workedShifts, payslip: payslip).execute(payslipID: payslip.id)

        XCTAssertEqual(review.verdict, .paidCorrectly)
    }

    func test_treatsAFewCentsOfRoundingAsPaidCorrectly_butNotAFullDollar() throws {
        let rounding = makePayslip(hours: 12, amount: 299.60)
        XCTAssertEqual(try makeUseCase(shifts: workedShifts, payslip: rounding).execute(payslipID: rounding.id).verdict,
                       .paidCorrectly)

        let dollarShort = makePayslip(hours: 12, amount: 299)
        XCTAssertEqual(try makeUseCase(shifts: workedShifts, payslip: dollarShort).execute(payslipID: dollarShort.id).verdict,
                       .underpaid(shortfall: 1))
    }

    func test_flagsAnOverpayment() throws {
        let payslip = makePayslip(hours: 14, amount: 350)
        let review = try makeUseCase(shifts: workedShifts, payslip: payslip).execute(payslipID: payslip.id)

        XCTAssertEqual(review.verdict, .overpaid(excess: 50))
    }

    func test_onlyCountsShiftsThatWereReallyWorked_notRosteredOnes() throws {
        let shifts = workedShifts + [Fixtures.rosteredShift(day: 4)]   // rostered but never worked
        let payslip = makePayslip(hours: 12, amount: 300)
        let review = try makeUseCase(shifts: shifts, payslip: payslip).execute(payslipID: payslip.id)

        XCTAssertEqual(review.hoursRecorded, 12)
        XCTAssertEqual(review.verdict, .paidCorrectly)
    }

    func test_onlyCountsShiftsAtTheWorkplaceOnThePayslip() throws {
        let shifts = workedShifts + [Fixtures.workedShift(at: Fixtures.warehouse, day: 2)]
        let payslip = makePayslip(hours: 12, amount: 300)
        let review = try makeUseCase(shifts: shifts, payslip: payslip).execute(payslipID: payslip.id)

        XCTAssertEqual(review.hoursRecorded, 12)
    }

    func test_onlyCountsShiftsInsideThePayPeriod() throws {
        let shifts = workedShifts + [Fixtures.workedShift(day: 9)]   // after the period ends
        let payslip = makePayslip(hours: 12, amount: 300)
        let review = try makeUseCase(shifts: shifts, payslip: payslip).execute(payslipID: payslip.id)

        XCTAssertEqual(review.hoursRecorded, 12)
    }

    func test_cannotCheckAPayslip_whenNoShiftsWereRecordedForThatPeriod() {
        let payslip = makePayslip(hours: 12, amount: 300)
        let useCase = makeUseCase(shifts: [], payslip: payslip)

        XCTAssertThrowsError(try useCase.execute(payslipID: payslip.id)) { error in
            XCTAssertEqual(error as? ReviewPayslipAgainstShiftsUseCase.Failure,
                           .noWorkedShiftsInPeriod(workplaceName: "Campus Café",
                                                   from: payslip.periodStart, to: payslip.periodEnd))
        }
    }

    func test_cannotCheckAPayslipThatWasNeverFiled() {
        let payslip = makePayslip(hours: 12, amount: 300)
        let useCase = makeUseCase(shifts: workedShifts, payslip: payslip)

        XCTAssertThrowsError(try useCase.execute(payslipID: UUID())) { error in
            XCTAssertEqual(error as? ReviewPayslipAgainstShiftsUseCase.Failure, .payslipNotFound)
        }
    }
}
