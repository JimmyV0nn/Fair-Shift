import SwiftUI

struct PayslipsView: View {
    let environment: AppEnvironment
    @State private var viewModel: PayslipsViewModel
    @State private var showingManualEntry = false
    @Environment(\.scenePhase) private var scenePhase

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = State(initialValue: PayslipsViewModel(environment: environment))
    }

    var body: some View {
        List {
            if !viewModel.sharedItems.isEmpty {
                Section("Shared from another app — add the numbers") {
                    ForEach(viewModel.sharedItems) { item in
                        NavigationLink {
                            PayslipEntryView(environment: environment, sharedItem: item)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Payslip received \(item.receivedAt.formatted(date: .abbreviated, time: .shortened))")
                                if !item.note.isEmpty {
                                    Text(item.note).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions {
                            Button("Discard", role: .destructive) { viewModel.discard(item) }
                        }
                    }
                }
            }

            Section("Pay checks") {
                if viewModel.rows.isEmpty {
                    ContentUnavailableView("No payslips filed",
                                           systemImage: "doc.text.magnifyingglass",
                                           description: Text("Share a payslip to FairShift from Mail, Files or Photos, or add one by hand. FairShift then checks it against the hours you worked."))
                }
                ForEach(viewModel.rows) { row in
                    NavigationLink {
                        PayslipReviewView(environment: environment, row: row)
                    } label: {
                        payslipRow(row)
                    }
                }
            }
        }
        .navigationTitle("Payslips")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add payslip", systemImage: "plus") { showingManualEntry = true }
            }
        }
        .sheet(isPresented: $showingManualEntry, onDismiss: { viewModel.refresh() }) {
            NavigationStack { PayslipEntryView(environment: environment, sharedItem: nil) }
        }
        .onAppear { viewModel.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refresh() }
        }
    }

    private func payslipRow(_ row: PayslipsViewModel.Row) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.workplaceName).font(.headline)
                Text("\(DateText.day(row.payslip.periodStart)) – \(DateText.day(row.payslip.periodEnd))")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            verdictBadge(for: row)
        }
    }

    @ViewBuilder
    private func verdictBadge(for row: PayslipsViewModel.Row) -> some View {
        switch row.review?.verdict {
        case .paidCorrectly:
            Label("Paid correctly", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption.bold())
        case .underpaid(let shortfall):
            Label("Short \(HoursFormat.money(shortfall))", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red).font(.caption.bold())
        case .overpaid(let excess):
            Label("Over by \(HoursFormat.money(excess))", systemImage: "arrow.up.circle.fill")
                .foregroundStyle(.orange).font(.caption.bold())
        case .none:
            Label("Needs shifts", systemImage: "questionmark.circle").foregroundStyle(.secondary).font(.caption.bold())
        }
    }
}

#Preview {
    NavigationStack { PayslipsView(environment: .preview()) }
}
