import SwiftUI
import CoreData

struct HomeView: View {
    let expenseViewModel: ExpenseViewModel
    @State private var currentDate = Date()
    @State private var showingBudgetSheet = false
    @State private var showingAddSpendSheet = false
    @State private var showingClearDataAlert = false
    @State private var showingRandomExpenseAlert = false
    
    private var hasData: Bool {
        return !expenseViewModel.currentMonthExpenses.isEmpty || expenseViewModel.currentBudget != nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        BudgetSummaryView(
                            totalSpent: expenseViewModel.totalSpent,
                            budget: expenseViewModel.currentBudget?.amount ?? 0
                        )
                        .frame(height: 140)
                        .padding(.horizontal)
                        
                        VStack(alignment: .leading) {
                            Text("Spending by Category")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            DonutChartView(data: expenseViewModel.categorySpending)
                                .frame(height: 260)
                        }
                        .padding(.horizontal, 8)
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Recent Expenses")
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    showingAddSpendSheet = true
                                }) {
                                    Label("Add Expense", systemImage: "plus.circle.fill")
                                }
                                
                                Button(action: {
                                    showingRandomExpenseAlert = true
                                }) {
                                    Label("Random Expenses", systemImage: "die.face.5.fill")
                                }
                                .padding(.leading, 8)
                            }
                            .padding(.horizontal)
                            
                            if expenseViewModel.currentMonthExpenses.isEmpty {
                                ContentUnavailableView("No Expenses", systemImage: "dollarsign.circle", description: Text("Add your first expense to get started"))
                                    .frame(height: 200)
                                    .padding(.top)
                            } else {
                                List {
                                    ForEach(expenseViewModel.currentMonthExpenses, id: \.self) { expense in
                                        ExpenseRowView(expense: expense)
                                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                            .listRowBackground(Color.clear)
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button(role: .destructive) {
                                                    expenseViewModel.deleteExpense(expense)
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                                .listStyle(PlainListStyle())
                                .padding(.horizontal, 16)
                                .frame(minHeight: 300, maxHeight: 400)
                            }
                        }
                        .padding(.top)
                        
                        Spacer().frame(height: 80)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Monthly Budget")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if hasData {
                        Button(action: {
                            showingClearDataAlert = true
                        }) {
                            Text("Clear Data")
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showingBudgetSheet = true
                    }) {
                        Text("Set Budget")
                    }
                }
            }
            .sheet(isPresented: $showingBudgetSheet, onDismiss: {
                print("Budget sheet dismissed")
            }) {
                BudgetSettingView(
                    expenseViewModel: expenseViewModel,
                    budget: expenseViewModel.currentBudget
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingAddSpendSheet, onDismiss: {
                print("AddSpendView sheet dismissed")
            }) {
                AddSpendView(expenseViewModel: expenseViewModel)
            }
            .alert("Clear All Data", isPresented: $showingClearDataAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    expenseViewModel.clearAllData()
                }
            } message: {
                Text("This will delete all expenses, budgets, and categories. This action cannot be undone.")
            }
            .alert("Generate Random Expenses", isPresented: $showingRandomExpenseAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Generate", role: .none) {
                    expenseViewModel.generateRandomExpenses()
                }
            } message: {
                Text("This will create 4-13 random expenses for each category, distributed over 5-15 days of the current month. Useful for testing purposes.")
            }
            .onAppear {
                expenseViewModel.refreshAllData()
            }
        }
    }
}

struct BudgetSummaryView: View {
    var totalSpent: Double
    var budget: Double
    
    private var remainingBudget: Double {
        budget - totalSpent
    }
    
    private var progress: Double {
        budget > 0 ? min(totalSpent / budget, 1.0) : 1.0
    }
    
    private var progressColor: Color {
        if progress < 0.7 {
            return .green
        } else if progress < 0.9 {
            return .yellow
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Budget Overview")
                .font(.headline)
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    Text("Total Spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(totalSpent, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(remainingBudget, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(remainingBudget >= 0 ? .primary : .red)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 10)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * progress, height: 10)
                }
            }
            .frame(height: 10)
            
            Text("Budget: $\(budget, specifier: "%.2f")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct ExpenseRowView: View {
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
        .padding(.horizontal, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct BudgetSettingView: View {
    let expenseViewModel: ExpenseViewModel
    var budget: Budget?
    
    @State private var totalBudget: Double = 0
    @State private var categoryBudgets: [String: Double] = [:]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Monthly Budget") {
                    HStack {
                        Text("$")
                        TextField("Amount", value: $totalBudget, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section("Category Budgets") {
                    ForEach(expenseViewModel.fetchCategories(), id: \.self) { category in
                        if let name = category.name {
                            HStack {
                                Text(name)
                                Spacer()
                                Text("$")
                                TextField("Amount", value: Binding(
                                    get: { categoryBudgets[name] ?? 0 },
                                    set: { categoryBudgets[name] = $0 }
                                ), format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Set Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBudget()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadBudget()
            }
        }
    }
    
    private func loadBudget() {
        if let budget = budget {
            totalBudget = budget.amount
            
            let categoryBudgetsArray = expenseViewModel.fetchCategoryBudgets(for: budget)
            for categoryBudget in categoryBudgetsArray {
                if let categoryName = categoryBudget.category?.name {
                    categoryBudgets[categoryName] = categoryBudget.amount
                }
            }
        }
    }
    
    private func saveBudget() {
        expenseViewModel.updateBudget(amount: totalBudget, categoryBudgets: categoryBudgets)
        print("Budget saved with amount: \(totalBudget)")
    }
}

#Preview {
    let viewModel = ExpenseViewModel(viewContext: PersistenceController.preview.container.viewContext)
    return HomeView(expenseViewModel: viewModel)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 
 
