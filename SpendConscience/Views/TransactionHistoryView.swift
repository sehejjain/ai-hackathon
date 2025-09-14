import SwiftUI
import SwiftData

struct TransactionHistoryView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var viewModel: TransactionHistoryViewModel?
    @State private var showingEditView = false
    @State private var selectedTransaction: Transaction?
    @State private var showingFilters = false
    @State private var transactionToDelete: Transaction?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Group {
            if let viewModel = viewModel {
                VStack(spacing: 0) {
                    searchBar(viewModel: viewModel)

                    if viewModel.hasActiveFilters {
                        activeFiltersBar(viewModel: viewModel)
                    }

                    transactionsList(viewModel: viewModel)
                }
                .navigationTitle("Transaction History")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                showingFilters = true
                            } label: {
                                Label("Filters", systemImage: "line.horizontal.3.decrease.circle")
                            }

                            Menu("Group By") {
                                ForEach(TransactionHistoryViewModel.GroupingMode.allCases, id: \.self) { mode in
                                    Button {
                                        viewModel.groupingMode = mode
                                    } label: {
                                        HStack {
                                            Text(mode.displayName)
                                            if viewModel.groupingMode == mode {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: $showingFilters) {
                    if let vm = self.viewModel {
                        FiltersView(viewModel: vm)
                    }
                }
                .sheet(item: $selectedTransaction) { transaction in
                    TransactionEditView(transaction: transaction, dataManager: dataManager) {
                        selectedTransaction = nil
                    }
                }
                .alert("Delete Transaction", isPresented: $showingDeleteConfirmation, presenting: transactionToDelete) { transaction in
                    Button("Cancel", role: .cancel) {
                        transactionToDelete = nil
                    }
                    Button("Delete", role: .destructive) {
                        Task {
                            _ = await dataManager.deleteTransaction(transaction)
                        }
                        transactionToDelete = nil
                    }
                } message: { transaction in
                    Text("Are you sure you want to delete this transaction? This action cannot be undone.")
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TransactionHistoryViewModel(dataManager: dataManager)
            }
        }
    }

    private func searchBar(viewModel: TransactionHistoryViewModel) -> some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search transactions...", text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.searchText = $0 }
            ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func activeFiltersBar(viewModel: TransactionHistoryViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !viewModel.searchText.isEmpty {
                    FilterChip(text: "Search: \(viewModel.searchText)", systemImage: "magnifyingglass") {
                        viewModel.searchText = ""
                    }
                }

                if !viewModel.selectedCategories.isEmpty {
                    let categoryText = viewModel.selectedCategories.count == 1
                        ? viewModel.selectedCategories.first?.displayName ?? ""
                        : "\(viewModel.selectedCategories.count) Categories"
                    FilterChip(text: categoryText, systemImage: "tag") {
                        viewModel.selectedCategories.removeAll()
                    }
                }

                if viewModel.startDate != nil || viewModel.endDate != nil {
                    FilterChip(text: "Date Range", systemImage: "calendar") {
                        viewModel.setDateRange(start: nil, end: nil)
                    }
                }

                if viewModel.minAmount != nil || viewModel.maxAmount != nil {
                    FilterChip(text: "Amount Range", systemImage: "dollarsign.circle") {
                        viewModel.setAmountRange(min: nil, max: nil)
                    }
                }

                Button("Clear All") {
                    viewModel.clearFilters()
                }
                .foregroundColor(.red)
                .font(.caption)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
    }

    private func transactionsList(viewModel: TransactionHistoryViewModel) -> some View {
        Group {
            if viewModel.filteredTransactions.isEmpty {
                EmptyStateView(hasFilters: viewModel.hasActiveFilters)
            } else {
                List {
                    ForEach(viewModel.sortedGroupDisplayStrings, id: \.self) { groupName in
                        Section(header: Text(groupName)) {
                            ForEach(viewModel.groupedTransactions[groupName] ?? [], id: \.id) { transaction in
                                SwiftDataTransactionRowView(transaction: transaction)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedTransaction = transaction
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button("Delete") {
                                            transactionToDelete = transaction
                                            showingDeleteConfirmation = true
                                        }
                                        .tint(.red)

                                        Button("Edit") {
                                            selectedTransaction = transaction
                                        }
                                        .tint(.blue)
                                    }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .refreshable {
                    await viewModel.dataManager.loadAllData()
                }
            }
        }
    }
}

struct FilterChip: View {
    let text: String
    let systemImage: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption)
            Text(text)
                .font(.caption)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBlue).opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(12)
    }
}

struct FiltersView: View {
    @ObservedObject var viewModel: TransactionHistoryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var tempStartDate: Date?
    @State private var tempEndDate: Date?
    @State private var tempMinAmount: String = ""
    @State private var tempMaxAmount: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Categories") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(TransactionCategory.allCases, id: \.self) { category in
                            CategoryFilterButton(
                                category: category,
                                isSelected: viewModel.selectedCategories.contains(category)
                            ) {
                                viewModel.toggleCategoryFilter(category)
                            }
                        }
                    }
                }

                Section("Date Range") {
                    DatePicker("Start Date", selection: Binding(
                        get: { tempStartDate ?? viewModel.startDate ?? Date() },
                        set: { tempStartDate = $0 }
                    ), displayedComponents: .date)
                    .onChange(of: tempStartDate) { _, newValue in
                        viewModel.startDate = newValue
                    }

                    DatePicker("End Date", selection: Binding(
                        get: { tempEndDate ?? viewModel.endDate ?? Date() },
                        set: { tempEndDate = $0 }
                    ), displayedComponents: .date)
                    .onChange(of: tempEndDate) { _, newValue in
                        viewModel.endDate = newValue
                    }

                    Button("Clear Date Range") {
                        viewModel.setDateRange(start: nil, end: nil)
                        tempStartDate = nil
                        tempEndDate = nil
                    }
                    .foregroundColor(.red)
                }

                Section("Amount Range") {
                    HStack {
                        Text("Min:")
                        TextField("0.00", text: $tempMinAmount)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .onChange(of: tempMinAmount) { _, newValue in
                                if let decimal = Decimal(string: newValue), decimal >= 0 {
                                    viewModel.minAmount = decimal
                                } else if newValue.isEmpty {
                                    viewModel.minAmount = nil
                                }
                            }
                    }

                    HStack {
                        Text("Max:")
                        TextField("0.00", text: $tempMaxAmount)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .onChange(of: tempMaxAmount) { _, newValue in
                                if let decimal = Decimal(string: newValue), decimal >= 0 {
                                    viewModel.maxAmount = decimal
                                } else if newValue.isEmpty {
                                    viewModel.maxAmount = nil
                                }
                            }
                    }

                    Button("Clear Amount Range") {
                        viewModel.setAmountRange(min: nil, max: nil)
                        tempMinAmount = ""
                        tempMaxAmount = ""
                    }
                    .foregroundColor(.red)
                }

                Section {
                    Button("Clear All Filters") {
                        viewModel.clearFilters()
                        tempStartDate = nil
                        tempEndDate = nil
                        tempMinAmount = ""
                        tempMaxAmount = ""
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            tempStartDate = viewModel.startDate
            tempEndDate = viewModel.endDate
            tempMinAmount = viewModel.minAmount?.description ?? ""
            tempMaxAmount = viewModel.maxAmount?.description ?? ""
        }
    }
}

struct CategoryFilterButton: View {
    let category: TransactionCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: category.systemIcon)
                    .foregroundColor(isSelected ? .white : category.color)
                Text(category.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? category.color : Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct EmptyStateView: View {
    let hasFilters: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: hasFilters ? "line.horizontal.3.decrease.circle" : "creditcard")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(hasFilters ? "No Transactions Found" : "No Transactions")
                .font(.title2)
                .fontWeight(.semibold)

            Text(hasFilters ?
                "Try adjusting your search or filters to find transactions." :
                "Your transaction history will appear here once you start adding transactions.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#if DEBUG
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Transaction.self, Budget.self, configurations: config)
    let dataManager = DataManager(modelContext: container.mainContext)

    TransactionHistoryView()
        .environmentObject(dataManager)
}
#endif
