import SwiftUI

struct WorkplacesView: View {
    let environment: AppEnvironment
    @State private var viewModel: WorkplacesViewModel
    @State private var showingAddForm = false

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = State(initialValue: WorkplacesViewModel(environment: environment))
    }

    var body: some View {
        List {
            if viewModel.workplaces.isEmpty {
                ContentUnavailableView("No workplaces yet",
                                       systemImage: "building.2",
                                       description: Text("Add the café, shop or warehouse you work at, with the hourly rate you should be paid."))
            }
            ForEach(viewModel.workplaces) { workplace in
                HStack {
                    Text(workplace.name).font(.headline)
                    Spacer()
                    Text("\(HoursFormat.money(workplace.awardHourlyRate)) / hour")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Workplaces")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add workplace", systemImage: "plus") { showingAddForm = true }
            }
        }
        .sheet(isPresented: $showingAddForm) {
            NavigationStack { addForm }
        }
        .onAppear { viewModel.refresh() }
    }

    private var addForm: some View {
        @Bindable var vm = viewModel
        return Form {
            Section("Workplace") {
                TextField("Name, e.g. Campus Café", text: $vm.newName)
                TextField("Hourly pay rate, e.g. 25.41", text: $vm.newRateText)
                    .keyboardType(.decimalPad)
            }
            if let error = vm.errorMessage {
                Section { Label(error, systemImage: "xmark.octagon.fill").foregroundStyle(.red) }
            }
            Section {
                Button("Save workplace") {
                    if vm.addWorkplace() { showingAddForm = false }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("New workplace")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { showingAddForm = false }
            }
        }
    }
}

#Preview {
    NavigationStack { WorkplacesView(environment: .preview()) }
}
