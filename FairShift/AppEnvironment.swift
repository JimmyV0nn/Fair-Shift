import Foundation
import CoreData

// where everything gets wired together. picks the real repositories once and builds
// the use cases from them - views and view models only talk to this.
final class AppEnvironment {
    let workplaces: WorkplaceRepository
    let shifts: ShiftRepository
    let payslips: PayslipRepository
    let workLimit: WorkLimitSettingsRepository
    let inbox = SharedPayslipInbox()
    let reloader: WidgetTimelineReloading

    init(workplaces: WorkplaceRepository,
         shifts: ShiftRepository,
         payslips: PayslipRepository,
         workLimit: WorkLimitSettingsRepository,
         reloader: WidgetTimelineReloading = SystemWidgetReloader()) {
        self.workplaces = workplaces
        self.shifts = shifts
        self.payslips = payslips
        self.workLimit = workLimit
        self.reloader = reloader
    }

    // MARK: use cases

    var rosterShift: RosterUpcomingShiftUseCase {
        RosterUpcomingShiftUseCase(workplaces: workplaces, shifts: shifts, workLimit: workLimit)
    }
    var recordWorkedShift: RecordWorkedShiftUseCase {
        RecordWorkedShiftUseCase(workplaces: workplaces, shifts: shifts, workLimit: workLimit)
    }
    var checkFortnightHours: CheckFortnightHoursUseCase {
        CheckFortnightHoursUseCase(workplaces: workplaces, shifts: shifts, workLimit: workLimit)
    }
    var recordPayslip: RecordPayslipUseCase {
        RecordPayslipUseCase(workplaces: workplaces, payslips: payslips)
    }
    var reviewPayslip: ReviewPayslipAgainstShiftsUseCase {
        ReviewPayslipAgainstShiftsUseCase(workplaces: workplaces, shifts: shifts, payslips: payslips)
    }

    var widgetPublisher: WidgetSnapshotPublisher {
        WidgetSnapshotPublisher(checkHours: checkFortnightHours, shifts: shifts,
                                workplaces: workplaces, reloader: reloader)
    }

    // MARK: factories

    static func live() -> AppEnvironment {
        make(persistence: PersistenceController())
    }

    // in-memory store so previews don't mess with real data
    static func preview() -> AppEnvironment {
        make(persistence: PersistenceController(inMemory: true),
             workLimit: UserDefaultsWorkLimitSettingsRepository(defaults: UserDefaults(suiteName: "fairshift.preview") ?? .standard))
    }

    private static func make(persistence: PersistenceController,
                             workLimit: WorkLimitSettingsRepository = UserDefaultsWorkLimitSettingsRepository()) -> AppEnvironment {
        let context = persistence.viewContext
        return AppEnvironment(workplaces: CoreDataWorkplaceRepository(context: context),
                              shifts: CoreDataShiftRepository(context: context),
                              payslips: CoreDataPayslipRepository(context: context),
                              workLimit: workLimit)
    }
}
