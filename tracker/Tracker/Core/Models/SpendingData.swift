import Foundation

struct DailySpending: Identifiable {
    let id = UUID()
    let date: Date
    let categoryAmounts: [CategoryAmount]
}

struct WeeklySpending: Identifiable {
    let id = UUID()
    let startDate: Date
    let categoryAmounts: [CategoryAmount]
}

struct CategoryAmount: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
} 
