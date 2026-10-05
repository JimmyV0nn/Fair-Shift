import XCTest
@testable import FairShift

final class RecordPayslipUseCaseTests: XCTestCase {
    private func makeUseCase(payslips: [Payslip] = []) -> (RecordPayslipUseCase, InMemoryPayslipRepository) {
        let repo = InMemoryPayslipRepository(payslips)
        return (RecordPayslipUseCase(workplaces: InMemoryWorkplaceRepository([Fixtures.cafe]), payslips: repo), repo)
    }

    func test_filesAPayslipAgainstItsPayPeriod() throws {
        let (useCase, repo) = makeUseCase()

        let payslip = try useCase.execute(workplaceID: Fixtures.cafe.id, periodStart: TestDates.at(day: 0),
                                          periodEnd: TestDates.at(day: 13), hoursPaid: 38, amountPaid: 950,
                                          attachmentFileName: "payslip.pdf")

        XCTAssertEqual(payslip.hoursPaid, 38)
        XCTAssertEqual(payslip.attachmentFileName, "payslip.pdf")
        XCTAssertEqual(try repo.payslip(id: payslip.id), payslip)
    }

    func test_acceptsAPayPeriodOfExactlyOneDay_andOfExactlyThirtyOneDays() throws {
        let (useCase, _) = makeUseCase()

        XCTAssertNoThrow(try useCase.execute(workplaceID: Fixtures.cafe.id, periodStart: TestDates.at(day: 0),
                                             periodEnd: TestDates.at(day: 0), hoursPaid: 5, amountPaid: 125))
        XCTAssertNoThrow(try useCase.execute(workplaceID: Fixtures.cafe.id, periodStart: TestDates.at(day: 1),
                                             periodEnd: TestDates.at(day: 31), hoursPaid: 100, amountPaid: 2500))
    }

    func test_refusesASecondPayslipThatOverlapsAnAlreadyFiledPayPeriod() throws {
        let (useCase, repo) = makeUseCase()
        try useCase.execute(workplaceID: Fixtures.cafe.id, periodStart: TestDates.at(day: 0),
                            periodEnd: TestDates.at(day: 13), hoursPaid: 38, amountPaid: 950)

        XCTAssertThrowsError(try useCase.execute(workplaceID: Fixtures.cafe.id, periodStart: TestDates.at(day: 10),
                                                 periodEnd: TestDates.at(day: 23), hoursPaid: 20, amountPaid: 500)) { error in
            XCTAssertEqual(error as? RecordPayslipUseCase.Failure,
                           .payslipAlreadyFiledForPeriod(workplaceName: "Campus Café"))
        }
        XCTAssertEqual(repo.stored.count, 1)
    }

    func test_refusesAPayPeriodThatEndsBeforeItStarts() {
        let (useCase, _) = makeUseCase()

        XCTAssertThrowsError(try useCase.execute(workplaceID: Fixtures.cafe.id, periodStart: TestDates.at(day: 13),
                                                 periodEnd: TestDates.at(day: 0), hoursPaid: 38, amountPaid: 950)) { error in
            XCTAssertEqual(error as? RecordPayslipUseCase.Failure, .periodEndsBeforeItStarts)
        }
    }

    func test_refusesAPayPeriodLongerThanAnyRealPayCycle() {
        let (useCase, _) = makeUseCase()

        XCTAssertThrowsError(try useCase.execute(workplaceID: Fixtures.cafe.id, periodStart: TestDates.at(day: 0),
                                                 periodEnd: TestDates.at(day: 40), hoursPaid: 38, amountPaid: 950)) { error in
            XCTAssertEqual(error as? RecordPayslipUseCase.Failure, .periodTooLong(maxDays: 31))
        }
    }

    func test_refusesAPayslipWithNoHoursOrNoPay() {
        let (useCase, _) = makeUseCase()

        XCTAssertThrowsError(try useCase.execute(workplaceID: Fixtures.cafe.id, periodStart: TestDates.at(day: 0),
                                                 periodEnd: TestDates.at(day: 13), hoursPaid: 0, amountPaid: 950)) { error in
            XCTAssertEqual(error as? RecordPayslipUseCase.Failure, .hoursNotPositive)
        }
        XCTAssertThrowsError(try useCase.execute(workplaceID: Fixtures.cafe.id, periodStart: TestDates.at(day: 0),
                                                 periodEnd: TestDates.at(day: 13), hoursPaid: 38, amountPaid: 0)) { error in
            XCTAssertEqual(error as? RecordPayslipUseCase.Failure, .amountNotPositive)
        }
    }

    func test_refusesAPayslipFromAnUnknownWorkplace() {
        let (useCase, _) = makeUseCase()

        XCTAssertThrowsError(try useCase.execute(workplaceID: UUID(), periodStart: TestDates.at(day: 0),
                                                 periodEnd: TestDates.at(day: 13), hoursPaid: 38, amountPaid: 950)) { error in
            XCTAssertEqual(error as? RecordPayslipUseCase.Failure, .workplaceNotFound)
        }
    }
}
