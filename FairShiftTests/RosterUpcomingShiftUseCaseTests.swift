import XCTest
@testable import FairShift

final class RosterUpcomingShiftUseCaseTests: XCTestCase {
    // "now" is the evening before the fortnight starts, so all the shifts below are in the future
    private let now = TestDates.at(day: -1, hour: 18)

    private func makeUseCase(shifts: [WorkShift] = [], limitHours: Decimal = 48)
        -> (RosterUpcomingShiftUseCase, InMemoryShiftRepository) {
        let shiftRepo = InMemoryShiftRepository(shifts)
        let useCase = RosterUpcomingShiftUseCase(
            workplaces: InMemoryWorkplaceRepository([Fixtures.cafe]),
            shifts: shiftRepo,
            workLimit: FixedWorkLimitSettings(hours: limitHours))
        return (useCase, shiftRepo)
    }

    // MARK: happy path

    func test_rostersAShift_whenItFitsInsideTheFortnightLimit() throws {
        let (useCase, shiftRepo) = makeUseCase()

        let shift = try useCase.execute(workplaceID: Fixtures.cafe.id, startsAt: TestDates.at(day: 1, hour: 9),
                                        endsAt: TestDates.at(day: 1, hour: 15), unpaidBreakMinutes: 30, now: now)

        XCTAssertEqual(shift.status, .rostered)
        XCTAssertEqual(shift.paidHours, 5.5)
        XCTAssertEqual(try shiftRepo.shift(id: shift.id), shift)
    }

    // MARK: boundary

    func test_allowsAShiftThatBringsTheFortnightToExactlyTheVisaLimit() throws {
        // 7 shifts x 6h = 42h, plus a 6h one = exactly 48h
        let existing = (0..<7).map { Fixtures.workedShift(day: $0) }
        let (useCase, _) = makeUseCase(shifts: existing)

        XCTAssertNoThrow(try useCase.execute(workplaceID: Fixtures.cafe.id, startsAt: TestDates.at(day: 8, hour: 9),
                                             endsAt: TestDates.at(day: 8, hour: 15), unpaidBreakMinutes: 0, now: now))
    }

    // MARK: domain rule - the visa limit

    func test_refusesAShift_thatWouldPushTheFortnightOverTheVisaLimit() {
        // 8 shifts x 6h = 48h already used
        let existing = (0..<8).map { Fixtures.workedShift(day: $0) }
        let (useCase, shiftRepo) = makeUseCase(shifts: existing)
        let before = shiftRepo.stored.count

        XCTAssertThrowsError(try useCase.execute(workplaceID: Fixtures.cafe.id, startsAt: TestDates.at(day: 9, hour: 9),
                                                 endsAt: TestDates.at(day: 9, hour: 12), unpaidBreakMinutes: 0, now: now)) { error in
            XCTAssertEqual(error as? RosterUpcomingShiftUseCase.Failure,
                           .wouldExceedFortnightLimit(hoursOver: 3, limitHours: 48))
        }
        XCTAssertEqual(shiftRepo.stored.count, before, "a refused shift must not be saved")
    }

    func test_countsRosteredShiftsTowardsTheLimitToo() {
        let existing = (0..<8).map { Fixtures.rosteredShift(day: $0) }
        let (useCase, _) = makeUseCase(shifts: existing)

        XCTAssertThrowsError(try useCase.execute(workplaceID: Fixtures.cafe.id, startsAt: TestDates.at(day: 9, hour: 9),
                                                 endsAt: TestDates.at(day: 9, hour: 10), unpaidBreakMinutes: 0, now: now)) { error in
            XCTAssertEqual(error as? RosterUpcomingShiftUseCase.Failure,
                           .wouldExceedFortnightLimit(hoursOver: 1, limitHours: 48))
        }
    }

    // MARK: domain errors

    func test_refusesAShift_thatOverlapsAnotherShift() {
        let existing = Fixtures.rosteredShift(day: 1, from: 9, to: 15)
        let (useCase, _) = makeUseCase(shifts: [existing])

        XCTAssertThrowsError(try useCase.execute(workplaceID: Fixtures.cafe.id, startsAt: TestDates.at(day: 1, hour: 14),
                                                 endsAt: TestDates.at(day: 1, hour: 18), unpaidBreakMinutes: 0, now: now)) { error in
            XCTAssertEqual(error as? RosterUpcomingShiftUseCase.Failure,
                           .overlapsAnotherShift(startsAt: existing.startsAt, endsAt: existing.endsAt))
        }
    }

    func test_refusesAShift_thatFinishesBeforeItStarts() {
        let (useCase, _) = makeUseCase()

        XCTAssertThrowsError(try useCase.execute(workplaceID: Fixtures.cafe.id, startsAt: TestDates.at(day: 1, hour: 15),
                                                 endsAt: TestDates.at(day: 1, hour: 9), unpaidBreakMinutes: 0, now: now)) { error in
            XCTAssertEqual(error as? RosterUpcomingShiftUseCase.Failure, .shiftEndsBeforeItStarts)
        }
    }

    func test_refusesAShift_whoseUnpaidBreakCoversTheWholeShift() {
        let (useCase, _) = makeUseCase()

        XCTAssertThrowsError(try useCase.execute(workplaceID: Fixtures.cafe.id, startsAt: TestDates.at(day: 1, hour: 9),
                                                 endsAt: TestDates.at(day: 1, hour: 10), unpaidBreakMinutes: 60, now: now)) { error in
            XCTAssertEqual(error as? RosterUpcomingShiftUseCase.Failure, .breakLongerThanShift)
        }
    }

    func test_refusesAShift_thatHasAlreadyStarted() {
        let (useCase, _) = makeUseCase()

        XCTAssertThrowsError(try useCase.execute(workplaceID: Fixtures.cafe.id, startsAt: TestDates.at(day: -2, hour: 9),
                                                 endsAt: TestDates.at(day: -2, hour: 15), unpaidBreakMinutes: 0, now: now)) { error in
            XCTAssertEqual(error as? RosterUpcomingShiftUseCase.Failure, .shiftAlreadyStarted)
        }
    }

    func test_refusesAShift_atAWorkplaceThatDoesNotExist() {
        let (useCase, _) = makeUseCase()

        XCTAssertThrowsError(try useCase.execute(workplaceID: UUID(), startsAt: TestDates.at(day: 1, hour: 9),
                                                 endsAt: TestDates.at(day: 1, hour: 15), unpaidBreakMinutes: 0, now: now)) { error in
            XCTAssertEqual(error as? RosterUpcomingShiftUseCase.Failure, .workplaceNotFound)
        }
    }

    func test_everyFailureTellsTheStudentWhatToDoNext() {
        let failures: [RosterUpcomingShiftUseCase.Failure] = [
            .workplaceNotFound, .shiftEndsBeforeItStarts, .breakLongerThanShift, .shiftAlreadyStarted,
            .overlapsAnotherShift(startsAt: TestDates.at(day: 1), endsAt: TestDates.at(day: 1, hour: 15)),
            .wouldExceedFortnightLimit(hoursOver: 2, limitHours: 48)
        ]
        for failure in failures {
            let message = failure.errorDescription ?? ""
            XCTAssertFalse(message.isEmpty)
            XCTAssertTrue(message.contains(".") && message.count > 40, "\(failure) should read as a full sentence with a next step")
        }
    }
}
