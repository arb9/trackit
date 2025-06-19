import WidgetKit
import SwiftUI
import Charts
import CoreData

// MARK: - CoreData Setup
class CoreDataStack {
    static let shared = CoreDataStack()
    
    lazy var container: NSPersistentContainer = {
        print("\n📱 Widget: Initializing CoreData stack...")
        
        let container = NSPersistentContainer(name: "Tracker")
        
        // Configure for App Group container to share with main app
        guard let groupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.none.tracker") else {
            print("❌ Widget: Failed to get App Group container URL")
            fatalError("Could not get App Group container URL")
        }
        
        print("📁 Widget: App Group container path: \(groupContainer.path)")
        
        // Create directories if needed
        do {
            try FileManager.default.createDirectory(at: groupContainer, withIntermediateDirectories: true)
            print("✅ Widget: Created/verified App Group directory")
        } catch {
            print("❌ Widget: Failed to create App Group directory: \(error)")
            fatalError("Failed to create App Group directory")
        }
        
        let storeURL = groupContainer.appendingPathComponent("Tracker.sqlite")
        print("💾 Widget: Database URL: \(storeURL.path)")
        
        if FileManager.default.fileExists(atPath: storeURL.path) {
            print("✅ Widget: Database file exists")
        } else {
            print("⚠️ Widget: Database file does not exist yet")
        }
        
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                print("❌ Widget: Failed to load store: \(error)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            print("✅ Widget: Successfully loaded store")
            
            // Print the model entities
            let entities = container.managedObjectModel.entities
            print("📊 Widget: Available entities: \(entities.map { $0.name ?? "unnamed" })")
            
            // Try to verify the store is accessible
            let context = container.viewContext
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Expense")
            do {
                let count = try context.count(for: fetchRequest)
                print("📈 Widget: Found \(count) expenses in database")
            } catch {
                print("❌ Widget: Failed to count expenses: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
}

// MARK: - Models
struct ExpenseInfo {
    let amount: Double
    let category: String
    let date: Date
    
    init(amount: Double, category: String, date: Date) {
        self.amount = amount
        self.category = category
        self.date = date
    }
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let expenses: [ExpenseInfo]
    
    var totalAmount: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    var expensesByCategory: [(category: String, amount: Double)] {
        Dictionary(grouping: expenses, by: { $0.category })
            .map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
    }
    
    // Preview helper
    static func previewEntry() -> WidgetEntry {
        let previewExpenses = [
            ExpenseInfo(amount: 250, category: "Food", date: Date()),
            ExpenseInfo(amount: 150, category: "Transport", date: Date()),
            ExpenseInfo(amount: 350, category: "Entertainment", date: Date())
        ]
        return WidgetEntry(date: Date(), expenses: previewExpenses)
    }
}

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    let viewContext = CoreDataStack.shared.viewContext
    
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), expenses: [])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        let entry = WidgetEntry(date: Date(), expenses: fetchCurrentMonthExpenses())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> ()) {
        let currentDate = Date()
        let entry = WidgetEntry(date: currentDate, expenses: fetchCurrentMonthExpenses())
        
        // Update every 15 minutes and when data changes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func fetchCurrentMonthExpenses() -> [ExpenseInfo] {
        print("\n🔍 Widget: Starting expense fetch...")
        
        // First verify we can access the database
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.none.tracker")?.appendingPathComponent("Tracker.sqlite") {
            print("📁 Widget: Database should be at: \(url.path)")
            if FileManager.default.fileExists(atPath: url.path) {
                print("✅ Widget: Database file exists")
            } else {
                print("❌ Widget: Database file NOT found!")
            }
        }
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "Expense")
        
        // Get current month's range
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        let startOfMonth = calendar.date(from: components)!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        print("📅 Widget: Fetching expenses between:")
        print("   Start: \(startOfMonth)")
        print("   End: \(endOfMonth)")
        
        // Debug: Try fetching without date filter first
        do {
            let allExpenses = try viewContext.fetch(request)
            print("\n📊 Widget: Found \(allExpenses.count) total expenses in database")
        } catch {
            print("❌ Widget: Failed to fetch all expenses: \(error)")
        }
        
        // Now try with date filter
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startOfMonth as NSDate, endOfMonth as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            let results = try viewContext.fetch(request)
            print("\n📊 Widget: Found \(results.count) expenses for current month")
            
            let expenses = results.map { expense in
                ExpenseInfo(
                    amount: expense.value(forKey: "amount") as? Double ?? 0,
                    category: expense.value(forKeyPath: "category.name") as? String ?? "Uncategorized",
                    date: expense.value(forKey: "date") as? Date ?? Date()
                )
            }
            
            if expenses.isEmpty {
                print("⚠️ Widget: No expenses found for current month")
            } else {
                print("💰 Widget: Total amount for month: \(expenses.reduce(0) { $0 + $1.amount })")
                print("📅 Widget: Date range of expenses: \(expenses.map { $0.date })")
            }
            
            return expenses
        } catch {
            print("❌ Widget: Failed to fetch filtered expenses: \(error)")
            return []
        }
    }
}

