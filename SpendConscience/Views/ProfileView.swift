//
//  ProfileView.swift
//  SpendConscience
//
//  Created by AI Assistant
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject private var permissionManager: PermissionManager
    @EnvironmentObject private var plaidService: PlaidService
    @State private var showingSignOutAlert = false
    @State private var showPermissionSheet = false
    @State private var showExportAlert = false
    @State private var showPrivacySheet = false
    @State private var showPlaidOnboarding = false
    
    // App Storage for settings
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("budgetAlertsEnabled") private var budgetAlertsEnabled = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("syncEnabled") private var syncEnabled = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // User Profile Section
                VStack(spacing: 16) {
                    // Profile Image Placeholder
                    Circle()
                        .fill(Color.blue.gradient)
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                    
                    // User Information
                    if let user = userManager.currentUser {
                        VStack(spacing: 4) {
                            Text(user.fullName)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(spacing: 4) {
                            Text("Guest User")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("No email available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 20)
                
                // Permission Status Card - Comprehensive permission management
                VStack(spacing: 16) {
                    PermissionStatusCard(showPermissionSheet: $showPermissionSheet)
                        .padding(.horizontal)
                }
                
                // Bank Connection Section
                VStack(spacing: 16) {
                    BankConnectionCard(showPlaidOnboarding: $showPlaidOnboarding)
                        .padding(.horizontal)
                }
                
                // Profile Sections
                VStack(spacing: 16) {
                    // User Information Card
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Profile Information", systemImage: "person.circle")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if let user = userManager.currentUser {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Name:")
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(user.fullName)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("Email:")
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(user.email)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Name:")
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("Guest User")
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("Email:")
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("No email available")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .accessibilityLabel("User profile information")
                    
                    // Enhanced Settings Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Settings", systemImage: "gearshape")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 8) {
                                // Notifications Toggle
                                HStack {
                                    Image(systemName: "bell")
                                        .foregroundColor(.blue)
                                    Text("Notifications")
                                    Spacer()
                                    Toggle("", isOn: $notificationsEnabled)
                                        .labelsHidden()
                                }
                                
                                Divider()
                                
                                // Data Export
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundColor(.blue)
                                    Text("Data Export")
                                    Spacer()
                                    Button("Export") {
                                        showExportAlert = true
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                
                                Divider()
                                
                                // Data Management
                                NavigationLink(destination: DataManagementView()) {
                                    HStack {
                                        Image(systemName: "internaldrive")
                                            .foregroundColor(.blue)
                                        Text("Data Management")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Divider()
                                
                                // Privacy Settings
                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundColor(.blue)
                                    Text("Privacy Settings")
                                    Spacer()
                                    Button("View") {
                                        showPrivacySheet = true
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                
                                Divider()
                                
                                // App Version
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("App Version")
                                    Spacer()
                                    Text("1.0.0")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .accessibilityLabel("Settings section")
                    
                    // Enhanced Preferences Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Preferences", systemImage: "slider.horizontal.3")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 8) {
                                // Currency Display
                                HStack {
                                    Image(systemName: "dollarsign.circle")
                                        .foregroundColor(.green)
                                    Text("Currency")
                                    Spacer()
                                    Text("USD")
                                        .foregroundColor(.secondary)
                                }
                                
                                Divider()
                                
                                // Budget Period Display
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.green)
                                    Text("Budget Period")
                                    Spacer()
                                    Text("Monthly")
                                        .foregroundColor(.secondary)
                                }
                                
                                Divider()
                                
                                // Budget Alerts Toggle
                                HStack {
                                    Image(systemName: "chart.bar")
                                        .foregroundColor(.green)
                                    Text("Budget Alerts")
                                    Spacer()
                                    Toggle("", isOn: $budgetAlertsEnabled)
                                        .labelsHidden()
                                }
                                
                                Divider()
                                
                                // Dark Mode Toggle
                                HStack {
                                    Image(systemName: "paintbrush")
                                        .foregroundColor(.green)
                                    Text("Dark Mode")
                                    Spacer()
                                    Toggle("", isOn: $darkModeEnabled)
                                        .labelsHidden()
                                }
                                
                                Divider()
                                
                                // Sync Settings Toggle
                                HStack {
                                    Image(systemName: "icloud")
                                        .foregroundColor(.green)
                                    Text("Sync Settings")
                                    Spacer()
                                    Toggle("", isOn: $syncEnabled)
                                        .labelsHidden()
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .accessibilityLabel("Preferences section")
                    
                    // Sign Out Section
                    GroupBox {
                        VStack(spacing: 12) {
                            Button(action: {
                                showingSignOutAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundColor(.red)
                                    Text("Sign Out")
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .foregroundColor(.red)
                            }
                            .accessibilityLabel("Sign out of your account")
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await permissionManager.checkAllPermissionStatuses()
        }
        .sheet(isPresented: $showPermissionSheet) {
            PermissionRequestView()
        }
        .sheet(isPresented: $showPrivacySheet) {
            PrivacySettingsView()
        }
        .sheet(isPresented: $showPlaidOnboarding) {
            PlaidOnboardingView()
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                userManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Export Data", isPresented: $showExportAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Export") {
                // Placeholder for future data export implementation
                print("Data export requested")
            }
        } message: {
            Text("Export your transaction data and budgets. This feature will be available in a future update.")
        }
    }
}

// MARK: - Bank Connection Card

struct BankConnectionCard: View {
    @EnvironmentObject private var plaidService: PlaidService
    @Binding var showPlaidOnboarding: Bool
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Bank Connection", systemImage: "building.columns")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if plaidService.isPlaidLinked {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                    }
                }
                
                if plaidService.isPlaidLinked {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Status:")
                                .fontWeight(.medium)
                            Spacer()
                            Text("Connected")
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Accounts:")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(plaidService.linkedAccounts.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        if let lastSync = plaidService.lastSyncDate {
                            HStack {
                                Text("Last Sync:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(lastSync, style: .relative)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Button("Manage Accounts") {
                                // TODO: Navigate to account management
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Spacer()
                            
                            Button("Disconnect") {
                                // TODO: Show disconnect confirmation
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .foregroundColor(.red)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connect your bank account to get real-time transaction data and AI-powered financial insights.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Connect Bank Account") {
                            showPlaidOnboarding = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .accessibilityLabel("Bank connection status")
    }
}

// MARK: - Privacy Settings View

struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Privacy")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("SpendConscience is committed to protecting your privacy. Your financial data is stored securely on your device and is never shared with third parties without your explicit consent.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Data Storage", systemImage: "externaldrive")
                                .font(.headline)
                            
                            Text("• All transaction data is stored locally on your device\n• Budget information is encrypted and secure\n• No personal data is transmitted to external servers\n• You have full control over your financial information")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Permissions", systemImage: "shield.checkered")
                                .font(.headline)
                            
                            Text("• Calendar access is used only for budget reminders\n• Notifications help you stay on track with spending goals\n• No location data is collected or stored\n• Permissions can be revoked at any time in Settings")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Privacy")
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

#Preview {
    ProfileView()
        .environmentObject(UserManager())
        .environmentObject(PermissionManager())
}
