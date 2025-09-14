import Foundation
import SwiftUI
import Combine

@MainActor
class TransactionHistoryViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var searchText = ""
    private var debouncedSearchText = ""
    @Published var isBackendSyncing: Bool = false
    @Published var lastBackendSync: Date?

    @Published var selectedCategories: Set<TransactionCategory> = [] {
        didSet {
            guard !isBatchUpdating else { return }
            updateFilteredTransactions()
        }
    }

    @Published var startDate: Date? = nil {
        didSet {
            guard !isBatchUpdating else { return }
            updateFilteredTransactions()
        }
    }

    @Published var endDate: Date? = nil {
        didSet {
            guard !isBatchUpdating else { return }
            updateFilteredTransactions()
        }
    }

    @Published var minAmount: Decimal? = nil {
        didSet {
            guard !isBatchUpdating else { return }
            updateFilteredTransactions()
        }
    }

    @Published var maxAmount: Decimal? = nil {
        didSet {
            guard !isBatchUpdating else { return }
            updateFilteredTransactions()
        }
    }

    @Published var groupingMode: GroupingMode = .day {
        didSet {
            updateGroupedTransactions()
        }
    }

    @Published private(set) var filteredTransactions: [Transaction] = []
    @Published private(set) var groupedTransactions: [String: [Transaction]] = [:]
    private var _internalGroupedTransactions: [GroupKey: [Transaction]] = [:]

    // MARK: - Dependencies

    let dataManager: DataManager
    private var cancellables = Set<AnyCancellable>()
    private var isBatchUpdating = false

    // MARK: - Types

    enum GroupingMode: String, CaseIterable {
        case day = "day"
        case week = "week"
        case month = "month"

        var displayName: String {
            switch self {
            case .day:
                return "Day"
            case .week:
                return "Week"
            case .month:
                return "Month"
            }
        }
    }

    struct GroupKey: Hashable {
        let anchor: Date
        let display: String
    }

    struct FilterCriteria {
        let categories: Set<TransactionCategory>
        let startDate: Date?
        let endDate: Date?
        let minAmount: Decimal?
        let maxAmount: Decimal?

        init(categories: Set<TransactionCategory> = [],
             startDate: Date? = nil,
             endDate: Date? = nil,
             minAmount: Decimal? = nil,
             maxAmount: Decimal? = nil) {
            self.categories = categories
            self.startDate = startDate
            self.endDate = endDate
            self.minAmount = minAmount
            self.maxAmount = maxAmount
        }
    }

    // MARK: - Initialization

    init(dataManager: DataManager) {
        self.dataManager = dataManager

        // Initial data load
        self.filteredTransactions = dataManager.transactions
        updateGroupedTransactions()

        // Observe changes to dataManager.transactions
        dataManager.$transactions
            .sink { [weak self] transactions in
                self?.handleTransactionsUpdate(transactions)
            }
            .store(in: &cancellables)


        // Bind searchText to debouncedSearchText with debouncing
        $searchText
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.debouncedSearchText = searchText
                self?.updateFilteredTransactions()
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Properties

    var hasActiveFilters: Bool {
        return !searchText.isEmpty ||
               !selectedCategories.isEmpty ||
               startDate != nil ||
               endDate != nil ||
               minAmount != nil ||
               maxAmount != nil
    }

    var filterCriteria: FilterCriteria {
        return FilterCriteria(
            categories: selectedCategories,
            startDate: startDate,
            endDate: endDate,
            minAmount: minAmount,
            maxAmount: maxAmount
        )
    }

    var sortedGroupKeys: [GroupKey] {
        return _internalGroupedTransactions.keys.sorted { key1, key2 in
            // Sort groups chronologically with most recent first (by anchor date)
            return key1.anchor > key2.anchor
        }
    }

    var sortedGroupDisplayStrings: [String] {
        return sortedGroupKeys.map { $0.display }
    }

    // MARK: - Public Methods

    func syncWithBackend() async {
        isBackendSyncing = true
        await dataManager.syncWithBackend()
        lastBackendSync = dataManager.getLastBackendSyncTime()
        isBackendSyncing = false
    }

    func clearFilters() {
        isBatchUpdating = true
        searchText = ""
        selectedCategories.removeAll()
        startDate = nil
        endDate = nil
        minAmount = nil
        maxAmount = nil
        isBatchUpdating = false
        updateFilteredTransactions()
    }

    func toggleCategoryFilter(_ category: TransactionCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    func setDateRange(start: Date?, end: Date?) {
        startDate = start
        endDate = end
    }

    func setAmountRange(min: Decimal?, max: Decimal?) {
        minAmount = min
        maxAmount = max
    }

    // MARK: - Private Methods

    private func handleTransactionsUpdate(_ transactions: [Transaction]) {
        updateFilteredTransactions()
    }

    func getTransactionDataSource(_ transaction: Transaction) -> String {
        if transaction.isFromBackend {
            return "AI Service"
        } else if transaction.isFromLocal {
            return "Local"
        } else {
            return "Unknown"
        }
    }

    func getLastBackendSyncTime() -> Date? {
        // Find the most recent backend sync date from transactions
        let backendTransactions = dataManager.transactions.filter { $0.isFromBackend }
        return backendTransactions.compactMap { $0.backendSyncDate }.max()
    }

    private func updateFilteredTransactions() {
        let criteria = filterCriteria
        var filtered = dataManager.transactions

        // Apply search filter using debounced debouncedSearchText
        if !debouncedSearchText.isEmpty {
            filtered = filtered.filter { transaction in
                transaction.description.localizedCaseInsensitiveContains(debouncedSearchText) ||
                transaction.merchantName?.localizedCaseInsensitiveContains(debouncedSearchText) == true
            }
        }

        // Apply category filter using FilterCriteria
        if !criteria.categories.isEmpty {
            filtered = filtered.filter { transaction in
                criteria.categories.contains(transaction.category)
            }
        }

        // Apply date range filter - normalize if startDate > endDate
        var normalizedStartDate = criteria.startDate
        var normalizedEndDate = criteria.endDate
        
        if let start = normalizedStartDate, let end = normalizedEndDate, start > end {
            // Swap dates if startDate > endDate
            normalizedStartDate = end
            normalizedEndDate = start
        }
        
        if let startDate = normalizedStartDate {
            filtered = filtered.filter { transaction in
                transaction.date >= startDate
            }
        }

        if let endDate = normalizedEndDate {
            // Normalize end date to end-of-day for expected UX
            let normalizedEndOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
            filtered = filtered.filter { transaction in
                transaction.date <= normalizedEndOfDay
            }
        }

        // Apply amount range filter - normalize if minAmount > maxAmount
        // Amount filtering uses absolute values to filter by transaction magnitude regardless of debit/credit
        var normalizedMinAmount = criteria.minAmount
        var normalizedMaxAmount = criteria.maxAmount
        
        if let min = normalizedMinAmount, let max = normalizedMaxAmount, min > max {
            // Swap amounts if minAmount > maxAmount
            normalizedMinAmount = max
            normalizedMaxAmount = min
        }
        
        if let minAmount = normalizedMinAmount {
            filtered = filtered.filter { transaction in
                let magnitude = transaction.amount < 0 ? -transaction.amount : transaction.amount
                return magnitude >= minAmount
            }
        }

        if let maxAmount = normalizedMaxAmount {
            filtered = filtered.filter { transaction in
                let magnitude = transaction.amount < 0 ? -transaction.amount : transaction.amount
                return magnitude <= maxAmount
            }
        }

        filteredTransactions = filtered
        updateGroupedTransactions()
    }

    private func updateGroupedTransactions() {
        let calendar = Calendar.current
        var internalGrouped: [GroupKey: [Transaction]] = [:]
        var displayGrouped: [String: [Transaction]] = [:]

        for transaction in filteredTransactions {
            let groupKey = groupKeyForTransaction(transaction, groupingMode: groupingMode, calendar: calendar)

            if internalGrouped[groupKey] == nil {
                internalGrouped[groupKey] = []
            }
            internalGrouped[groupKey]?.append(transaction)
        }

        // Sort transactions within each group by date (most recent first)
        for key in internalGrouped.keys {
            internalGrouped[key]?.sort { $0.date > $1.date }
            // Create display mapping using display string as key
            displayGrouped[key.display] = internalGrouped[key]
        }

        _internalGroupedTransactions = internalGrouped
        groupedTransactions = displayGrouped
    }

    private func groupKeyForTransaction(_ transaction: Transaction, groupingMode: GroupingMode, calendar: Calendar) -> GroupKey {
        let transactionDate = transaction.date

        switch groupingMode {
        case .day:
            let anchor = calendar.startOfDay(for: transactionDate)
            if calendar.isDateInToday(transactionDate) {
                return GroupKey(anchor: anchor, display: "Today")
            } else if calendar.isDateInYesterday(transactionDate) {
                return GroupKey(anchor: anchor, display: "Yesterday")
            } else {
                let display = transactionDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
                return GroupKey(anchor: anchor, display: display)
            }

        case .week:
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: transactionDate) {
                let anchor = weekInterval.start
                if calendar.dateInterval(of: .weekOfYear, for: Date())?.start == weekInterval.start {
                    return GroupKey(anchor: anchor, display: "This Week")
                } else if let lastWeekInterval = calendar.dateInterval(of: .weekOfYear, for: calendar.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()),
                          lastWeekInterval.start == weekInterval.start {
                    return GroupKey(anchor: anchor, display: "Last Week")
                } else {
                    let startOfWeek = weekInterval.start
                    let display = "Week of \(startOfWeek.formatted(.dateTime.month(.abbreviated).day()))"
                    return GroupKey(anchor: anchor, display: display)
                }
            } else {
                let anchor = calendar.startOfDay(for: transactionDate)
                let display = transactionDate.formatted(.dateTime.month(.abbreviated).day())
                return GroupKey(anchor: anchor, display: display)
            }

        case .month:
            guard let monthInterval = calendar.dateInterval(of: .month, for: transactionDate) else {
                let anchor = calendar.startOfDay(for: transactionDate)
                let display = transactionDate.formatted(.dateTime.month(.wide).year())
                return GroupKey(anchor: anchor, display: display)
            }

            let anchor = monthInterval.start
            let currentMonth = calendar.component(.month, from: Date())
            let currentYear = calendar.component(.year, from: Date())
            let transactionMonth = calendar.component(.month, from: transactionDate)
            let transactionYear = calendar.component(.year, from: transactionDate)

            if transactionMonth == currentMonth && transactionYear == currentYear {
                return GroupKey(anchor: anchor, display: "This Month")
            } else if let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) {
                let lastMonthMonth = calendar.component(.month, from: lastMonth)
                let lastMonthYear = calendar.component(.year, from: lastMonth)
                if transactionMonth == lastMonthMonth && transactionYear == lastMonthYear {
                    return GroupKey(anchor: anchor, display: "Last Month")
                }
            }

            let display = transactionDate.formatted(.dateTime.month(.wide).year())
            return GroupKey(anchor: anchor, display: display)
        }
    }
}
