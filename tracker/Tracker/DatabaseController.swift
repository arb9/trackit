import CoreData

class DatabaseController {
    static let shared = DatabaseController()

    @MainActor
    static let preview: DatabaseController = {
        let result = DatabaseController(inMemory: true)
        let viewContext = result.container.viewContext
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        print("\n📱 App: Initializing CoreData stack...")
        
        container = NSPersistentContainer(name: "Tracker")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure for App Group container to share with widget
            guard let groupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.none.tracker") else {
                print("❌ App: Failed to get App Group container URL")
                fatalError("Could not get App Group container URL")
            }
            
            print("📁 App: App Group container path: \(groupContainer.path)")
            
            // Create directories if needed
            do {
                try FileManager.default.createDirectory(at: groupContainer, withIntermediateDirectories: true)
                print("✅ App: Created/verified App Group directory")
            } catch {
                print("❌ App: Failed to create App Group directory: \(error)")
                fatalError("Failed to create App Group directory")
            }
            
            let storeURL = groupContainer.appendingPathComponent("Tracker.sqlite")
            print("💾 App: Database URL: \(storeURL.path)")
            
            if FileManager.default.fileExists(atPath: storeURL.path) {
                print("✅ App: Database file exists")
            } else {
                print("⚠️ App: Database file does not exist yet")
            }
            
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            container.persistentStoreDescriptions = [storeDescription]
        }

        container.loadPersistentStores { [self] description, error in
            if let error = error as NSError? {
                print("❌ App: Failed to load store: \(error)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            print("✅ App: Successfully loaded store")
            
            // Print the model entities
            let entities = self.container.managedObjectModel.entities
            print("📊 App: Available entities: \(entities.map { $0.name ?? "unnamed" })")
            
            // Try to verify the store is accessible
            let context = self.container.viewContext
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Expense")
            do {
                let count = try context.count(for: fetchRequest)
                print("📈 App: Found \(count) expenses in database")
            } catch {
                print("❌ App: Failed to count expenses: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
} 
