import SwiftUI
import SwiftData

struct TransactionEditView: View {
    let transaction: Transaction?
    let dataManager: DataManager
    let onDismiss: () -> Void

    @State private var amount: String = ""
    @State private var description: String = ""
    @State private var selectedCategory: TransactionCategory = .other
    @State private var date: Date = Date()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingDeleteConfirmation = false

    private var isEditing: Bool {
        transaction != nil
    }

    private var navigationTitle: String {
        isEditing ? "Edit Transaction" : "New Transaction"
    }

    private var saveButtonText: String {
        isEditing ? "Update" : "Save"
    }

    private var isFormValid: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !amount.isEmpty &&
        Decimal(string: amount) != nil &&
        Decimal(string: amount) != 0
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Transaction Details") {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    HStack {
                        Text("Description")
                        TextField("Enter description", text: $description)
                            .multilineTextAlignment(.trailing)
                    }

                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Category") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(TransactionCategory.allCases, id: \.self) { category in
                            CategorySelectionButton(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                if isEditing {
                    Section {
                        Button("Delete Transaction") {
                            showingDeleteConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(saveButtonText) {
                        Task {
                            await saveTransaction()
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .onAppear {
                loadTransactionData()
            }
            .alert("Delete Transaction", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteTransaction()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this transaction? This action cannot be undone.")
            }
        }
    }

    private func loadTransactionData() {
        guard let transaction = transaction else { return }

        amount = NSDecimalNumber(decimal: transaction.amount).stringValue
        description = transaction.description
        selectedCategory = transaction.category
        date = transaction.date
    }

    @MainActor
    private func saveTransaction() async {
        guard isFormValid else { return }

        isLoading = true
        errorMessage = nil

        do {
            guard let amountDecimal = Decimal(string: amount) else {
                errorMessage = "Please enter a valid amount"
                isLoading = false
                return
            }

            let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

            if let existingTransaction = transaction {
                existingTransaction.amount = amountDecimal
                existingTransaction.description = trimmedDescription
                existingTransaction.category = selectedCategory
                existingTransaction.date = date

                let success = await dataManager.updateTransaction(existingTransaction)
                if success {
                    onDismiss()
                } else {
                    errorMessage = "Failed to update transaction. Please try again."
                }
            } else {
                let newTransaction = try Transaction(
                    amount: amountDecimal,
                    description: trimmedDescription,
                    category: selectedCategory,
                    date: date
                )

                let success = await dataManager.saveTransaction(newTransaction)
                if success {
                    onDismiss()
                } else {
                    errorMessage = "Failed to save transaction. Please try again."
                }
            }
        } catch Transaction.TransactionError.zeroAmount {
            errorMessage = "Transaction amount cannot be zero"
        } catch Transaction.TransactionError.emptyDescription {
            errorMessage = "Transaction description cannot be empty"
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }

        isLoading = false
    }

    @MainActor
    private func deleteTransaction() async {
        guard let transaction = transaction else { return }

        isLoading = true
        errorMessage = nil

        let success = await dataManager.deleteTransaction(transaction)
        if success {
            onDismiss()
        } else {
            errorMessage = "Failed to delete transaction. Please try again."
            isLoading = false
        }
    }
}

struct CategorySelectionButton: View {
    let category: TransactionCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.systemIcon)
                    .foregroundColor(isSelected ? .white : category.color)
                    .frame(width: 20)

                Text(category.displayName)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? category.color : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#if DEBUG
#Preview("New Transaction") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Transaction.self, Budget.self, configurations: config)
    let dataManager = DataManager(modelContext: container.mainContext)

    TransactionEditView(transaction: nil, dataManager: dataManager) {
        // Dismiss action
    }
}

#Preview("Edit Transaction") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Transaction.self, Budget.self, configurations: config)
    let dataManager = DataManager(modelContext: container.mainContext)

    let sampleTransaction = try! Transaction(
        amount: 25.50,
        description: "Coffee and Pastry",
        category: .dining,
        date: Date()
    )

    TransactionEditView(transaction: sampleTransaction, dataManager: dataManager) {
        // Dismiss action
    }
}
#endif