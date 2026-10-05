import CoreData

// the Core Data classes. they stay inside the persistence layer - the rest of the
// app works with the plain Workplace / WorkShift / Payslip structs and these
// extensions do the translating in both directions.

@objc(WorkplaceEntity)
final class WorkplaceEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var awardHourlyRate: NSDecimalNumber
    @NSManaged var shifts: Set<WorkShiftEntity>?
    @NSManaged var payslips: Set<PayslipEntity>?

    var domain: Workplace {
        Workplace(id: id, name: name, awardHourlyRate: awardHourlyRate as Decimal)
    }

    func apply(_ workplace: Workplace) {
        id = workplace.id
        name = workplace.name
        awardHourlyRate = workplace.awardHourlyRate as NSDecimalNumber
    }
}

@objc(WorkShiftEntity)
final class WorkShiftEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var startsAt: Date
    @NSManaged var endsAt: Date
    @NSManaged var unpaidBreakMinutes: Int16
    @NSManaged var statusRaw: String
    @NSManaged var workplace: WorkplaceEntity?

    var domain: WorkShift? {
        guard let workplace, let status = ShiftStatus(rawValue: statusRaw) else { return nil }
        return WorkShift(id: id, workplaceID: workplace.id, startsAt: startsAt, endsAt: endsAt,
                         unpaidBreakMinutes: Int(unpaidBreakMinutes), status: status)
    }

    func apply(_ shift: WorkShift, workplace: WorkplaceEntity) {
        id = shift.id
        startsAt = shift.startsAt
        endsAt = shift.endsAt
        unpaidBreakMinutes = Int16(shift.unpaidBreakMinutes)
        statusRaw = shift.status.rawValue
        self.workplace = workplace
    }
}

@objc(PayslipEntity)
final class PayslipEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var periodStart: Date
    @NSManaged var periodEnd: Date
    @NSManaged var hoursPaid: NSDecimalNumber
    @NSManaged var amountPaid: NSDecimalNumber
    @NSManaged var attachmentFileName: String?
    @NSManaged var workplace: WorkplaceEntity?

    var domain: Payslip? {
        guard let workplace else { return nil }
        return Payslip(id: id, workplaceID: workplace.id, periodStart: periodStart, periodEnd: periodEnd,
                       hoursPaid: hoursPaid as Decimal, amountPaid: amountPaid as Decimal,
                       attachmentFileName: attachmentFileName)
    }

    func apply(_ payslip: Payslip, workplace: WorkplaceEntity) {
        id = payslip.id
        periodStart = payslip.periodStart
        periodEnd = payslip.periodEnd
        hoursPaid = payslip.hoursPaid as NSDecimalNumber
        amountPaid = payslip.amountPaid as NSDecimalNumber
        attachmentFileName = payslip.attachmentFileName
        self.workplace = workplace
    }
}
