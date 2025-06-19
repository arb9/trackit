import SwiftUI
import CoreData

struct AddSpendView: View {
    let expenseViewModel: ExpenseViewModel
    
    @State private var amount: Double = 0
    @State private var selectedCategory: Category?
    @State private var remarks: String = ""
    @State private var date: Date = Date()
    @State private var selectedEmoji: String = "💰"
    @State private var showAlert = false
    @State private var categories: [Category] = []
    
    @Environment(\.dismiss) private var dismiss
    
    private var emojiOptions: [String] {
        if let category = selectedCategory, let name = category.name {
            if let emojis = expenseViewModel.getCategoryEmojis(for: name) {
                return emojis
            }
        }
        return expenseViewModel.getDefaultEmojis()
    }
    
    private var isFormValid: Bool {
        return amount > 0 && !remarks.isEmpty && selectedCategory != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        Text("$")
                            .font(.headline)
                        TextField("0.00", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.headline)
                    }
                }
                
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category.name ?? "").tag(category as Category?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedCategory) { oldValue, newValue in
                        if let firstEmoji = emojiOptions.first {
                            selectedEmoji = firstEmoji
                        }
                    }
                }
                
                Section("") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Button(action: {
                                selectedEmoji = emoji
                            }) {
                                Text(emoji)
                                    .font(.title)
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Section("Remarks") {
                    TextField("Add notes about this expense", text: $remarks)
                }
                
                Section("Date") {
                    DatePicker("", selection: $date, displayedComponents: [.date])
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .labelsHidden()
                }
                                
                Section {
                    Button("Save Expense") {
                        saveExpense()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(!isFormValid)
                }
            }
            .onAppear {
                loadCategories()
            }
        }
    }
    
    private func loadCategories() {
        expenseViewModel.createDefaultCategoriesIfNeeded()
        
        categories = expenseViewModel.fetchCategories()
        
        if !categories.isEmpty && selectedCategory == nil {
            selectedCategory = categories.first
            
            if let firstEmoji = emojiOptions.first {
                selectedEmoji = firstEmoji
            }
        }
    }
    
    private func saveExpense() {
        guard let category = selectedCategory, amount > 0 && !remarks.isEmpty else { return }
        
        expenseViewModel.addExpense(
            amount: amount,
            category: category,
            remarks: remarks,
            date: date,
            emoji: selectedEmoji
        )
        
        dismiss()
    }
}

#Preview {
    let viewModel = ExpenseViewModel(viewContext: DatabaseController.preview.container.viewContext)
    return AddSpendView(expenseViewModel: viewModel)
        .environment(\.managedObjectContext, DatabaseController.preview.container.viewContext)
} 
