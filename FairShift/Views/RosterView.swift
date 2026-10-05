import SwiftUI

struct RosterView: View {
    let environment: AppEnvironment
    @State private var viewModel: RosterViewModel
    @State private var editor: EditorRequest?

    private struct EditorRequest: Identifiable {
        let id = UUID()
        let mode: ShiftEditorViewModel.Mode
        var prefill: WorkShift?
    }

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = State(initialValue: RosterViewModel(environment: environment))
    }

    var body: some View {
        List {
            if let message = viewModel.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }

            if viewModel.rows.isEmpty {
                ContentUnavailableView("No shifts yet",
                                       systemImage: "calendar.badge.plus",
                                       description: Text("Roster the shifts your manager has given you, and record the ones you've worked."))
            }

            ForEach(viewModel.rows) { row in
                shiftRow(row)
                    .swipeActions(edge: .trailing) {
                        Button("Remove", role: .destructive) { viewModel.remove(row.shift) }
                    }
                    .swipeActions(edge: .leading) {
                        if row.shift.status == .rostered && row.shift.endsAt <= Date() {
                            Button("Worked") {
                                editor = EditorRequest(mode: .recordWorked(rosteredShiftID: row.shift.id), prefill: row.shift)
                            }
                            .tint(.green)
                        }
                    }
            }
        }
        .navigationTitle("Roster")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Roster an upcoming shift", systemImage: "calendar.badge.plus") {
                        editor = EditorRequest(mode: .roster)
                    }
                    Button("Record a worked shift", systemImage: "checkmark.circle") {
                        editor = EditorRequest(mode: .recordWorked(rosteredShiftID: nil))
                    }
                } label: {
                    Label("Add shift", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editor, onDismiss: { viewModel.refresh() }) { request in
            NavigationStack {
                ShiftEditorView(environment: environment, mode: request.mode, prefill: request.prefill)
            }
        }
        .onAppear { viewModel.refresh() }
    }

    private func shiftRow(_ row: RosterViewModel.Row) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.workplaceName).font(.headline)
                Text("\(DateText.dayAndTime(row.shift.startsAt)) – \(DateText.time(row.shift.endsAt))")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(HoursFormat.string(row.shift.paidHours)) h").font(.headline)
                Text(row.shift.status == .worked ? "Worked" : "Rostered")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(row.shift.status == .worked ? Color.green.opacity(0.2) : Color.blue.opacity(0.2),
                                in: Capsule())
            }
        }
    }
}

#Preview {
    NavigationStack { RosterView(environment: .preview()) }
}
