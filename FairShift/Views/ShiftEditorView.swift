import SwiftUI

struct ShiftEditorView: View {
    @State private var viewModel: ShiftEditorViewModel
    @Environment(\.dismiss) private var dismiss

    init(environment: AppEnvironment, mode: ShiftEditorViewModel.Mode, prefill: WorkShift? = nil) {
        _viewModel = State(initialValue: ShiftEditorViewModel(environment: environment, mode: mode, prefill: prefill))
    }

    var body: some View {
        @Bindable var vm = viewModel

        Form {
            Section("Where") {
                if vm.workplaces.isEmpty {
                    Text("You haven't added a workplace yet. Add one on the Workplaces tab first.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Workplace", selection: $vm.workplaceID) {
                        ForEach(vm.workplaces) { workplace in
                            Text(workplace.name).tag(Optional(workplace.id))
                        }
                    }
                }
            }

            Section("When") {
                DatePicker("Starts", selection: $vm.startsAt)
                DatePicker("Finishes", selection: $vm.endsAt)
                Stepper("Unpaid break: \(vm.unpaidBreakMinutes) min", value: $vm.unpaidBreakMinutes, in: 0...120, step: 5)
            }

            if let warning = vm.limitWarning {
                Section {
                    Label(warning, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
            if let error = vm.errorMessage {
                Section {
                    Label(error, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
                }
            }

            Section {
                if vm.didSave {
                    Button("Done") { dismiss() }
                        .frame(maxWidth: .infinity)
                } else {
                    Button(vm.saveButtonTitle) { vm.save() }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.workplaces.isEmpty)
                }
            }
        }
        .navigationTitle(vm.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .onAppear { vm.load() }
        .onChange(of: vm.didSave) { _, saved in
            // if there's a warning, keep the sheet open until they tap Done
            if saved && vm.limitWarning == nil { dismiss() }
        }
    }
}

#Preview {
    NavigationStack {
        ShiftEditorView(environment: .preview(), mode: .roster)
    }
}
