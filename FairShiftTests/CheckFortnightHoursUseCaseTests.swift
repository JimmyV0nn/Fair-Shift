import XCTest
@testable import FairShift

final class CheckFortnightHoursUseCaseTests: XCTestCase {
    private func makeUseCase(shifts: [WorkShift], workplaces: [Workplace] = [Fixtures.cafe], limitHours: Decimal = 48)
        -> CheckFortnightHoursUseCase {
        CheckFortnightHoursUseCase(workplaces: InMemoryWorkplaceRepository(workplaces),
                                   shifts: InMemoryShiftRepository(shifts),
                                   workLimit: FixedWorkLimitSettings(hours: limitHours))
    }

    func test_countsWorkedAndRosteredHoursSeparately() throws {
        let useCase = makeUseCase(shifts: [
            Fixtures.workedShift(day: 0, from: 9, to: 15, breakMinutes: 30),   // 5.5h
            Fixtures.workedShift(day: 1, from: 9, to: 13),                      // 4h
            Fixtures.rosteredShift(day: 8, from: 9, to: 17)                     // 8h
        ])

        let status = try useCase.execute(now: TestDates.at(day: 2))

        XCTAssertEqual(status.hoursWorked, 9.5)
        XCTAssertEqual(status.hoursRostered, 8)
        XCTAssertEqual(status.hoursRemaining, 30.5)
        XCTAssertFalse(status.isOverLimit)
    }

    func test_ignoresShiftsFromOtherFortnights() throws {
        let useCase = makeUseCase(shifts: [
            Fixtures.workedShift(day: -1),    // last fortnight
            Fixtures.workedShift(day: 3),     // this one
            Fixtures.workedShift(day: 14)     // the next
        ])

        let status = try useCase.execute(now: TestDates.at(day: 5))

        XCTAssertEqual(status.hoursWorked, 6)
    }

    func test_aShiftOnTheLastDayOfTheFortnightStillCounts_andTheNextDayStartsAFreshCount() throws {
        let useCase = makeUseCase(shifts: [Fixtures.workedShift(day: 13)])

        XCTAssertEqual(try useCase.execute(now: TestDates.at(day: 13, hour: 20)).hoursWorked, 6)
        XCTAssertEqual(try useCase.execute(now: TestDates.at(day: 14, hour: 8)).hoursWorked, 0)
    }

    func test_flagsTheFortnightAsOverTheLimit() throws {
        let useCase = makeUseCase(shifts: (0..<9).map { Fixtures.workedShift(day: $0) })   // 54h

        let status = try useCase.execute(now: TestDates.at(day: 10))

        XCTAssertTrue(status.isOverLimit)
        XCTAssertEqual(status.hoursOverLimit, 6)
        XCTAssertEqual(status.hoursRemaining, 0)
    }

    func test_failsUntilTheStudentHasAddedAWorkplace() {
        let useCase = makeUseCase(shifts: [], workplaces: [])

        XCTAssertThrowsError(try useCase.execute(now: TestDates.at(day: 1))) { error in
            XCTAssertEqual(error as? CheckFortnightHoursUseCase.Failure, .noWorkplaceSetUp)
        }
    }

    func test_fortnightsKeepRepeatingFromTheAnchor_includingBeforeIt() {
        let limit = VisaWorkLimit(hoursPerFortnight: 48, fortnightAnchor: TestDates.fortnightStart)

        let before = limit.window(containing: TestDates.at(day: -3))
        XCTAssertEqual(before.start, TestDates.at(day: -14, hour: 0))
        XCTAssertEqual(before.end, TestDates.at(day: 0, hour: 0))

        let later = limit.window(containing: TestDates.at(day: 30))
        XCTAssertEqual(later.start, TestDates.at(day: 28, hour: 0))
    }
}
