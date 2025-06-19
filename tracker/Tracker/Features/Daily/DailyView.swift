import SwiftUI
import CoreData

struct DailyView: View {
    let expenseViewModel: ExpenseViewModel
    private let monthsToShow = 2
    @State private var selectedDay: SelectedDay? = nil
    @State private var refreshTrigger = false
    @State private var isRefreshing = false
    
    struct SelectedDay: Identifiable {
        let date: Date
        let expenses: [Expense]
        var id: Date { date }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(0..<monthsToShow, id: \.self) { monthOffset in
                            let date = Calendar.current.date(byAdding: .month, value: -monthOffset, to: Date())!
                            MonthGridView(
                                date: date,
                                dailyTotals: calculateDailyTotals(for: date),
                                dailyExpenses: groupExpensesByDay(for: date),
                                onDaySelected: { day, expenses in
                                    if !expenses.isEmpty {
                                        selectedDay = SelectedDay(date: day, expenses: expenses)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                if isRefreshing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
            .navigationTitle("Daily Spending")
            .sheet(item: $selectedDay) { dayData in
                DayDetailView(date: dayData.date, expenses: dayData.expenses)
            }
            .onAppear {
                refreshView()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSManagedObjectContext.didSaveObjectsNotification)) { _ in
                refreshView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .expenseDataCleared)) { _ in
                refreshView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .expenseDataChanged)) { _ in
                refreshView()
            }
        }
    }
    
    private func refreshView() {
        isRefreshing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expenseViewModel.refreshAllData()
            
            refreshTrigger.toggle()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isRefreshing = false
            }
        }
    }
    
    private func calculateDailyTotals(for date: Date) -> [Int: Double] {
        let calendar = Calendar.current
        let monthComponents = calendar.dateComponents([.year, .month], from: date)
        
        var components = DateComponents()
        components.year = monthComponents.year
        components.month = monthComponents.month
        
        guard let startOfMonth = calendar.date(from: components) else { return [:] }
        
        let expenses = expenseViewModel.fetchExpenses(for: startOfMonth)
        
        var dailyTotals: [Int: Double] = [:]
        
        for expense in expenses {
            guard let expenseDate = expense.date else { continue }
            let day = calendar.component(.day, from: expenseDate)
            dailyTotals[day, default: 0] += expense.amount
        }
        
        return dailyTotals
    }
    
    private func groupExpensesByDay(for date: Date) -> [Int: [Expense]] {
        let calendar = Calendar.current
        let monthComponents = calendar.dateComponents([.year, .month], from: date)
        
        var components = DateComponents()
        components.year = monthComponents.year
        components.month = monthComponents.month
        
        guard let startOfMonth = calendar.date(from: components) else { return [:] }
        
        let expenses = expenseViewModel.fetchExpenses(for: startOfMonth)
        
        var dailyExpenses: [Int: [Expense]] = [:]
        
        for expense in expenses {
            guard let expenseDate = expense.date else { continue }
            let day = calendar.component(.day, from: expenseDate)
            if dailyExpenses[day] == nil {
                dailyExpenses[day] = []
            }
            dailyExpenses[day]?.append(expense)
        }
        
        return dailyExpenses
    }
}

struct DayDetailView: View {
    let date: Date
    let expenses: [Expense]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Total: $\(expenses.reduce(0) { $0 + $1.amount }, specifier: "%.2f")")
                            .font(.headline)
                        
                        Text("\(expenses.count) expense(s)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                }
                
                Section("Expenses") {
                    ForEach(expenses) { expense in
                        DailyExpenseRowView(expense: expense)
                    }
                }
            }
            .navigationTitle(dateFormatter.string(from: date))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

struct MonthGridView: View {
    let date: Date
    let dailyTotals: [Int: Double]
    let dailyExpenses: [Int: [Expense]]
    let onDaySelected: (Date, [Expense]) -> Void
    
    private let daysInWeek = 7
    private let calendar = Calendar.current
    
    private struct EmptyDayID: Hashable {
        let position: Int
        let type: EmptyDayType
        
        enum EmptyDayType {
            case prefix
            case suffix
        }
    }
    
    private var firstDayOfMonth: Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        var dateComponents = DateComponents()
        dateComponents.year = components.year
        dateComponents.month = components.month
        dateComponents.day = 1
        return calendar.date(from: dateComponents) ?? date
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthYearFormatter.string(from: firstDayOfMonth))
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 4)
            
            HStack {
                ForEach(0..<daysInWeek, id: \.self) { index in
                    let weekdayIndex = (index + calendar.firstWeekday - 1) % 7
                    Text(calendar.veryShortWeekdaySymbols[weekdayIndex])
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: daysInWeek), spacing: 8) {
                ForEach((0..<firstWeekdayOfMonth).map { EmptyDayID(position: $0, type: .prefix) }, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(height: 40)
                }
                ForEach(1...daysInMonth, id: \.self) { day in
                    DayCell(day: day, amount: dailyTotals[day] ?? 0)
                        .frame(height: 40)
                        .onTapGesture {
                            if let expenses = dailyExpenses[day], !expenses.isEmpty {
                                let components = calendar.dateComponents([.year, .month], from: date)
                                var dayComponents = DateComponents()
                                dayComponents.year = components.year
                                dayComponents.month = components.month
                                dayComponents.day = day
                                if let dayDate = calendar.date(from: dayComponents) {
                                    onDaySelected(dayDate, expenses)
                                }
                            }
                        }
                }

                let totalDaysDisplayed = firstWeekdayOfMonth + daysInMonth
                let remainingCells = (daysInWeek - (totalDaysDisplayed % daysInWeek)) % daysInWeek
                ForEach((0..<remainingCells).map { EmptyDayID(position: $0, type: .suffix) }, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(height: 40)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    private var firstWeekdayOfMonth: Int {
        let components = calendar.dateComponents([.year, .month], from: date)
        
        var firstDayComponents = DateComponents()
        firstDayComponents.year = components.year
        firstDayComponents.month = components.month
        firstDayComponents.day = 1
        
        guard let firstDay = calendar.date(from: firstDayComponents) else { return 0 }
        
        let weekday = calendar.component(.weekday, from: firstDay)
        return ((weekday - calendar.firstWeekday) + 7) % 7
    }
    
    private var daysInMonth: Int {
        let components = calendar.dateComponents([.year, .month], from: date)
        var firstDayComponents = DateComponents()
        firstDayComponents.year = components.year
        firstDayComponents.month = components.month
        firstDayComponents.day = 1
        
        guard let firstDay = calendar.date(from: firstDayComponents) else { return 30 }
        guard let range = calendar.range(of: .day, in: .month, for: firstDay) else { return 30 }
        return range.count
    }
}

struct DayCell: View {
    let day: Int
    let amount: Double
    
    private var cellColor: Color {
        if amount == 0 {
            return Color.clear
        } else if amount < 250 {
            return Color.green.opacity(0.15)
        } else if amount < 500 {
            return Color.blue.opacity(0.15)
        } else if amount < 750 {
            return Color.orange.opacity(0.15)
        } else {
            return Color.red.opacity(0.15)
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(cellColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if amount > 0 {
                    Text("$\(amount, specifier: "%.0f")")
                        .font(.system(size: 10))
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct DailyExpenseRowView: View {
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
    }
}

#Preview {
    let viewContext = DatabaseController.preview.container.viewContext
    let viewModel = ExpenseViewModel(viewContext: viewContext)
    return DailyView(expenseViewModel: viewModel)
} 
 
