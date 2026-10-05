import XCTest
@testable import FairShift

final class RecordWorkedShiftUseCaseTests: XCTestCase {
    // the middle of the first fortnight - earlier shifts are over, later ones haven't happened
    private let now = TestDates.at(day: 5, hour: 20)

    private func makeUseCase(shifts: [WorkShift] = [], limitHours: Decimal = 48)
        -> (RecordWorkedShiftUseCase, InMemoryShiftRepository) {
        let repo = InMemoryShiftRepository(shifts)
        let useCase = RecordWorkedShiftUseCase(
            workplaces: InMemoryWorkplaceRepository([Fixtures.cafe]),
            shifts: repo,
            workLimit: FixedWorkLimitSettings(hours: limitHours))
        return (useCase, repo)
    }

    func test_turnsARosteredShiftIntoAWorkedShift_usingTheRealFinishTime() throws {
        let rostered = Fixtures.rosteredShift(day: 3, from: 9, to: 15)
        let (useCase, repo) = makeUseCase(shifts: [rostered])

        // the shift actually ran an hour late
        let outcome = try useCase.execute(rosteredShiftID: rostered.id, workplaceID: Fixtures.cafe.id,
                                          startsAt: rostered.startsAt, endsAt: TestDates.at(day: 3, hour: 16),
                                          unpaidBreakMinutes: 0, now: now)

        XCTAssertEqual(outcome.shift.id, rostered.id, "the rostered shift is updated, not duplicated")
        XCTAssertEqual(outcome.shift.status, .worked)
        XCTAssertEqual(outcome.shift.paidHours, 7)
        XCTAssertEqual(repo.stored.count, 1)
    }

    func test_logsAShiftThatWasNeverOnTheRoster() throws {
        let (useCase, repo) = makeUseCase()

        let outcome = try useCase.execute(workplaceID: Fixtures.cafe.id, startsAt: TestDates.at(day: 2, hour: 9),
                                          endsAt: TestDates.at(day: 2, hour: 13), unpaidBreakMinutes: 0, now: now)

        XCTAssertEqual(outcome.fortnight.hoursWorked, 4)
        XCTAssertEqual(repo.stored.count, 1)
    }

    // the record has to be truthful even if it shows a breach
    func test_recordsTheShiftEvenWhenItPutsTheStudentOverTheVisaLimit_andReportsIt() throws {
        // 48h already worked, on every day except the one being recorded
        let existing = [0, 1, 2, 3, 4, 6, 7, 8].map { Fixtures.workedShift(day: $0) }
        let (useCase, repo) = makeUseCase(shifts: existing)

        let outcome = try useCase.execute(workplaceID: Fixtures.cafe.id, startsAt: TestDates.at(day: 5, hour: 9),
                                          endsAt: TestDates.at(day: 5, hour: 12), unpaidBreakMinutes: 0, now: now)

        XCTAssertTrue(outcome.fortnight.isOverLimit)
        XCTAssertEqual(outcome.fortnight.hoursOverLimit, 3)
        XCTAssertEqual(repo.stored.count, 9)
    }

    func test_refusesToRecordAShiftThatHasNotFinishedYet() {
        let (useCase, _) = makeUseCase()

        XCTAssertThrowsError(try useCase.execute(workplaceID: Fixtures.cafe.id, startsAt: TestDates.at(day: 5, hour: 18),
                                                 endsAt: TestDates.at(day: 5, hour: 23), unpaidBreakMinutes: 0, now: now)) { error in
            XCTAssertEqual(error as? RecordWorkedShiftUseCase.Failure, .shiftNotFinishedYet)
        }
    }

    func test_refusesToRecordTheSameRosteredShiftTwice() throws {
        let rostered = Fixtures.rosteredShift(day: 3)
        let (useCase, _) = makeUseCase(shifts: [rostered])
        try useCase.execute(rosteredShiftID: rostered.id, workplaceID: Fixtures.cafe.id, startsAt: rostered.startsAt,
                            endsAt: rostered.endsAt, unpaidBreakMinutes: 0, now: now)

        XCTAssertThrowsError(try useCase.execute(rosteredShiftID: rostered.id, workplaceID: Fixtures.cafe.id,
                                                 startsAt: rostered.startsAt, endsAt: rostered.endsAt,
                                                 unpaidBreakMinutes: 0, now: now)) { error in
            XCTAssertEqual(error as? RecordWorkedShiftUseCase.Failure, .shiftAlreadyRecorded)
        }
    }

    func test_refusesToRecordAShiftThatOverlapsAnotherWorkedShift() {
        let worked = Fixtures.workedShift(day: 2, from: 9, to: 15)
        let (useCase, _) = makeUseCase(shifts: [worked])

        XCTAssertThrowsError(try useCase.execute(workplaceID: Fixtures.cafe.id, startsAt: TestDates.at(day: 2, hour: 12),
                                                 endsAt: TestDates.at(day: 2, hour: 18), unpaidBreakMinutes: 0, now: now)) { error in
            XCTAssertEqual(error as? RecordWorkedShiftUseCase.Failure,
                           .overlapsAnotherShift(startsAt: worked.startsAt, endsAt: worked.endsAt))
        }
    }

    func test_refusesToRecordARosteredShiftThatNoLongerExists() {
        let (useCase, _) = makeUseCase()

        XCTAssertThrowsError(try useCase.execute(rosteredShiftID: UUID(), workplaceID: Fixtures.cafe.id,
                                                 startsAt: TestDates.at(day: 2, hour: 9), endsAt: TestDates.at(day: 2, hour: 13),
                                                 unpaidBreakMinutes: 0, now: now)) { error in
            XCTAssertEqual(error as? RecordWorkedShiftUseCase.Failure, .rosteredShiftNotFound)
        }
    }
}
