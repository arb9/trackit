import SwiftUI
import CoreData

@main
struct trackerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var expenseViewModel: ExpenseViewModel
    
    init() {
        let viewContext = persistenceController.container.viewContext
        let expenseVM = ExpenseViewModel(viewContext: viewContext)
        
        _expenseViewModel = StateObject(wrappedValue: expenseVM)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(expenseViewModel)
        }
    }
}
