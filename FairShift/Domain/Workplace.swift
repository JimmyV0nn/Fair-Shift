import Foundation

// a place I work at. awardHourlyRate is what I should get paid per hour - every
// payslip gets checked against it.
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
