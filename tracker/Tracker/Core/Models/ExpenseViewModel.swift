import Foundation
import CoreData
import SwiftUI
import WidgetKit

final class ExpenseViewModel: ObservableObject {
    private var viewContext: NSManagedObjectContext
    @Published private(set) var currentBudget: Budget?
    @Published private(set) var categoryBudgets: [CategoryBudget] = []
    @Published private(set) var currentMonthExpenses: [Expense] = []
    @Published private(set) var totalSpent: Double = 0
    @Published private(set) var categorySpending: [String: Double] = [:]
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        createDefaultCategoriesIfNeeded()
        refreshAllData()
    }
    
    // MARK: - Data Refresh
    
    func refreshAllData() {
        let currentDate = Date()
        
        currentBudget = fetchCurrentBudget()
        
        if let budget = currentBudget {
            categoryBudgets = fetchCategoryBudgets(for: budget)
        } else {
            categoryBudgets = []
        }
        
        currentMonthExpenses = fetchExpenses(for: currentDate)
        totalSpent = currentMonthExpenses.reduce(0) { $0 + $1.amount }
        categorySpending = expensesByCategory(for: currentDate)
    }
    
    // MARK: - Expense Methods
    
    func addExpense(amount: Double, category: Category, remarks: String, date: Date, emoji: String) {
        let newExpense = Expense(context: viewContext)
        newExpense.amount = amount
        newExpense.category = category
        newExpense.remarks = remarks
        newExpense.date = date
        newExpense.emoji = emoji
        
        saveContext()
        refreshAllData()
        
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func fetchExpenses(for month: Date) -> [Expense] {
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        
        let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: month))!
        let endOfMonth = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startOfMonth as NSDate, endOfMonth as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching expenses: \(error)")
            return []
        }
    }
    
    func deleteExpense(_ expense: Expense) {
        viewContext.delete(expense)
        saveContext()
        refreshAllData()
        
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func updateExpense(_ expense: Expense, amount: Double, category: Category, remarks: String, date: Date, emoji: String) {
        expense.amount = amount
        expense.category = category
        expense.remarks = remarks
        expense.date = date
        expense.emoji = emoji
        
        saveContext()
        refreshAllData()
        
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func clearAllExpenses() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Expense.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try viewContext.execute(deleteRequest)
            saveContext()
            refreshAllData()
            
            NotificationCenter.default.post(name: .expenseDataCleared, object: nil)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Failed to clear expenses: \(error)")
        }
    }
    
    // MARK: - Category Methods
    
    func createCategory(name: String) -> Category {
        let newCategory = Category(context: viewContext)
        newCategory.name = name
        saveContext()
        return newCategory
    }
    
    func fetchCategories() -> [Category] {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching categories: \(error)")
            return []
        }
    }
    
    func createDefaultCategoriesIfNeeded() {
        let categories = fetchCategories()
        
        if categories.isEmpty {
            let defaultCategories = ["Transport", "Entertainment", "Groceries", "Hobbies", "Subscriptions", "Utilities", "Healthcare", "Food"]
            for category in defaultCategories {
                _ = createCategory(name: category)
            }
        }
    }
    
    // MARK: - Budget Methods
    
    func createBudget(amount: Double, month: Date) -> Budget {
        let newBudget = Budget(context: viewContext)
        newBudget.amount = amount
        newBudget.month = month
        saveContext()
        refreshAllData()
        return newBudget
    }
    
    func createCategoryBudget(amount: Double, category: Category, budget: Budget) {
        let newCategoryBudget = CategoryBudget(context: viewContext)
        newCategoryBudget.amount = amount
        newCategoryBudget.category = category
        newCategoryBudget.budget = budget
        saveContext()
        refreshAllData()
    }
    
    func deleteCategoryBudget(_ categoryBudget: CategoryBudget) {
        viewContext.delete(categoryBudget)
        saveContext()
        refreshAllData()
    }
    
    func fetchCurrentBudget() -> Budget? {
        let now = Date()
        let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now))!
        
        let request: NSFetchRequest<Budget> = Budget.fetchRequest()
        request.predicate = NSPredicate(format: "month == %@", startOfMonth as NSDate)
        request.fetchLimit = 1
        
        do {
            let budgets = try viewContext.fetch(request)
            return budgets.first
        } catch {
            print("Error fetching budget: \(error)")
            return nil
        }
    }
    
    func fetchCategoryBudgets(for budget: Budget) -> [CategoryBudget] {
        guard let categoryBudgets = budget.categoryBudgets as? Set<CategoryBudget> else { return [] }
        return Array(categoryBudgets).sorted { $0.category?.name ?? "" < $1.category?.name ?? "" }
    }
    
    func updateBudget(amount: Double, categoryBudgets: [String: Double]) {
        let currentDate = Date()
        let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: currentDate))!
        
        let budget: Budget
        if let existingBudget = fetchCurrentBudget() {
            budget = existingBudget
            budget.amount = amount
        } else {
            budget = createBudget(amount: amount, month: startOfMonth)
        }
        
        for existingCategoryBudget in fetchCategoryBudgets(for: budget) {
            deleteCategoryBudget(existingCategoryBudget)
        }
        
        for category in fetchCategories() {
            guard let categoryName = category.name else { continue }
            let budgetAmount = categoryBudgets[categoryName] ?? 0
            createCategoryBudget(amount: budgetAmount, category: category, budget: budget)
        }
        
        saveContext()
        refreshAllData()
        
        print("Budget updated: \(amount), categories: \(categoryBudgets)")
    }
    
    // MARK: - Analytics
    
    func totalExpenses(for month: Date) -> Double {
        let expenses = fetchExpenses(for: month)
        return expenses.reduce(0) { $0 + $1.amount }
    }
    
    func expensesByCategory(for month: Date) -> [String: Double] {
        let expenses = fetchExpenses(for: month)
        var result: [String: Double] = [:]
        
        for expense in expenses {
            let categoryName = expense.category?.name ?? "Uncategorized"
            result[categoryName, default: 0] += expense.amount
        }
        
        return result
    }
    
    // MARK: - Data Clearing
    
    func clearAllData() {
        let context = viewContext
        
        let expenseFetchRequest: NSFetchRequest<NSFetchRequestResult> = Expense.fetchRequest()
        let expenseDeleteRequest = NSBatchDeleteRequest(fetchRequest: expenseFetchRequest)
        
        let categoryFetchRequest: NSFetchRequest<NSFetchRequestResult> = Category.fetchRequest()
        let categoryDeleteRequest = NSBatchDeleteRequest(fetchRequest: categoryFetchRequest)
        
        let budgetFetchRequest: NSFetchRequest<NSFetchRequestResult> = Budget.fetchRequest()
        let budgetDeleteRequest = NSBatchDeleteRequest(fetchRequest: budgetFetchRequest)
        
        do {
            try context.execute(expenseDeleteRequest)
            try context.execute(categoryDeleteRequest)
            try context.execute(budgetDeleteRequest)
            
            try context.save()
            
            createDefaultCategoriesIfNeeded()
            refreshAllData()
            
            NotificationCenter.default.post(name: .expenseDataCleared, object: nil)
        } catch {
            print("Error clearing data: \(error)")
        }
    }
    
    // MARK: - Utilities
    
    func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    // MARK: - Category Emoji Methods
    
    private let categoryEmojis: [String: [String]] = [
        "Transport": ["🚗", "🚕", "🚌", "🚇", "⛽️", "🛵", "🚞"],
        "Entertainment": ["🎮", "🎬", "🎭", "🎟️", "🎪", "🎨", "🎯"],
        "Groceries": ["🛒", "🍎", "🥦", "🍞", "🥛", "🍽️", "🥑"],
        "Hobbies": ["📚", "🎸", "🏀", "⚽️", "🎣", "🧩", "🎲"],
        "Subscriptions": ["📺", "🎵", "📱", "💻", "📰", "🎙️", "🎬"],
        "Utilities": ["💡", "💧", "🔥", "📶", "📡", "🔌", "🧹"],
        "Healthcare": ["💊", "🩹", "🧴", "🦷", "👓", "🧬", "🏥"],
        "Food": ["🍔", "🍕", "🍣", "🍜", "🍲", "🍷", "🍹", "☕️", "🍦", "🍳"]
    ]
    
    private let categoryRemarks: [String: [String]] = [
        "Transport": [
            "Filled up the tank",
            "Train ticket",
            "Bus fare",
            "Taxi ride",
            "Car maintenance",
            "Parking fee",
            "Toll road",
            "Subway pass"
        ],
        "Entertainment": [
            "Movie night",
            "Video game",
            "Concert tickets",
            "Theater show",
            "Museum entry",
            "Amusement park",
            "Streaming service",
            "Sports event"
        ],
        "Groceries": [
            "Weekly groceries",
            "Fresh produce",
            "Pantry staples",
            "Grocery delivery",
            "Farmers market",
            "Bulk shopping",
            "Specialty foods",
            "Snacks"
        ],
        "Hobbies": [
            "New book",
            "Art supplies",
            "Musical equipment",
            "Sports gear",
            "Photography equipment",
            "Craft supplies",
            "Gardening tools",
            "Workshop materials"
        ],
        "Subscriptions": [
            "Monthly subscription",
            "Annual membership",
            "Streaming service",
            "Magazine subscription",
            "Software license",
            "App purchase",
            "Cloud storage",
            "Online courses"
        ],
        "Utilities": [
            "Electricity bill",
            "Water bill",
            "Gas bill",
            "Internet service",
            "Phone bill",
            "Waste management",
            "Home insurance",
            "Security service"
        ],
        "Healthcare": [
            "Doctor's visit",
            "Prescription",
            "Vitamins & supplements",
            "Dental care",
            "Eye care",
            "Therapy session",
            "Medical equipment",
            "Insurance copay"
        ],
        "Food": [
            "Lunch with friends",
            "Dinner out",
            "Coffee break",
            "Pizza delivery",
            "Sushi restaurant",
            "Brunch with family",
            "Restaurant tip",
            "Fast food",
            "Food delivery",
            "Ice cream shop"
        ]
    ]
    
    private let defaultEmojiOptions = ["💰", "💸", "💵", "💳", "🧾", "📊", "📝"]
    
    private let defaultRemarkOptions = [
        "Miscellaneous purchase",
        "Online purchase",
        "Shopping",
        "Monthly expense",
        "Regular purchase",
        "Gift for someone",
        "Necessary expense",
        ""
    ]
    
    func getCategoryEmojis(for categoryName: String) -> [String]? {
        return categoryEmojis[categoryName]
    }
    
    func getDefaultEmojis() -> [String] {
        return defaultEmojiOptions
    }
    
    func getRandomEmoji(for categoryName: String) -> String {
        if let emojis = categoryEmojis[categoryName], !emojis.isEmpty {
            return emojis.randomElement()!
        }
        return defaultEmojiOptions.randomElement()!
    }
    
    func getCategoryRemarks(for categoryName: String) -> [String] {
        return categoryRemarks[categoryName] ?? defaultRemarkOptions
    }
    
    func getRandomRemark(for categoryName: String) -> String {
        if let remarks = categoryRemarks[categoryName], !remarks.isEmpty {
            return remarks.randomElement()!
        }
        return defaultRemarkOptions.randomElement()!
    }
    
    // MARK: - Testing & Debug
    
    func generateRandomExpenses() {
        let categories = fetchCategories()
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: now)
        let startOfMonth = calendar.date(from: components)!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        let numberOfDaysInMonth = range.count
        
        let numberOfDays = Int.random(in: 5...min(15, numberOfDaysInMonth))
        
        var randomDays = Set<Int>()
        while randomDays.count < numberOfDays {
            randomDays.insert(Int.random(in: 1...numberOfDaysInMonth))
        }
        
        for category in categories {
            guard let categoryName = category.name else { continue }
            
            let expensesCount = Int.random(in: 4...13)
            
            for _ in 0..<expensesCount {
                let randomDay = randomDays.randomElement()!
                var dateComponents = DateComponents()
                dateComponents.year = components.year
                dateComponents.month = components.month
                dateComponents.day = randomDay
                
                dateComponents.hour = Int.random(in: 8...22)
                dateComponents.minute = Int.random(in: 0...59)
                let date = calendar.date(from: dateComponents)!
                
                let amount = Double.random(in: 5...150).rounded(to: 2)
                
                let emoji = getRandomEmoji(for: categoryName)
                let remark = getRandomRemark(for: categoryName)
                
                addExpense(
                    amount: amount,
                    category: category,
                    remarks: remark,
                    date: date,
                    emoji: emoji
                )
            }
        }
        
        refreshAllData()
        
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
    }
    
    // MARK: - Stats Methods
    
    var dailySpendingData: [DailySpending] {
        let calendar = Calendar.current
        
        // Create a dictionary to group expenses by date
        var expensesByDate: [Date: [Expense]] = [:]
        
        // Group expenses by date
        for expense in currentMonthExpenses {
            guard let date = expense.date else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            expensesByDate[startOfDay, default: []].append(expense)
        }
        
        // Convert grouped expenses into DailySpending objects
        return expensesByDate.map { date, expenses in
            // Group expenses by category
            var categoryAmounts: [CategoryAmount] = []
            let expensesByCategory = Dictionary(grouping: expenses) { $0.category?.name ?? "Uncategorized" }
            
            for (category, categoryExpenses) in expensesByCategory {
                let totalAmount = categoryExpenses.reduce(0) { $0 + $1.amount }
                categoryAmounts.append(CategoryAmount(category: category, amount: totalAmount))
            }
            
            return DailySpending(date: date, categoryAmounts: categoryAmounts)
        }
        .sorted { $0.date < $1.date }
    }
    
    var weeklySpendingData: [WeeklySpending] {
        let calendar = Calendar.current
        
        // Create a dictionary to group expenses by week
        var expensesByWeek: [Date: [Expense]] = [:]
        
        // Group expenses by week
        for expense in currentMonthExpenses {
            guard let date = expense.date else { continue }
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
            expensesByWeek[weekStart, default: []].append(expense)
        }
        
        // Convert grouped expenses into WeeklySpending objects
        return expensesByWeek.map { weekStart, expenses in
            // Group expenses by category
            var categoryAmounts: [CategoryAmount] = []
            let expensesByCategory = Dictionary(grouping: expenses) { $0.category?.name ?? "Uncategorized" }
            
            for (category, categoryExpenses) in expensesByCategory {
                let totalAmount = categoryExpenses.reduce(0) { $0 + $1.amount }
                categoryAmounts.append(CategoryAmount(category: category, amount: totalAmount))
            }
            
            return WeeklySpending(startDate: weekStart, categoryAmounts: categoryAmounts)
        }
        .sorted { $0.startDate < $1.startDate }
    }
}

extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

extension Notification.Name {
    static let expenseDataCleared = Notification.Name("expenseDataCleared")
    static let expenseDataChanged = Notification.Name("expenseDataChanged")
} 
