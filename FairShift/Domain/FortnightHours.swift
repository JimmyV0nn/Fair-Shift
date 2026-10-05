import Foundation

// the student-visa work limit is counted per fortnight, so everything here is
// built around a 14-day window that repeats from a start date the student picks.
// the 48-hour default is only a starting value - the student confirms the real
// figure for their own visa in Settings.
struct VisaWorkLimit: Equatable, Sendable {
    static let defaultHoursPerFortnight: Decimal = 48

    var hoursPerFortnight: Decimal
    var fortnightAnchor: Date

    func window(containing date: Date, calendar: Calendar = .current) -> FortnightWindow {
        let anchorDay = calendar.startOfDay(for: fortnightAnchor)
        let day = calendar.startOfDay(for: date)
        let daysSinceAnchor = calendar.dateComponents([.day], from: anchorDay, to: day).day ?? 0

        // floor division so dates before the anchor still land in a proper window
        let windowsSinceAnchor = Int((Double(daysSinceAnchor) / 14).rounded(.down))
        let start = calendar.date(byAdding: .day, value: windowsSinceAnchor * 14, to: anchorDay)!
        let end = calendar.date(byAdding: .day, value: 14, to: start)!
        return FortnightWindow(start: start, end: end)
    }
}

struct FortnightWindow: Equatable, Sendable {
    let start: Date
    let end: Date   // exclusive

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

struct FortnightHoursStatus: Equatable, Sendable {
    let window: FortnightWindow
    let limitHours: Decimal
    let hoursWorked: Decimal
    let hoursRostered: Decimal

    var hoursCommitted: Decimal { hoursWorked + hoursRostered }
    var hoursRemaining: Decimal { max(limitHours - hoursCommitted, 0) }
    var hoursOverLimit: Decimal { max(hoursCommitted - limitHours, 0) }
    var isOverLimit: Bool { hoursCommitted > limitHours }

    func daysLeft(from now: Date, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        return max(calendar.dateComponents([.day], from: today, to: window.end).day ?? 0, 0)
    }

    // adds up the paid hours of every shift in the window
    static func make(window: FortnightWindow, limit: Decimal, shifts: [WorkShift]) -> FortnightHoursStatus {
        let inWindow = shifts.filter { window.contains($0.startsAt) }
        let worked = inWindow.filter { $0.status == .worked }.reduce(Decimal(0)) { $0 + $1.paidHours }
        let rostered = inWindow.filter { $0.status == .rostered }.reduce(Decimal(0)) { $0 + $1.paidHours }
        return FortnightHoursStatus(window: window, limitHours: limit,
                                    hoursWorked: worked, hoursRostered: rostered)
    }
}

enum HoursFormat {
    // 22.5 -> "22.5", 48 -> "48"
    static func string(_ hours: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: hours)) ?? "\(hours)"
    }

    static func money(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        formatter.locale = Locale(identifier: "en_AU")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$\(amount)"
    }
}
