import SwiftUI

struct DashboardView: View {
    let environment: AppEnvironment
    @State private var viewModel: DashboardViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = State(initialValue: DashboardViewModel(environment: environment))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.pendingPayslipCount > 0 {
                    pendingPayslipsBanner
                }

                if viewModel.needsFirstWorkplace {
                    firstWorkplaceCard
                } else if let status = viewModel.status {
                    hoursCard(status)
                    nextShiftCard
                } else if let message = viewModel.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else {
                    ProgressView().padding(.top, 60)
                }
            }
            .padding()
        }
        .navigationTitle("This Fortnight")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView(environment: environment)
                } label: {
                    Label("Visa limit & demo data", systemImage: "gearshape")
                }
            }
        }
        .onAppear { viewModel.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refresh() }
        }
    }

    private func hoursCard(_ status: FortnightHoursStatus) -> some View {
        let remaining = NSDecimalNumber(decimal: status.hoursRemaining).doubleValue
        let limit = NSDecimalNumber(decimal: status.limitHours).doubleValue

        // the ring shows the hours still available, so it empties as the fortnight fills up
        return VStack(spacing: 14) {
            Gauge(value: remaining, in: 0...max(limit, 1)) {
                Text("left")
            } currentValueLabel: {
                Text(HoursFormat.string(status.hoursRemaining))
                    .font(.title.bold())
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .scaleEffect(2.2)
            .tint(status.isOverLimit ? .red : .blue)
            .frame(height: 140)

            Text(status.isOverLimit
                 ? "\(HoursFormat.string(status.hoursOverLimit)) hours over your \(HoursFormat.string(status.limitHours))-hour limit"
                 : "\(HoursFormat.string(status.hoursCommitted)) of \(HoursFormat.string(status.limitHours)) hours used or rostered")
                .font(.headline)
                .foregroundStyle(status.isOverLimit ? .red : .primary)

            HStack {
                stat("Worked", HoursFormat.string(status.hoursWorked))
                Divider().frame(height: 30)
                stat("Rostered", HoursFormat.string(status.hoursRostered))
                Divider().frame(height: 30)
                stat("Days left", "\(status.daysLeft(from: Date()))")
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var nextShiftCard: some View {
        if let next = viewModel.nextShift {
            HStack(spacing: 14) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.title2).foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next shift").font(.subheadline).foregroundStyle(.secondary)
                    Text(next.workplaceName).font(.headline)
                    Text("\(DateText.dayAndTime(next.startsAt)) – \(DateText.time(next.endsAt))")
                        .font(.subheadline)
                }
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        } else {
            Text("Nothing rostered yet. Add your upcoming shifts on the Roster tab and FairShift will warn you before you go over your limit.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var pendingPayslipsBanner: some View {
        Label("\(viewModel.pendingPayslipCount) payslip\(viewModel.pendingPayslipCount == 1 ? "" : "s") shared from another app — open the Payslips tab to add the hours and pay.",
              systemImage: "tray.and.arrow.down.fill")
            .font(.subheadline)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private var firstWorkplaceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start with where you work").font(.title3.bold())
            Text("Add your workplace and hourly pay rate, then log your shifts. FairShift counts your hours against your visa limit and checks each payslip against the hours you worked.")
                .font(.subheadline).foregroundStyle(.secondary)
            NavigationLink {
                WorkplacesView(environment: environment)
            } label: {
                Text("Add my workplace").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            NavigationLink {
                SettingsView(environment: environment)
            } label: {
                Text("Or load sample shifts to try it").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    NavigationStack { DashboardView(environment: .preview()) }
}
