import Foundation

// rostered = the boss has put me on it, worked = it actually happened
enum ShiftStatus: String, Codable, Sendable {
    case rostered
    case worked
}

struct WorkShift: Identifiable, Hashable, Sendable {
    let id: UUID
    var workplaceID: UUID
    var startsAt: Date
    var endsAt: Date
    var unpaidBreakMinutes: Int
    var status: ShiftStatus

    init(id: UUID = UUID(),
         workplaceID: UUID,
         startsAt: Date,
         endsAt: Date,
         unpaidBreakMinutes: Int = 0,
         status: ShiftStatus) {
        self.id = id
        self.workplaceID = workplaceID
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.unpaidBreakMinutes = unpaidBreakMinutes
        self.status = status
    }

    var lengthInMinutes: Int {
        Int((endsAt.timeIntervalSince(startsAt) / 60).rounded())
    }

    // time on the clock minus the unpaid break - this is what counts towards the
    // visa limit and what the employer should pay for
    var paidMinutes: Int { max(0, lengthInMinutes - unpaidBreakMinutes) }

    var paidHours: Decimal { Decimal(paidMinutes) / 60 }

    func overlaps(_ other: WorkShift) -> Bool {
        startsAt < other.endsAt && other.startsAt < endsAt
    }
}
