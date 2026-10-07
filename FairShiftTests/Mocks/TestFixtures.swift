import Foundation
@testable import FairShift

// fixed dates so tests don't depend on what day they run. the first fortnight is
// Mon 6 Jan 2025 up to (not including) Mon 20 Jan 2025.
enum TestDates {
    static let fortnightStart: Date = {
        var parts = DateComponents()
        parts.year = 2025; parts.month = 1; parts.day = 6
        return Calendar.current.date(from: parts)!
    }()

    // `day` days after the fortnight start, at `hour`:00
    static func at(day: Int, hour: Int = 9) -> Date {
        let date = Calendar.current.date(byAdding: .day, value: day, to: fortnightStart)!
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
    }
}

enum Fixtures {
    static let cafe = Workplace(name: "Campus Café", awardHourlyRate: 25)
    static let warehouse = Workplace(name: "Riverside Warehouse", awardHourlyRate: 30)

    // by default a 9-3 shift (6h), minus whatever unpaid break you pass in
    static func workedShift(at workplace: Workplace = cafe, day: Int, from: Int = 9, to: Int = 15,
                            breakMinutes: Int = 0) -> WorkShift {
        WorkShift(workplaceID: workplace.id, startsAt: TestDates.at(day: day, hour: from),
                  endsAt: TestDates.at(day: day, hour: to), unpaidBreakMinutes: breakMinutes, status: .worked)
    }

    static func rosteredShift(at workplace: Workplace = cafe, day: Int, from: Int = 9, to: Int = 15,
                              breakMinutes: Int = 0) -> WorkShift {
        WorkShift(workplaceID: workplace.id, startsAt: TestDates.at(day: day, hour: from),
                  endsAt: TestDates.at(day: day, hour: to), unpaidBreakMinutes: breakMinutes, status: .rostered)
    }
}
