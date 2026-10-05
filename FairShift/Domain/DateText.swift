import Foundation

// short date strings used inside error messages, e.g. "Mon 6 Oct, 5:00 pm"
enum DateText {
    static func dayAndTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.dateFormat = "EEE d MMM, h:mm a"
        return formatter.string(from: date)
    }

    // "5:00 pm" - same 12-hour style as dayAndTime, so ranges don't mix formats
    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
