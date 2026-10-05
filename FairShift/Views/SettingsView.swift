import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    init(environment: AppEnvironment) {
        _viewModel = State(initialValue: SettingsViewModel(environment: environment))
    }

    var body: some View {
        @Bindable var vm = viewModel

        Form {
            Section {
                Stepper("Limit: \(Int(vm.hoursPerFortnight)) hours per fortnight",
                        value: $vm.hoursPerFortnight, in: 10...80, step: 1)
                DatePicker("A fortnight starts on", selection: $vm.fortnightAnchor, displayedComponents: .date)
            } header: {
                Text("Visa work limit")
            } footer: {
                Text("48 hours per fortnight is a common limit for student visas, but check the exact condition on your own visa grant. Pick any date a fortnight began — FairShift counts 14-day blocks from there.")
            }

            Section {
                Button("Save") { vm.save() }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
            }

            Section {
                Button("Load sample shifts & payslip") { vm.loadSampleData() }
            } header: {
                Text("Try it out")
            } footer: {
                Text("Adds a café job, a week of shifts and a payslip that's short by an hour, so you can see the pay check and the widget working.")
            }

            if let message = vm.message {
                Section { Text(message).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Visa limit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { SettingsView(environment: .preview()) }
}
