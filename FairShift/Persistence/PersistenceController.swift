import CoreData

// owns the Core Data stack. the store lives inside the App Group container, so it
// is one shared location (and survives the app being updated).
final class PersistenceController {
    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FairShift")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else if let groupURL = AppGroup.containerURL {
            container.persistentStoreDescriptions.first?.url = groupURL.appendingPathComponent("FairShift.sqlite")
        }

        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Core Data store failed to load: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
