import UIKit
import SwiftUI
import UniformTypeIdentifiers

// the share sheet extension. payslips usually turn up as an email PDF or a screenshot;
// sharing it to FairShift drops a copy in the App Group inbox, and the main app asks
// for the hours and pay next time it opens.
final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        let content = SharePayslipView(
            model: model,
            onSave: { [weak self] in self?.save() },
            onCancel: { [weak self] in self?.cancel() })
        let host = UIHostingController(rootView: content)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        loadAttachments()
    }

    // MARK: reading what was shared

    private func loadAttachments() {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []
        let wanted = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) ||
            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }

        guard !wanted.isEmpty else {
            model.problem = "FairShift can only take payslips as a PDF or a picture. Share the payslip file, or take a screenshot of it."
            return
        }

        for provider in wanted {
            let type = provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) ? UTType.pdf : UTType.image
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { [weak self] url, error in
                // iOS deletes `url` as soon as this closure ends, so copy it first
                var copy: URL?
                if let url {
                    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    let destination = folder.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    if (try? FileManager.default.copyItem(at: url, to: destination)) != nil { copy = destination }
                }
                DispatchQueue.main.async {
                    if let copy {
                        self?.model.files.append(copy)
                    } else {
                        self?.model.problem = "FairShift couldn't read that file. Try sharing it again, or save it to Files first and share it from there."
                    }
                }
            }
        }
    }

    // MARK: finishing

    private func save() {
        do {
            let inbox = SharedPayslipInbox()
            for file in model.files {
                try inbox.receive(fileAt: file, note: model.note)
            }
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            model.problem = "FairShift couldn't save the payslip. Open FairShift once, then try sharing it again."
        }
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }
}

final class ShareModel: ObservableObject {
    @Published var files: [URL] = []
    @Published var note = ""
    @Published var problem: String?
}

struct SharePayslipView: View {
    @ObservedObject var model: ShareModel
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if model.files.isEmpty && model.problem == nil {
                        HStack { ProgressView(); Text("Reading the payslip…") }
                    }
                    ForEach(model.files, id: \.self) { file in
                        Label(file.lastPathComponent, systemImage: "doc.text.fill")
                    }
                } header: {
                    Text("Payslip to send to FairShift")
                } footer: {
                    Text("FairShift will ask you for the hours and pay on the payslip, then check them against the shifts you worked.")
                }

                Section("Note (optional)") {
                    TextField("e.g. Campus Café, fortnight ending 12 Oct", text: $model.note)
                }

                if let problem = model.problem {
                    Section { Label(problem, systemImage: "xmark.octagon.fill").foregroundStyle(.red) }
                }
            }
            .navigationTitle("Save to FairShift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave).disabled(model.files.isEmpty)
                }
            }
        }
    }
}
