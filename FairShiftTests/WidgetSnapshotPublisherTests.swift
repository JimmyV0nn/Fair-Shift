import XCTest
@testable import FairShift

// the widget only shows what the app publishes, so these check that every change
// produces the right snapshot and asks WidgetKit to reload
final class WidgetSnapshotPublisherTests: XCTestCase {
    private let now = TestDates.at(day: 2, hour: 12)

    private func makePublisher(workplaces: [Workplace], shifts: [WorkShift],
                               reloader: RecordingWidgetReloader,
                               written: @escaping (WidgetSnapshot) -> Void) -> WidgetSnapshotPublisher {
        let workplaceRepo = InMemoryWorkplaceRepository(workplaces)
        let shiftRepo = InMemoryShiftRepository(shifts)
        let limit = FixedWorkLimitSettings()
        return WidgetSnapshotPublisher(
            checkHours: CheckFortnightHoursUseCase(workplaces: workplaceRepo, shifts: shiftRepo, workLimit: limit),
            shifts: shiftRepo, workplaces: workplaceRepo, reloader: reloader,
            write: { written($0) })
    }

    func test_publishesTheFortnightHoursAndNextShift_thenReloadsTheWidget() {
        let reloader = RecordingWidgetReloader()
        var snapshot: WidgetSnapshot?
        let publisher = makePublisher(
            workplaces: [Fixtures.cafe],
            shifts: [Fixtures.workedShift(day: 0, from: 9, to: 15, breakMinutes: 30),
                     Fixtures.rosteredShift(day: 4, from: 16, to: 22)],
            reloader: reloader, written: { snapshot = $0 })

        publisher.publish(now: now)

        XCTAssertEqual(snapshot?.isSetUp, true)
        XCTAssertEqual(snapshot?.hoursWorked, 5.5)
        XCTAssertEqual(snapshot?.hoursRostered, 6)
        XCTAssertEqual(snapshot?.hoursRemaining, 36.5)
        XCTAssertEqual(snapshot?.nextShift?.workplaceName, "Campus Café")
        XCTAssertEqual(reloader.reloadCount, 1)
    }

    func test_publishesAnOnboardingSnapshot_untilAWorkplaceExists() {
        let reloader = RecordingWidgetReloader()
        var snapshot: WidgetSnapshot?
        let publisher = makePublisher(workplaces: [], shifts: [], reloader: reloader, written: { snapshot = $0 })

        publisher.publish(now: now)

        XCTAssertEqual(snapshot?.isSetUp, false)
        XCTAssertEqual(reloader.reloadCount, 1, "the widget still reloads so it can show the set-up prompt")
    }

    func test_snapshotShowsAnOverLimitFortnight() {
        var snapshot: WidgetSnapshot?
        let publisher = makePublisher(
            workplaces: [Fixtures.cafe],
            shifts: (0..<9).map { Fixtures.workedShift(day: $0) },   // 54h
            reloader: RecordingWidgetReloader(), written: { snapshot = $0 })

        publisher.publish(now: now)

        XCTAssertEqual(snapshot?.isOverLimit, true)
        XCTAssertEqual(snapshot?.hoursRemaining, 0)
    }
}
