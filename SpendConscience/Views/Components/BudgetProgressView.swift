import SwiftUI

struct BudgetProgressView: View {
    let budget: Budget
    let ringSize: CGFloat
    let lineWidth: CGFloat
    
    @Environment(\.navigate) private var navigate
    
    init(budget: Budget, ringSize: CGFloat = 120, lineWidth: CGFloat = 8) {
        self.budget = budget
        self.ringSize = ringSize
        self.lineWidth = lineWidth
    }
    
    // Static currency formatter for locale-aware formatting
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }()
    
    // Helper function to format currency from Decimal
    private func formatCurrency(_ amount: Decimal) -> String {
        let nsDecimalNumber = NSDecimalNumber(decimal: amount)
        return Self.currencyFormatter.string(from: nsDecimalNumber) ?? "$0.00"
    }

    // Comment 2: Extract repeated percentage calculation into a computed property
    private var percentUsed: Int { 
        Int(round(budget.utilizationPercentage * 100)) 
    }
    
    // Comment 3: Consider capping displayed percent at 100% while keeping textual overage
    private var displayPercent: Int { 
        min(100, percentUsed) 
    }

    // Comment 4: Prefer semantic system colors for better accessibility
    private var statusColor: Color {
        switch budget.status {
        case .safe:
            return Color(.systemGreen)
        case .warning:
            return Color(.systemOrange)
        case .danger:
            return Color(.systemRed)
        }
    }

    private var progressValue: Double {
        max(0, min(1, budget.utilizationPercentage))
    }
    
    private var overByAmount: Decimal {
        max(0, budget.currentSpent - budget.monthlyLimit)
    }

    private var accessibilityLabel: String {
        let statusText = switch budget.status {
        case .safe: "Safe"
        case .warning: "Warning"
        case .danger: "Danger"
        }

        if budget.isOverBudget {
            return "\(budget.category.displayName) budget. \(statusText) status. \(percentUsed) percent used. Spent \(formatCurrency(budget.currentSpent)) of \(formatCurrency(budget.monthlyLimit)) limit. Over by \(formatCurrency(overByAmount))."
        } else {
            return "\(budget.category.displayName) budget. \(statusText) status. \(percentUsed) percent used. Spent \(formatCurrency(budget.currentSpent)) of \(formatCurrency(budget.monthlyLimit)) limit. \(formatCurrency(budget.remainingAmount)) remaining."
        }
    }

    var body: some View {
        Button(action: {
            navigate(.budgetDetail(budget))
        }) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: budget.category.systemIcon)
                        .foregroundColor(statusColor)
                        .font(.title2)

                    Text(budget.category.displayName)
                        .font(.headline)
                        .fontWeight(.medium)

                    Spacer()
                    
                    // Visual indicator that the view is tappable
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(0.6)
                }

                ZStack {
                    Circle()
                        .stroke(statusColor.opacity(0.2), lineWidth: lineWidth)
                        .frame(width: ringSize, height: ringSize)

                    Circle()
                        .trim(from: 0, to: progressValue)
                        .stroke(statusColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: progressValue)

                    VStack(spacing: 4) {
                        Text("\(displayPercent)%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(statusColor)

                        Text(budget.status == .danger ? "Over Budget" : "Used")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(spacing: 8) {
                    HStack {
                        Text("Spent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatCurrency(budget.currentSpent))
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Limit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatCurrency(budget.monthlyLimit))
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    Divider()

                    HStack {
                        Text(budget.isOverBudget ? "Over by" : "Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(budget.isOverBudget ? formatCurrency(overByAmount) : formatCurrency(budget.remainingAmount))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(budget.isOverBudget ? .red : .primary)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: statusColor.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(statusColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.35), value: budget.status)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel + " Tap to view budget details")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to view detailed budget information")
    }
}

#Preview {
    let sampleCategory = TransactionCategory.groceries
    let sampleBudget = try! Budget(
        category: sampleCategory,
        monthlyLimit: Decimal(500),
        currentSpent: Decimal(350)
    )

    return BudgetProgressView(budget: sampleBudget)
        .padding()
}

#Preview("Warning Status") {
    let sampleCategory = TransactionCategory.transportation
    let sampleBudget = try! Budget(
        category: sampleCategory,
        monthlyLimit: Decimal(300),
        currentSpent: Decimal(240)
    )

    return BudgetProgressView(budget: sampleBudget)
        .padding()
}

#Preview("Danger Status") {
    let sampleCategory = TransactionCategory.entertainment
    let sampleBudget = try! Budget(
        category: sampleCategory,
        monthlyLimit: Decimal(200),
        currentSpent: Decimal(220)
    )

    return BudgetProgressView(budget: sampleBudget)
        .padding()
}
