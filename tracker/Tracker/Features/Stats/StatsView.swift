import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject private var expenseViewModel: ExpenseViewModel
    @State private var selectedTimeframe: TimeframeSelection = .daily
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
            VStack(spacing: 20) {
                Picker("Timeframe", selection: $selectedTimeframe) {
                    Text("Daily").tag(TimeframeSelection.daily)
                    Text("Weekly").tag(TimeframeSelection.weekly)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .frame(height: 44)
                
                if selectedTimeframe == .daily {
                        VStack(spacing: 16) {
                    DailySpendingChart()
                        .frame(height: geometry.size.height * 0.5)
                            
                            DailyTrendChart()
                        }
                } else {
                    WeeklySpendingChart()
                            .frame(height: geometry.size.height * 0.8)
                }
            }
            .padding()
            }
        }
        .navigationTitle("Statistics")
    }
}

struct DailySpendingChart: View {
    @EnvironmentObject private var expenseViewModel: ExpenseViewModel
    
    var body: some View {
        GroupBox("Daily Spending") {
            ScrollView(.horizontal, showsIndicators: false) {
                Chart {
                    ForEach(expenseViewModel.dailySpendingData) { day in
                        ForEach(day.categoryAmounts) { amount in
                            BarMark(
                                x: .value("Date", day.date, unit: .day),
                                y: .value("Amount", amount.amount)
                            )
                            .foregroundStyle(by: .value("Category", amount.category))
                            .position(by: .value("Category", amount.category))
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text("$\(amount, specifier: "%.0f")")
                            }
                        }
                    }
                }
                .chartLegend(position: .bottom, spacing: 10)
                .frame(width: max(CGFloat(expenseViewModel.dailySpendingData.count) * 87.5, 300))
                .frame(height: 300)
                .padding()
            }
        }
    }
}

struct DailyTrendChart: View {
    @EnvironmentObject private var expenseViewModel: ExpenseViewModel
    
    private var dailyTotals: [(date: Date, total: Double)] {
        expenseViewModel.dailySpendingData.map { day in
            (date: day.date, total: day.categoryAmounts.reduce(0) { $0 + $1.amount })
        }
    }
    
    var body: some View {
        GroupBox("Daily Spending Trend") {
            ScrollView(.horizontal, showsIndicators: false) {
                Chart {
                    ForEach(dailyTotals, id: \.date) { day in
                        LineMark(
                            x: .value("Date", day.date, unit: .day),
                            y: .value("Amount", day.total)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.blue.gradient)
                        
                        AreaMark(
                            x: .value("Date", day.date, unit: .day),
                            y: .value("Amount", day.total)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.blue.opacity(0.1))
                        
                        PointMark(
                            x: .value("Date", day.date, unit: .day),
                            y: .value("Amount", day.total)
                        )
                        .symbol(Circle().strokeBorder(lineWidth: 2))
                        .foregroundStyle(.blue)
                        .annotation(position: .top, spacing: 0) {
                            Text("$\(Int(day.total))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text("$\(amount, specifier: "%.0f")")
                            }
                        }
                    }
                }
                .frame(width: max(CGFloat(expenseViewModel.dailySpendingData.count) * 87.5, 300))
                .frame(height: 200)
                .padding()
            }
        }
    }
}

struct WeeklySpendingChart: View {
    @EnvironmentObject private var expenseViewModel: ExpenseViewModel
    
    var body: some View {
        GroupBox("Weekly Spending") {
            Chart {
                ForEach(expenseViewModel.weeklySpendingData) { week in
                    ForEach(week.categoryAmounts) { amount in
                        BarMark(
                            x: .value("Week", week.startDate, unit: .weekOfYear),
                            y: .value("Amount", amount.amount)
                        )
                        .foregroundStyle(by: .value("Category", amount.category))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .chartLegend(position: .bottom)
            .padding()
        }
    }
}

struct CategoryLegend: View {
    @EnvironmentObject private var expenseViewModel: ExpenseViewModel
    
    var body: some View {
        GroupBox("Categories") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(expenseViewModel.fetchCategories(), id: \.name) { category in
                    HStack {
                        Circle()
                            .fill(Color.categoryColor(for: category.name ?? ""))
                            .frame(width: 12, height: 12)
                        Text(category.name ?? "")
                            .font(.caption)
                        Spacer()
                    }
                }
            }
            .padding()
        }
    }
}

enum TimeframeSelection {
    case daily
    case weekly
}

#Preview {
    let context = DatabaseController.preview.container.viewContext
    let expenseViewModel = ExpenseViewModel(viewContext: context)
    
    return StatsView()
        .environment(\.managedObjectContext, context)
        .environmentObject(expenseViewModel)
} 