// MARK: - Widget Subviews
struct HeaderView: View {
    let totalAmount: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Monthly Total")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("$\(totalAmount, specifier: "%.2f")")
                    .font(.system(size: 12, weight: .semibold))
            }
            Spacer()
        }
    }
}

struct ChartView: View {
    let expensesByCategory: [(category: String, amount: Double)]
    let totalAmount: Double
    let colors: [Color]
    let showPercentages: Bool
    let chartHeight: CGFloat
    
    var body: some View {
        Chart {
            ForEach(expensesByCategory, id: \.category) { item in
                SectorMark(
                    angle: .value("Amount", item.amount),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(colors[expensesByCategory.firstIndex(where: { $0.category == item.category })! % colors.count])
                .annotation(position: .overlay) {
                    if showPercentages && item.amount / totalAmount > 0.1 {
                        Text("\(Int((item.amount / totalAmount) * 100))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.black)
                    }
                }
            }
        }
        .frame(height: chartHeight)
    }
}

struct LegendItemView: View {
    let category: String
    let amount: Double
    let totalAmount: Double
    let color: Color
    let fontSize: CGFloat
    let showPercentage: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(category)
                .font(.system(size: fontSize))
                .lineLimit(1)
            Spacer()
            Text("$\(Int(amount))")
                .font(.system(size: fontSize, weight: .medium))
            if showPercentage {
                Text("(\(Int((amount / totalAmount) * 100))%)")
                    .font(.system(size: fontSize - 2))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LargeWidgetView: View {
    let entry: Provider.Entry
    let colors: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                ChartView(
                    expensesByCategory: entry.expensesByCategory,
                    totalAmount: entry.totalAmount,
                    colors: colors,
                    showPercentages: true,
                    chartHeight: 200
                )
                
                VStack(spacing: 2) {
                    Text("Monthly Total")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                    Text("\(Int(entry.totalAmount))")
                        .font(.system(size: 20, weight: .semibold))
                }
            }
            
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(entry.expensesByCategory.prefix(4)), id: \.category) { item in
                        LegendItemView(
                            category: item.category,
                            amount: item.amount,
                            totalAmount: entry.totalAmount,
                            color: colors[entry.expensesByCategory.firstIndex(where: { $0.category == item.category })! % colors.count],
                            fontSize: 10,
                            showPercentage: false
                        )
                    }
                }
                
                if entry.expensesByCategory.count > 4 {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(entry.expensesByCategory.dropFirst(4).prefix(4)), id: \.category) { item in
                            LegendItemView(
                                category: item.category,
                                amount: item.amount,
                                totalAmount: entry.totalAmount,
                                color: colors[entry.expensesByCategory.firstIndex(where: { $0.category == item.category })! % colors.count],
                                fontSize: 10,
                                showPercentage: false
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct MediumWidgetView: View {
    let entry: Provider.Entry
    let colors: [Color]
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                ChartView(
                    expensesByCategory: entry.expensesByCategory,
                    totalAmount: entry.totalAmount,
                    colors: colors,
                    showPercentages: true,
                    chartHeight: 125
                )
                
                VStack(spacing: 2) {
                    Text("Monthly Total")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("\(Int(entry.totalAmount))")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .chartLegend(.hidden)
            .frame(width: 125)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entry.expensesByCategory, id: \.category) { item in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colors[entry.expensesByCategory.firstIndex(where: { $0.category == item.category })! % colors.count])
                            .frame(width: 6, height: 6)
                        Text(item.category)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .font(.system(size: 8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("$\(Int(item.amount))")
                            .font(.system(size: 8, weight: .medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}

struct SmallWidgetView: View {
    let entry: Provider.Entry
    let colors: [Color]
    
    var body: some View {
        ZStack {
            ChartView(
                expensesByCategory: entry.expensesByCategory,
                totalAmount: entry.totalAmount,
                colors: colors,
                showPercentages: false,
                chartHeight: 180
            )
            
            VStack(spacing: 2) {
                Text("Monthly Total")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                Text("\(Int(entry.totalAmount))")
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .chartLegend(.hidden)
    }
}

// MARK: - Widget View
struct TrackerWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Provider.Entry
    
    private let colors: [Color] = [
        .blue, .purple, .green, .orange, .pink,
        .yellow, .red, .teal, .indigo, .mint
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
//            if family != .systemLarge {
//                HeaderView(totalAmount: entry.totalAmount)
//            }
            
            if entry.expenses.isEmpty {
                ContentUnavailableView("No expenses this month",
                                    systemImage: "chart.pie",
                                    description: Text(""))
            } else {
                switch family {
                case .systemLarge:
                    LargeWidgetView(entry: entry, colors: colors)
                case .systemMedium:
                    MediumWidgetView(entry: entry, colors: colors)
                default:
                    SmallWidgetView(entry: entry, colors: colors)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Widget Configuration
struct TrackerWidget: Widget {
    let kind: String = "TrackerWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TrackerWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Expense Tracker")
        .description("View your monthly expenses")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview
#if DEBUG
struct TrackerWidget_Previews: PreviewProvider {
    static var previews: some View {
        TrackerWidgetEntryView(entry: WidgetEntry.previewEntry())
            .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
#endif

