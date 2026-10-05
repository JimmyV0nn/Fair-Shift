# FairShift

FairShift helps an international student on a work-limited visa answer two questions:

1. **"How many hours am I still allowed to work this fortnight?"**
2. **"Did my employer pay me for every hour I worked?"**

It is an iOS app (SwiftUI, Core Data, WidgetKit, Share Extension) built for Assessment 3.

## Domain context

**Primary stakeholder:** an international student working casual shifts (café, retail, warehouse) on a student visa that caps work hours per fortnight.

Two things go wrong for this person, both because the information is scattered:

- **The visa limit is counted per fortnight, but rosters are set week to week.** Shifts get swapped and extended at short notice, and nobody is adding them up. Going over the limit can put the visa at risk.
- **Underpayment is hard to notice.** Payslips arrive as PDFs or screenshots, hours are summarised, and the student has no record of their own to compare against.

FairShift keeps the student's own shift log, counts it against the visa limit as shifts are rostered, and checks every payslip against the hours actually worked. The evidence for the problem, and the stakeholder research, are in the Required Document (PDF).

> The 48-hour fortnightly limit used as the default is a common student-visa condition, but the exact limit is on each student's visa grant. It is editable in the app (Settings).

## What the app does

| Screen | Purpose |
| --- | --- |
| **This Fortnight** | Hours worked + rostered against the limit, days left, next shift |
| **Roster** | Roster upcoming shifts, record worked shifts, swipe to remove |
| **Shift editor** | One form for "roster a shift" and "record a worked shift" |
| **Payslips** | Filed payslips with a pay-check verdict; payslips shared in from other apps |
| **File a payslip** | Enter the hours and pay printed on a payslip |
| **Pay check** | Hours/pay comparison, and what to do if underpaid |
| **Workplaces** | Employers and their hourly pay rate |
| **Visa limit** | Hours per fortnight, fortnight start date, sample data for demos |

## Architecture

```
Views  ->  ViewModels  ->  Use Cases  ->  Repository protocols  ->  Core Data
                                              ^
                                    mock repositories in tests
```

- **Domain models** use the student's vocabulary: `Workplace`, `WorkShift` (rostered / worked), `Payslip`, `VisaWorkLimit`, `FortnightWindow`, `FortnightHoursStatus`, `PayslipReview`.
- **Use cases** (each enforces a business rule and has its own typed error enum with messages written for the student):
  - `RosterUpcomingShiftUseCase` - refuses a shift that would push the fortnight over the visa limit, overlaps another shift, or has already started.
  - `RecordWorkedShiftUseCase` - records what really happened; never refuses for the visa limit (the record must be truthful) but reports the breach.
  - `CheckFortnightHoursUseCase` - hours worked and rostered in the current fortnight.
  - `RecordPayslipUseCase` - one payslip per workplace per pay period.
  - `ReviewPayslipAgainstShiftsUseCase` - compares what was paid with worked hours x pay rate.
- **Repositories** are protocols (`WorkplaceRepository`, `ShiftRepository`, `PayslipRepository`, `WorkLimitSettingsRepository`); `Repositories/CoreData` holds the only code that touches Core Data. ViewModels and Views never import it.
- **Composition root:** `AppEnvironment` builds repositories and use cases once.

### Data flow of the primary use case (rostering a shift)

`ShiftEditorView` -> `ShiftEditorViewModel.save()` -> `RosterUpcomingShiftUseCase.execute()` (checks overlap, fortnight total) -> `ShiftRepository.save()` -> Core Data store in the App Group container -> `WidgetSnapshotPublisher.publish()` writes `widget-snapshot.json` to the App Group and calls `WidgetCenter.reloadAllTimelines()` -> widget redraws.

## Database: Core Data

Chosen over CloudKit because the data is **private, personal and must work offline**: a student's shifts, pay rates and payslips are sensitive, entered at work often without signal, and there is only one user and one device in the target scenario. Core Data keeps everything on the phone with no account or sync setup. Moving to CloudKit later only means swapping the repository implementations, because nothing above the repository layer knows which store is used.

Schema (three related entities):

- `WorkplaceEntity` 1 - * `WorkShiftEntity`
- `WorkplaceEntity` 1 - * `PayslipEntity`

Queries with predicates: shifts starting in a date range, **worked** shifts at one workplace in a pay period (`workplace.id == %@ AND statusRaw == "worked" AND startsAt >= %@ AND startsAt < %@`), and the next rostered shift (`statusRaw == "rostered" AND startsAt > now`).

## System extensions

### 1. WidgetKit widget - "Fortnight hours"
- **Scenario:** a student on a shift break wants to know whether they can say yes to an extra shift. A Lock Screen widget answers "hours left this fortnight" without unlocking the phone or opening the app.
- Families: Small, Medium (Home Screen); Circular, Rectangular (Lock Screen).
- Reads `widget-snapshot.json` from the App Group container. The app rewrites it and calls `WidgetCenter.shared.reloadAllTimelines()` after every shift, workplace or visa-limit change, and on launch.

### 2. Share Extension - "Save to FairShift"
- **Scenario:** payslips arrive as an email PDF or a screenshot from the employer's app. Sharing it to FairShift saves a copy straight into the app, so the student files it in seconds instead of hunting for it later.
- Accepts PDFs and images, copies them into the App Group inbox, and always dismisses (`completeRequest` / `cancelRequest`). The main app lists them under **Payslips -> Shared from another app**; filing one runs `RecordPayslipUseCase` and moves the file into the permanent library.

**App Group identifier:** `group.au.edu.au.FairShift` (shared by the app, widget and share extension; see `Config/*.entitlements`).

## Testing

`FairShiftTests` has 40+ unit tests across all five use cases and the widget publisher. They use in-memory **mock repositories** (`FairShiftTests/Mocks`) - no Core Data - and cover happy paths, boundaries (a shift that lands exactly on the limit, a pay difference of 50 cents) and every domain error. Test names describe the scenario in the student's terms.

Run with Cmd+U in Xcode, or:

```
xcodebuild test -project FairShift.xcodeproj -scheme FairShift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Setup

1. Open `FairShift.xcodeproj` in Xcode 16 or later (iOS 17+ simulator).
2. Select the **FairShift** scheme and run (Cmd+R).
3. On a real device: set your own Team on all three targets (FairShift, FairShiftWidget, FairShiftShare) and enable the App Groups capability with `group.au.edu.au.FairShift` (or change the identifier in `Shared/AppGroup.swift` and the three `.entitlements` files).
4. To try everything quickly: open **This Fortnight -> gear icon -> Load sample shifts & payslip**. The Payslips tab then shows a payslip that is short by an hour.
5. To try the widget: long-press the Home Screen -> + -> FairShift. To try the Share Extension: open a PDF or image in Files/Photos -> Share -> **FairShift**, then open the app.

## Project layout

```
FairShift/          App target (Domain, UseCases, Repositories, Persistence, ViewModels, Views)
Shared/             Code used by the app, widget and share extension (App Group, snapshot, inbox)
FairShiftWidget/    WidgetKit extension
FairShiftShare/     Share extension
FairShiftTests/     Unit tests + mock repositories
Config/             Entitlements and extension Info.plists
```

## AI use and attribution

AI coding assistance (Claude, via Claude Code) was used while building this project. The specifics - what it did, what had to be corrected, and how the output was checked - are declared in the Required Document. No third-party libraries are used; the only dependencies are Apple frameworks (SwiftUI, Core Data, WidgetKit, UniformTypeIdentifiers).
