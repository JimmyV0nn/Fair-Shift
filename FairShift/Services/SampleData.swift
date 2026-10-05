import Foundation

// a believable week of shifts and one payslip, so the dashboard, widget and pay
// check can be tried straight away. it goes through the same use cases / repositories
// as real data, and the payslip is deliberately short-paid so the check has something
// to find.
enum SampleData {
    static func load(into environment: AppEnvironment, now: Date = Date()) throws {
        let calendar = Calendar.current
        let cafe = Workplace(name: "Campus Café", awardHourlyRate: 25.41)
        try environment.workplaces.save(cafe)

        // start the fortnight six days ago so the sample shifts below always fall inside it
        let fortnightStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
        environment.workLimit.save(VisaWorkLimit(hoursPerFortnight: VisaWorkLimit.defaultHoursPerFortnight,
                                                 fortnightAnchor: fortnightStart))

        func at(daysFromNow days: Int, hour: Int, minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now))!
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
        }

        // shifts that already happened
        let worked: [(Int, Int, Int)] = [(-6, 9, 15), (-4, 16, 22), (-3, 16, 22), (-1, 9, 14)]
        for (day, from, to) in worked {
            let shift = WorkShift(workplaceID: cafe.id, startsAt: at(daysFromNow: day, hour: from),
                                  endsAt: at(daysFromNow: day, hour: to), unpaidBreakMinutes: 30, status: .worked)
            try environment.shifts.save(shift)
        }

        // upcoming shifts
        for (day, from, to) in [(1, 16, 22), (3, 9, 15)] {
            let shift = WorkShift(workplaceID: cafe.id, startsAt: at(daysFromNow: day, hour: from),
                                  endsAt: at(daysFromNow: day, hour: to), unpaidBreakMinutes: 30, status: .rostered)
            try environment.shifts.save(shift)
        }

        // a payslip covering the worked shifts that pays one hour less than was worked
        let paidHours: Decimal = 20.5
        let payslip = Payslip(workplaceID: cafe.id,
                              periodStart: calendar.startOfDay(for: at(daysFromNow: -7, hour: 0)),
                              periodEnd: calendar.startOfDay(for: at(daysFromNow: 0, hour: 0)),
                              hoursPaid: paidHours, amountPaid: paidHours * 25.41)
        try environment.payslips.save(payslip)
    }
}
