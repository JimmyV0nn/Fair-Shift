import Foundation

// everything the widget needs, flattened into plain values. the app writes this
// after every change to shifts/workplaces, the widget only ever reads it - so the
// widget never has to open Core Data.
struct WidgetSnapshot: Codable, Equatable {
    struct NextShift: Codable, Equatable {
        var workplaceName: String
        var startsAt: Date
        var endsAt: Date
    }

    var isSetUp: Bool
    var hoursWorked: Double
    var hoursRostered: Double
    var limitHours: Double
    var windowStart: Date
    var windowEnd: Date
    var nextShift: NextShift?
    var generatedAt: Date

    var hoursCommitted: Double { hoursWorked + hoursRostered }
    var hoursRemaining: Double { max(limitHours - hoursCommitted, 0) }
    var isOverLimit: Bool { hoursCommitted > limitHours }

    static func notSetUp(now: Date = Date()) -> WidgetSnapshot {
        WidgetSnapshot(isSetUp: false, hoursWorked: 0, hoursRostered: 0, limitHours: 48,
                       windowStart: now, windowEnd: now, nextShift: nil, generatedAt: now)
    }

    // placeholder content for the widget gallery
    static let preview = WidgetSnapshot(
        isSetUp: true, hoursWorked: 22.5, hoursRostered: 12, limitHours: 48,
        windowStart: Date(), windowEnd: Date().addingTimeInterval(7 * 86_400),
        nextShift: NextShift(workplaceName: "Campus Café",
                             startsAt: Date().addingTimeInterval(3 * 3_600),
                             endsAt: Date().addingTimeInterval(8 * 3_600)),
        generatedAt: Date())
}

enum WidgetSnapshotStore {
    private static let fileName = "widget-snapshot.json"

    private static var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(fileName)
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: WidgetSnapshot) throws {
        guard let url = fileURL else { return }
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }
}
