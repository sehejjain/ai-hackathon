//
//  SpendingChartView.swift
//  SpendConscience
//
//  Created by AI Assistant on 9/13/2025.
//

import SwiftUI
import Charts
import SwiftData

@available(iOS 16.0, *)
struct SpendingChartView: View {
    @ObservedObject var dataManager: DataManager
    let showNavigationTitle: Bool
    @State private var selectedChartType: ChartType = .monthlyTrend
    @State private var isLoading = false
    @State private var monthlyData: [MonthlySpendingData] = []
    @State private var categoryData: [CategorySpendingData] = []
    
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter
    }()
    
    private var adaptiveChartHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        return min(screenHeight * 0.4, 300)
    }
    
    init(dataManager: DataManager, showNavigationTitle: Bool = true) {
        self.dataManager = dataManager
        self.showNavigationTitle = showNavigationTitle
    }
    
    enum ChartType: String, CaseIterable {
        case monthlyTrend = "Monthly Trend"
        case categoryBreakdown = "Category Breakdown"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Chart Type Selector
            Picker("Chart Type", selection: $selectedChartType) {
                ForEach(ChartType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Chart Content
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        loadingView
                    } else {
                        switch selectedChartType {
                        case .monthlyTrend:
                            monthlyTrendChart(height: adaptiveChartHeight)
                        case .categoryBreakdown:
                            categoryBreakdownChart(height: adaptiveChartHeight)
                        }
                    }
                }
                .padding()
            }
        }
        .apply { view in
            if showNavigationTitle {
                view.navigationTitle("Spending Analysis")
            } else {
                view
            }
        }
        .onAppear {
            loadChartData()
        }
        .onChange(of: selectedChartType) {
            loadChartData()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading spending data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Loading spending data")
    }
    
    // MARK: - Monthly Trend Chart
    private func monthlyTrendChart(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Spending Trends")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            if monthlyData.isEmpty {
                emptyStateView(message: "No spending data available for the past 6 months")
            } else {
                Chart(monthlyData) { data in
                    LineMark(
                        x: .value("Month", data.month),
                        y: .value("Amount", data.doubleAmount)
                    )
                    .foregroundStyle(lineColor(for: data.amount))
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    PointMark(
                        x: .value("Month", data.month),
                        y: .value("Amount", data.doubleAmount)
                    )
                    .foregroundStyle(lineColor(for: data.amount))
                    .symbolSize(60)
                }
                .frame(height: height)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(formatCurrency(Decimal(amount)))
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let month = value.as(String.self) {
                                Text(month)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .accessibilityLabel("Monthly spending trend chart showing spending over the past 6 months")
                .accessibilityValue(monthlyTrendAccessibilityDescription)
                
                // Trend Summary
                trendSummaryView
            }
        }
    }
    
    // MARK: - Category Breakdown Chart
    private func categoryBreakdownChart(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Category Breakdown")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            if categoryData.isEmpty {
                emptyStateView(message: "No category spending data available")
            } else {
                VStack(spacing: 20) {
                    // Pie Chart
                    Chart(categoryData) { data in
                        SectorMark(
                            angle: .value("Amount", data.doubleAmount),
                            innerRadius: .ratio(0.4),
                            angularInset: 2
                        )
                        .foregroundStyle(data.category.color)
                        .opacity(0.8)
                    }
                    .frame(height: min(height * 0.8, 250))
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .accessibilityLabel("Category spending breakdown pie chart")
                    .accessibilityValue(categoryBreakdownAccessibilityDescription)
                    
                    // Category List
                    categoryListView
                }
            }
        }
    }
    
    // MARK: - Category List View
    private var categoryListView: some View {
        VStack(spacing: 12) {
            ForEach(categoryData.sorted { $0.amount > $1.amount }, id: \.category) { data in
                HStack(spacing: 12) {
                    // Category Icon
                    Image(systemName: data.category.systemIcon)
                        .font(.title3)
                        .foregroundColor(data.category.color)
                        .frame(width: 24, height: 24)
                    
                    // Category Name
                    Text(data.category.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    // Percentage
                    Text(String(format: "%.1f%%", data.percentage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                    
                    // Amount
                    Text(formatCurrency(data.amount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(data.category.displayName): \(formatCurrency(data.amount)), \(String(format: "%.1f", data.percentage)) percent of total spending")
            }
        }
    }
    
    // MARK: - Trend Summary View
    private var trendSummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trend Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let currentMonth = monthlyData.last,
               let previousMonth = monthlyData.dropLast().last {
                let change = currentMonth.amount - previousMonth.amount
                let changePercentage = previousMonth.amount > 0 ? (change / previousMonth.amount) * 100 : 0
                
                HStack(spacing: 8) {
                    Image(systemName: change >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundColor(change >= 0 ? .red : .green)
                    
                    Text(change >= 0 ? "Increased by" : "Decreased by")
                        .font(.subheadline)
                    
                    Text("\(formatCurrency(abs(change))) (\(String(format: "%.1f", NSDecimalNumber(decimal: abs(changePercentage)).doubleValue))%)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("from last month")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Spending \(change >= 0 ? "increased" : "decreased") by \(formatCurrency(abs(change))) or \(String(format: "%.1f", NSDecimalNumber(decimal: abs(changePercentage)).doubleValue)) percent from last month")
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Empty State View
    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityLabel(message)
    }
    
    // MARK: - Helper Methods
    private func loadChartData() {
        isLoading = true
        
        switch selectedChartType {
        case .monthlyTrend:
            loadMonthlyTrendData()
        case .categoryBreakdown:
            loadCategoryBreakdownData()
        }
        isLoading = false
    }
    
    private func loadMonthlyTrendData() {
        monthlyData = []
        let calendar = Calendar.current
        let now = Date()
        
        // Generate data for past 6 months
        for i in (0..<6).reversed() {
            if let monthDate = calendar.date(byAdding: .month, value: -i, to: now) {
                let monthFormatter = DateFormatter()
                monthFormatter.dateFormat = "MMM"
                let monthName = monthFormatter.string(from: monthDate)
                
                // Get spending for this month using DataManager
                let monthlySpending = dataManager.getMonthlySpending(for: monthDate)
                let totalAmount: Decimal = monthlySpending.values.reduce(Decimal(0), +)
                
                monthlyData.append(MonthlySpendingData(
                    month: monthName,
                    amount: totalAmount,
                    date: monthDate
                ))
            }
        }
    }
    
    private func loadCategoryBreakdownData() {
        categoryData = []
        let currentMonthSpending = dataManager.getMonthlySpending()
        let totalSpending = currentMonthSpending.values.reduce(0, +)
        
        if totalSpending > 0 {
            for (category, amount) in currentMonthSpending {
                let percentageDecimal = (amount / totalSpending) * 100
                let percentageDouble = NSDecimalNumber(decimal: percentageDecimal).doubleValue
                categoryData.append(CategorySpendingData(
                    category: category,
                    amount: amount,
                    percentage: percentageDouble
                ))
            }
        }
    }
    
    private func lineColor(for amount: Decimal) -> Color {
        let maxAmount = monthlyData.map { $0.amount }.max() ?? 0
        guard maxAmount > 0 else { return .gray }
        let ratio = amount / maxAmount
        
        if ratio < 0.33 {
            return .green
        } else if ratio < 0.66 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        return Self.currencyFormatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    
    private var monthlyTrendAccessibilityDescription: String {
        let descriptions = monthlyData.map { data in
            "\(data.month): \(formatCurrency(data.amount))"
        }
        return "Monthly spending: " + descriptions.joined(separator: ", ")
    }
    
    private var categoryBreakdownAccessibilityDescription: String {
        let descriptions = categoryData.sorted { $0.amount > $1.amount }.map { data in
            "\(data.category.displayName): \(formatCurrency(data.amount)) (\(String(format: "%.1f", data.percentage))%)"
        }
        return "Category breakdown: " + descriptions.joined(separator: ", ")
    }
}

// MARK: - Data Models
struct MonthlySpendingData: Identifiable {
    let id = UUID()
    let month: String
    let amount: Decimal
    let date: Date
    
    var doubleAmount: Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }
}

struct CategorySpendingData: Identifiable {
    let id = UUID()
    let category: TransactionCategory
    let amount: Decimal
    let percentage: Double
    
    var doubleAmount: Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }
}

// MARK: - Extensions
extension View {
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V {
        block(self)
    }
}


// MARK: - Preview
struct SpendingChartView_Previews: PreviewProvider {
    static var previews: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Transaction.self, Budget.self, configurations: config)
        let context = container.mainContext
        let dataManager = DataManager(modelContext: context)
        
        NavigationView {
            SpendingChartView(dataManager: dataManager)
        }
        .previewDisplayName("iPhone")
        
        NavigationView {
            SpendingChartView(dataManager: dataManager)
        }
        .previewDevice("iPad Pro (12.9-inch) (6th generation)")
        .previewDisplayName("iPad")
        
        NavigationView {
            SpendingChartView(dataManager: dataManager)
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}
