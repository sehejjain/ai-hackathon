//
//  DataManagementView.swift
//  SpendConscience
//
//  Data backup, restore, and maintenance interface
//

import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingBackupShare = false
    @State private var showingFileImporter = false
    @State private var showingMaintenanceResults = false
    @State private var isPerformingMaintenance = false
    @State private var backupData: Data?
    @State private var validationResult: DataValidationResult?
    @State private var storageInfo: StorageInfo?
    @State private var maintenanceResult: DataMaintenanceResult?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // Storage Information Section
                if let storageInfo = storageInfo {
                    storageInfoSection(storageInfo)
                }
                
                // Data Validation Section
                if let validationResult = validationResult {
                    validationSection(validationResult)
                }
                
                // Backup & Export Section
                backupSection
                
                // Restore & Import Section
                restoreSection
                
                // Maintenance Section
                maintenanceSection
                
                // Advanced Options Section
                advancedSection
            }
            .navigationTitle("Data Management")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadStorageInfo()
                performValidation()
            }
            .sheet(isPresented: $showingBackupShare) {
                if let backupData = backupData {
                    ShareSheet(activityItems: [backupData])
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            .sheet(isPresented: $showingMaintenanceResults) {
                if let maintenanceResult = maintenanceResult {
                    MaintenanceResultsView(result: maintenanceResult)
                }
            }
            .alert("Data Management", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Storage Information Section
    
    private func storageInfoSection(_ info: StorageInfo) -> some View {
        Section("Storage Information") {
            HStack {
                Label("Transactions", systemImage: "creditcard")
                Spacer()
                Text("\(info.transactionCount)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("Budgets", systemImage: "chart.pie")
                Spacer()
                Text("\(info.budgetCount)")
                    .foregroundColor(.secondary)
            }
            
            if let oldestDate = info.oldestTransactionDate {
                HStack {
                    Label("Data From", systemImage: "calendar")
                    Spacer()
                    Text(oldestDate.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Label("Storage Size", systemImage: "internaldrive")
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: Int64(info.estimatedStorageSize), countStyle: .file))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Validation Section
    
    private func validationSection(_ result: DataValidationResult) -> some View {
        Section("Data Validation") {
            HStack {
                if result.isValid {
                    Label("All Data Valid", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Label("\(result.issues.count) Issues Found", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(result.hasErrors ? .red : .orange)
                }
                Spacer()
            }
            
            if !result.issues.isEmpty {
                ForEach(Array(result.issues.enumerated()), id: \.offset) { index, issue in
                    issueRow(issue)
                }
            }
            
            Button("Re-validate Data") {
                performValidation()
            }
            .disabled(dataManager.isLoading)
        }
    }
    
    private func issueRow(_ issue: DataValidationIssue) -> some View {
        HStack {
            Image(systemName: issue.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(issue.severity == .error ? .red : .orange)
            
            VStack(alignment: .leading, spacing: 2) {
                switch issue {
                case .invalidTransaction(let id, let reason):
                    Text("Invalid Transaction")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                case .invalidBudget(let id, let reason):
                    Text("Invalid Budget")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                case .suspiciousTransaction(let id, let reason):
                    Text("Suspicious Transaction")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                case .duplicateBudgetCategory(let category, let budgetIds):
                    Text("Duplicate Budget Category")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(category.displayName) has \(budgetIds.count) budgets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                case .dataAccessError(let error):
                    Text("Data Access Error")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Backup Section
    
    private var backupSection: some View {
        Section("Backup & Export") {
            Button(action: createBackup) {
                Label("Export Data Backup", systemImage: "square.and.arrow.up")
            }
            .disabled(dataManager.isLoading)
            
            Button(action: shareData) {
                Label("Share Data (JSON)", systemImage: "square.and.arrow.up.on.square")
            }
            .disabled(dataManager.isLoading)
        }
    }
    
    // MARK: - Restore Section
    
    private var restoreSection: some View {
        Section("Restore & Import") {
            Button(action: { showingFileImporter = true }) {
                Label("Import Data Backup", systemImage: "square.and.arrow.down")
            }
            .disabled(dataManager.isLoading)
        }
    }
    
    // MARK: - Maintenance Section
    
    private var maintenanceSection: some View {
        Section("Maintenance") {
            Button(action: performMaintenance) {
                HStack {
                    if isPerformingMaintenance {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Running Maintenance...")
                    } else {
                        Label("Run Data Maintenance", systemImage: "gear")
                    }
                }
            }
            .disabled(dataManager.isLoading || isPerformingMaintenance)
            
            if maintenanceResult != nil {
                Button("View Last Results") {
                    showingMaintenanceResults = true
                }
            }
        }
    }
    
    // MARK: - Advanced Section
    
    private var advancedSection: some View {
        Section("Advanced") {
            Button(action: confirmClearAllData) {
                Label("Clear All Data", systemImage: "trash")
            }
            .foregroundColor(.red)
            .disabled(dataManager.isLoading)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadStorageInfo() {
        Task {
            let info = await dataManager.getStorageInfo()
            await MainActor.run {
                self.storageInfo = info
            }
        }
    }
    
    private func performValidation() {
        Task {
            let result = await dataManager.validateDataIntegrity()
            await MainActor.run {
                self.validationResult = result
            }
        }
    }
    
    private func createBackup() {
        Task {
            if let data = await dataManager.exportDataAsJSON() {
                await MainActor.run {
                    self.backupData = data
                    self.showingBackupShare = true
                }
            } else {
                await MainActor.run {
                    self.alertMessage = "Failed to create backup"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func shareData() {
        createBackup()
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            Task {
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let backup = try decoder.decode(DataBackup.self, from: data)
                    
                    let success = await dataManager.restoreFromBackup(backup)
                    
                    await MainActor.run {
                        if success {
                            self.alertMessage = "Data successfully restored from backup"
                            // Refresh info after restoration
                            self.loadStorageInfo()
                            self.performValidation()
                        } else {
                            self.alertMessage = "Failed to restore data from backup"
                        }
                        self.showingAlert = true
                    }
                } catch {
                    await MainActor.run {
                        self.alertMessage = "Invalid backup file: \(error.localizedDescription)"
                        self.showingAlert = true
                    }
                }
            }
            
        case .failure(let error):
            alertMessage = "Failed to import file: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func performMaintenance() {
        isPerformingMaintenance = true
        
        Task {
            let result = await dataManager.performDataMaintenance()
            
            await MainActor.run {
                self.isPerformingMaintenance = false
                self.maintenanceResult = result
                self.showingMaintenanceResults = true
                
                // Refresh info after maintenance
                self.loadStorageInfo()
                self.performValidation()
            }
        }
    }
    
    private func confirmClearAllData() {
        // This would show a confirmation alert in a real implementation
        alertMessage = "This action cannot be undone. All your data will be permanently deleted."
        showingAlert = true
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Maintenance Results View

struct MaintenanceResultsView: View {
    let result: DataMaintenanceResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Validation Results") {
                    if let validation = result.validationResult {
                        if validation.isValid {
                            Label("All data is valid", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("\(validation.issues.count) issues found", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(validation.hasErrors ? .red : .orange)
                        }
                    }
                }
                
                Section("Cleanup Results") {
                    if let cleanup = result.cleanupResult {
                        if cleanup.success {
                            Label("Cleanup completed successfully", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            if cleanup.deletedTransactions > 0 {
                                Text("Removed \(cleanup.deletedTransactions) old transactions")
                            }
                            
                            if cleanup.deletedBudgets > 0 {
                                Text("Removed \(cleanup.deletedBudgets) invalid budgets")
                            }
                        } else {
                            Label("Cleanup failed", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section("Storage Information") {
                    if let storage = result.storageInfo {
                        HStack {
                            Text("Transactions")
                            Spacer()
                            Text("\(storage.transactionCount)")
                        }
                        
                        HStack {
                            Text("Budgets")
                            Spacer()
                            Text("\(storage.budgetCount)")
                        }
                        
                        HStack {
                            Text("Storage Size")
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: Int64(storage.estimatedStorageSize), countStyle: .file))
                        }
                    }
                }
            }
            .navigationTitle("Maintenance Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DataManagementView()
        .environmentObject(DataManager.preview())
}