import XCTest
@testable import FairShift

// the one test that touches the real App Group folder: it is the hand-off point
// between the share extension and the app, so it has to work on the real filesystem
final class SharedPayslipInboxTests: XCTestCase {
    private let inbox = SharedPayslipInbox()
    private var tempFile: URL!

    override func setUpWithError() throws {
        try XCTSkipIf(AppGroup.containerURL == nil, "App Group container isn't available in this build")
        tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("payslip-\(UUID().uuidString).pdf")
        try Data("fake payslip".utf8).write(to: tempFile)
        inbox.pendingItems().forEach { inbox.discard($0) }
    }

    override func tearDown() {
        inbox.pendingItems().forEach { inbox.discard($0) }
        try? FileManager.default.removeItem(at: tempFile)
    }

    func test_aPayslipSharedFromAnotherApp_waitsInTheInboxWithItsNote() throws {
        try inbox.receive(fileAt: tempFile, note: "Campus Café, fortnight ending 12 Oct")

        let pending = inbox.pendingItems()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.note, "Campus Café, fortnight ending 12 Oct")
        XCTAssertNotNil(pending.first.flatMap { inbox.url(for: $0) }, "the shared file itself is kept")
    }

    func test_filingASharedPayslip_movesItsFileFromTheInboxToTheLibrary() throws {
        let item = try inbox.receive(fileAt: tempFile, note: "")

        let storedName = try inbox.adopt(item)

        XCTAssertTrue(inbox.pendingItems().isEmpty)
        XCTAssertNotNil(inbox.libraryURL(forFileNamed: storedName))
    }

    func test_discardingASharedPayslip_removesItFromTheInbox() throws {
        let item = try inbox.receive(fileAt: tempFile, note: "")

        inbox.discard(item)

        XCTAssertTrue(inbox.pendingItems().isEmpty)
        XCTAssertNil(inbox.url(for: item))
    }
}
