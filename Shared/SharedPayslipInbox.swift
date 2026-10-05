import Foundation

// a payslip file that arrived through the share sheet and is waiting for the
// student to type in the hours / amount from it
struct SharedPayslipItem: Codable, Identifiable, Equatable {
    var id: UUID
    var fileName: String
    var receivedAt: Date
    var note: String
}

// the share extension drops files here, the main app picks them up. both sides
// use this one type so the folder layout can't drift apart.
struct SharedPayslipInbox {
    enum InboxError: Error {
        case containerUnavailable
    }

    private let fileManager = FileManager.default

    private func folder(_ name: String) throws -> URL {
        guard let root = AppGroup.containerURL else { throw InboxError.containerUnavailable }
        let url = root.appendingPathComponent(name, isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func inboxFolder() throws -> URL { try folder("PayslipInbox") }
    private func libraryFolder() throws -> URL { try folder("PayslipLibrary") }

    // MARK: written by the share extension

    @discardableResult
    func receive(fileAt source: URL, note: String, now: Date = Date()) throws -> SharedPayslipItem {
        let id = UUID()
        let storedName = "\(id.uuidString)-\(source.lastPathComponent)"
        let inbox = try inboxFolder()
        try fileManager.copyItem(at: source, to: inbox.appendingPathComponent(storedName))

        let item = SharedPayslipItem(id: id, fileName: storedName, receivedAt: now, note: note)
        let sidecar = inbox.appendingPathComponent("\(id.uuidString).json")
        try JSONEncoder().encode(item).write(to: sidecar, options: .atomic)
        return item
    }

    // MARK: read by the main app

    func pendingItems() -> [SharedPayslipItem] {
        guard let inbox = try? inboxFolder(),
              let files = try? fileManager.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)
        else { return [] }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(SharedPayslipItem.self, from: Data(contentsOf: $0)) }
            .sorted { $0.receivedAt > $1.receivedAt }
    }

    func url(for item: SharedPayslipItem) -> URL? {
        guard let inbox = try? inboxFolder() else { return nil }
        let url = inbox.appendingPathComponent(item.fileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    // moves the file out of the inbox into the permanent library once the payslip
    // has been filed, and returns the name it is stored under
    func adopt(_ item: SharedPayslipItem) throws -> String {
        let inbox = try inboxFolder()
        let library = try libraryFolder()
        try fileManager.moveItem(at: inbox.appendingPathComponent(item.fileName),
                                 to: library.appendingPathComponent(item.fileName))
        try? fileManager.removeItem(at: inbox.appendingPathComponent("\(item.id.uuidString).json"))
        return item.fileName
    }

    func discard(_ item: SharedPayslipItem) {
        guard let inbox = try? inboxFolder() else { return }
        try? fileManager.removeItem(at: inbox.appendingPathComponent(item.fileName))
        try? fileManager.removeItem(at: inbox.appendingPathComponent("\(item.id.uuidString).json"))
    }

    func libraryURL(forFileNamed name: String) -> URL? {
        guard let library = try? libraryFolder() else { return nil }
        let url = library.appendingPathComponent(name)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }
}
