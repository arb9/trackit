import SwiftUI
import Charts

struct CategoryData: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
    let color: Color
}

struct DonutChartView: View {
    var data: [String: Double]
    private var total: Double { data.values.reduce(0, +) }
    
    private var colors: [Color] = [
        .blue, .purple, .green, .orange, .pink, .yellow, .red, .teal, .indigo, .mint
    ]
    
    private var chartData: [CategoryData] {
        Array(data.keys.enumerated()).map { index, category in
            CategoryData(
                category: category,
                amount: data[category] ?? 0,
                color: colors[index % colors.count]
            )
        }
        .sorted { $0.amount > $1.amount }
    }
    
    public init(data: [String: Double]) {
        self.data = data
    }
    
    public var body: some View {
        if data.isEmpty {
            ContentUnavailableView("No Spending Data", 
                                systemImage: "chart.pie", 
                                description: Text("Add expenses to see your spending breakdown"))
        } else {
            HStack(alignment: .center, spacing: 16) {
                Chart {
                    ForEach(chartData) { item in
                        SectorMark(
                            angle: .value("Amount", item.amount),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(item.color)
                        .annotation(position: .overlay) {
                            if item.amount / total > 0.1 {
                                Text("\(Int((item.amount / total) * 100))%")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.black)
                            }
                        }
                    }
                }
                .frame(height: 200)
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(chartData) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 10, height: 10)
                            
                            Text(item.category)
                                .font(.caption)
                                .lineLimit(1)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("$\(item.amount, specifier: "%.2f")")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                
                                Text("\(Int((item.amount / total) * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    DonutChartView(data: [
        "Entertainment": 250.0,
        "Food": 350.0,
        "Transport": 120.0,
        "Groceries": 200.0
    ])
    .frame(height: 300)
    .padding()
} 