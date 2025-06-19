import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var expenseViewModel: ExpenseViewModel
    
    var body: some View {
        TabView {
            HomeView(expenseViewModel: expenseViewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
            
            DailyView(expenseViewModel: expenseViewModel)
                .tabItem {
                    Label("Daily", systemImage: "calendar")
                }
            
            CategoriesView(expenseViewModel: expenseViewModel)
                .tabItem {
                    Label("Categories", systemImage: "list.bullet.rectangle")
                }
            
            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
        }
    }
}

#Preview {
    let context = DatabaseController.preview.container.viewContext
    let expenseViewModel = ExpenseViewModel(viewContext: context)
    
    return ContentView()
        .environment(\.managedObjectContext, context)
        .environmentObject(expenseViewModel)
}
