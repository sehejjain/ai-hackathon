//
//  PermissionComponents.swift
//  SpendConscience
//
//  Created by AI Assistant
//

import SwiftUI
import EventKit
import UserNotifications

// MARK: - Permission Status Enum

enum PermissionStatus {
    case notification(UNAuthorizationStatus)
    case calendar(EKAuthorizationStatus)
    
    var isGranted: Bool {
        switch self {
        case .notification(let status):
            return status == .authorized || status == .provisional
        case .calendar(let status):
            if #available(iOS 17.0, *) {
                return status == .fullAccess || status == .writeOnly
            } else {
                return status == .authorized
            }
        }
    }
}

// MARK: - Permission Request Sheet

struct PermissionRequestView: View {
    @EnvironmentObject private var permissionManager: PermissionManager
    @Environment(\.dismiss) private var dismiss
    @State private var isRequesting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Enable Smart Budget Features")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text("To provide the best budgeting experience, SpendConscience needs access to:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    PermissionItemView(
                        icon: "calendar",
                        title: "Calendar Access",
                        description: "Create budget reminders and schedule financial planning events",
                        status: .calendar(permissionManager.calendarStatus)
                    )
                    
                    PermissionItemView(
                        icon: "bell",
                        title: "Notifications",
                        description: "Receive timely alerts about budget limits and spending recommendations",
                        status: .notification(permissionManager.notificationStatus)
                    )
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    if permissionManager.notificationStatus == .denied || permissionManager.calendarStatus == .denied {
                        Button(action: openSettings) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Open Settings")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        Button(action: requestPermissions) {
                            HStack {
                                if isRequesting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isRequesting ? "Requesting..." : "Grant Permissions")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isRequesting)
                    }
                    
                    Button("Maybe Later") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func requestPermissions() {
        isRequesting = true
        Task {
            await permissionManager.requestPermissions()
            await MainActor.run {
                isRequesting = false
                dismiss()
            }
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
        dismiss()
    }
}

// MARK: - Permission Item View

struct PermissionItemView: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Image(systemName: status.isGranted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(status.isGranted ? .green : .gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Permission Status Card

struct PermissionStatusCard: View {
    @EnvironmentObject private var permissionManager: PermissionManager
    @Binding var showPermissionSheet: Bool
    
    private func openSettingsFromCard() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    var body: some View {
        if permissionManager.needsPermissions {
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("App Permissions")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Enable features for better budget management")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Permission Status List
                    VStack(spacing: 12) {
                        // Notification Permission
                        HStack {
                            Image(systemName: "bell")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Notifications")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Budget alerts and reminders")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: permissionManager.hasNotificationPermission ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(permissionManager.hasNotificationPermission ? .green : .orange)
                        }
                        
                        Divider()
                        
                        // Calendar Permission
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Calendar Access")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Budget reminders and planning")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: permissionManager.hasCalendarPermission ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(permissionManager.hasCalendarPermission ? .green : .orange)
                        }
                    }
                    
                    // Action Button
                    if permissionManager.notificationStatus == .denied || permissionManager.calendarStatus == .denied {
                        Button(action: openSettingsFromCard) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Open Settings")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    } else {
                        Button(action: {
                            showPermissionSheet = true
                        }) {
                            HStack {
                                Image(systemName: "shield.checkered")
                                Text("Grant Permissions")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
                .padding(.vertical, 8)
            }
            .accessibilityLabel("Permission status card")
        }
    }
}

#Preview("Permission Request View") {
    PermissionRequestView()
        .environmentObject(PermissionManager())
}

#Preview("Permission Status Card") {
    PermissionStatusCard(showPermissionSheet: .constant(false))
        .environmentObject(PermissionManager())
        .padding()
}
