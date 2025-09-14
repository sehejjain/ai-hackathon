import Foundation

enum TransactionCategory: String, CaseIterable, Codable {
    case dining = "dining"
    case groceries = "groceries"
    case entertainment = "entertainment"
    case transportation = "transportation"
    case shopping = "shopping"
    case utilities = "utilities"
    case other = "other"

    var displayName: String {
        switch self {
        case .dining:
            return "Dining"
        case .groceries:
            return "Groceries"
        case .entertainment:
            return "Entertainment"
        case .transportation:
            return "Transportation"
        case .shopping:
            return "Shopping"
        case .utilities:
            return "Utilities"
        case .other:
            return "Other"
        }
    }

    var systemIcon: String {
        switch self {
        case .dining:
            return "fork.knife"
        case .groceries:
            return "cart"
        case .entertainment:
            return "gamecontroller"
        case .transportation:
            return "car"
        case .shopping:
            return "bag"
        case .utilities:
            return "bolt"
        case .other:
            return "questionmark.circle"
        }
    }


    var budgetPriority: Int {
        switch self {
        case .utilities:
            return 1
        case .groceries:
            return 2
        case .transportation:
            return 3
        case .dining:
            return 4
        case .shopping:
            return 5
        case .entertainment:
            return 6
        case .other:
            return 7
        }
    }
}