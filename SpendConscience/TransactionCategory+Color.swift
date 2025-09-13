import SwiftUI

extension TransactionCategory {
    var color: Color {
        switch self {
        case .dining:
            return .orange
        case .groceries:
            return .green
        case .entertainment:
            return .purple
        case .transportation:
            return .blue
        case .shopping:
            return .pink
        case .utilities:
            return .yellow
        case .other:
            return .gray
        }
    }
}