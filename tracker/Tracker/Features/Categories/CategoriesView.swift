import SwiftUI
import CoreData

struct CategoryExpenseItemView: View {
    var expense: Expense
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(expense.emoji ?? "💰")
                        .font(.headline)
                    Text(expense.category?.name ?? "Uncategorized")
                        .font(.headline)
                }
                
                if let date = expense.date {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let remarks = expense.remarks, !remarks.isEmpty {
                    Text(remarks)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text("$\(expense.amount, specifier: "%.2f")")
                .font(.headline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct CategoryExpenseRow: View {
    let expense: Expense
    let expenseViewModel: ExpenseViewModel
    
    var body: some View {
        CategoryExpenseItemView(expense: expense)
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    expenseViewModel.deleteExpense(expense)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}

struct CategoryTotalView: View {
    let total: Double
    
    var body: some View {
        HStack {
            Spacer()
            Text("Total: $\(total, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
}

struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var selectedSearchScope: SearchScope
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search expenses...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            Picker("Search Scope", selection: $selectedSearchScope) {
                ForEach(SearchScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }
}

enum SearchScope: String, CaseIterable, Identifiable {
    case all
    case remarks
    case category
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .all: return "All"
        case .remarks: return "Remarks"
        case .category: return "Category"
        }
    }
}

struct CategoriesView: View {
    let expenseViewModel: ExpenseViewModel
    @State private var showingUpdateAlert = false
    @State private var refreshTrigger = false
    @State private var searchText = ""
    @State private var selectedSearchScope: SearchScope = .all
    
    var body: some View {
        NavigationStack {
            VStack {
                SearchBarView(searchText: $searchText, selectedSearchScope: $selectedSearchScope)
                
                categoriesList
            }
            .navigationTitle("Expenses by Category")
            .overlay {
                overlayContent
            }
            .onAppear {
                expenseViewModel.refreshAllData()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSManagedObjectContext.didSaveObjectsNotification)) { _ in
                refreshTrigger.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .expenseDataCleared)) { _ in
                refreshTrigger.toggle()
                expenseViewModel.refreshAllData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .expenseDataChanged)) { _ in
                refreshTrigger.toggle()
                expenseViewModel.refreshAllData()
            }
        }
    }
        
    private var categoriesList: some View {
        List {
            ForEach(Array(groupedExpenses.keys.sorted()), id: \.self) { categoryName in
                if let expenses = groupedExpenses[categoryName], !expenses.isEmpty {
                    Section(header: Text(categoryName)) {
                        ForEach(expenses, id: \.self) { expense in
                            CategoryExpenseRow(expense: expense, expenseViewModel: expenseViewModel)
                        }
                        
                        CategoryTotalView(total: categoryTotal(for: categoryName))
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    @ViewBuilder
    private var overlayContent: some View {
        if expenseViewModel.currentMonthExpenses.isEmpty {
            ContentUnavailableView("No Expenses", 
                                systemImage: "creditcard", 
                                description: Text("Add your first expense to see categories"))
        } else if searchText.isEmpty == false && groupedExpenses.isEmpty {
            ContentUnavailableView("No Matching Expenses", 
                                systemImage: "magnifyingglass", 
                                description: Text("Try searching with different terms"))
        }
    }
        
    private var groupedExpenses: [String: [Expense]] {
        _ = refreshTrigger
        
        let expenses = expenseViewModel.currentMonthExpenses
        var result: [String: [Expense]] = [:]
        
        for expense in expenses {
            if !searchText.isEmpty {
                let searchTextLower = searchText.lowercased()
                let remarks = expense.remarks?.lowercased() ?? ""
                let categoryName = expense.category?.name?.lowercased() ?? ""
                
                switch selectedSearchScope {
                case .all:
                    if !remarks.contains(searchTextLower) && !categoryName.contains(searchTextLower) {
                        continue
                    }
                case .remarks:
                    if !remarks.contains(searchTextLower) {
                        continue
                    }
                case .category:
                    if !categoryName.contains(searchTextLower) {
                        continue
                    }
                }
            }
            
            let categoryName = expense.category?.name ?? "Uncategorized"
            if result[categoryName] == nil {
                result[categoryName] = []
            }
            result[categoryName]?.append(expense)
        }
        
        for (category, expenses) in result {
            result[category] = expenses.sorted { 
                guard let date1 = $0.date, let date2 = $1.date else { return false }
                return date1 > date2
            }
        }
        
        return result
    }
    
    private func categoryTotal(for category: String) -> Double {
        guard let expenses = groupedExpenses[category] else { return 0 }
        return expenses.reduce(0) { $0 + $1.amount }
    }
}

#Preview {
    let viewContext = DatabaseController.preview.container.viewContext
    let viewModel = ExpenseViewModel(viewContext: viewContext)
    CategoriesView(expenseViewModel: viewModel)
} 
