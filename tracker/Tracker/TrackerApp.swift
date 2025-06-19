import SwiftUI
import CoreData

@main
struct TrackerApp: App {
    let databaseController = DatabaseController.shared
    @StateObject private var expenseViewModel: ExpenseViewModel
    
    init() {
        let viewContext = databaseController.container.viewContext
        let expenseVM = ExpenseViewModel(viewContext: viewContext)
        
        _expenseViewModel = StateObject(wrappedValue: expenseVM)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, databaseController.container.viewContext)
                .environmentObject(expenseViewModel)
        }
    }
}
