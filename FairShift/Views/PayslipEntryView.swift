import SwiftUI
import UIKit

struct PayslipEntryView: View {
    @State private var viewModel: PayslipEntryViewModel
    @Environment(\.dismiss) private var dismiss

    init(environment: AppEnvironment, sharedItem: SharedPayslipItem?) {
        _viewModel = State(initialValue: PayslipEntryViewModel(environment: environment, sharedItem: sharedItem))
    }

    var body: some View {
        @Bindable var vm = viewModel

        Form {
            if let url = vm.attachmentURL {
                Section("The payslip you shared") {
                    if let image = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                    } else {
                        Label(url.lastPathComponent, systemImage: "doc.fill")
                    }
                    Text("Copy the pay period, hours and pay from it into the boxes below.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Workplace") {
                if vm.workplaces.isEmpty {
                    Text("Add the workplace on the Workplaces tab first.").foregroundStyle(.secondary)
                } else {
                    Picker("Workplace", selection: $vm.workplaceID) {
                        ForEach(vm.workplaces) { workplace in
                            Text(workplace.name).tag(Optional(workplace.id))
                        }
                    }
                }
            }

            Section("Pay period on the payslip") {
                DatePicker("From", selection: $vm.periodStart, displayedComponents: .date)
                DatePicker("To", selection: $vm.periodEnd, displayedComponents: .date)
            }

            Section("What you were paid") {
                TextField("Hours paid, e.g. 20.5", text: $vm.hoursText).keyboardType(.decimalPad)
                TextField("Amount paid in AUD, e.g. 520.90", text: $vm.amountText).keyboardType(.decimalPad)
            }

            if let error = vm.errorMessage {
                Section { Label(error, systemImage: "xmark.octagon.fill").foregroundStyle(.red) }
            }

            Section {
                Button("File payslip & check it") { vm.save() }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.workplaces.isEmpty)
            }
        }
        .navigationTitle("File a payslip")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.load() }
        .onChange(of: vm.didSave) { _, saved in
            if saved { dismiss() }
        }
    }
}

#Preview {
    NavigationStack { PayslipEntryView(environment: .preview(), sharedItem: nil) }
}
