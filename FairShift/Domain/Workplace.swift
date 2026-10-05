import Foundation

// somewhere the student is employed. awardHourlyRate is what they should be paid
// per hour - it's the number every payslip gets checked against.
struct Workplace: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var awardHourlyRate: Decimal

    init(id: UUID = UUID(), name: String, awardHourlyRate: Decimal) {
        self.id = id
        self.name = name
        self.awardHourlyRate = awardHourlyRate
    }
}
