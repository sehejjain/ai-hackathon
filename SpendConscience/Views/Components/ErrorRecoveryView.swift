//
//  ErrorRecoveryView.swift
//  SpendConscience
//
//  User-friendly error display with recovery options
//

import SwiftUI

struct ErrorRecoveryView: View {
    
    @ObservedObject var errorManager: ErrorRecoveryManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        if let error = errorManager.currentError {
            VStack(spacing: 24) {
                // Error Icon and Title
                VStack(spacing: 16) {
                    Image(systemName: error.severity.icon)
                        .font(.system(size: 48))
                        .foregroundColor(error.severity.color)
                    
                    Text("Oops! Something went wrong")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                }
                
                // Error Description
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Recovery Status
                if errorManager.isRecovering {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Attempting to recover...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if errorManager.recoveryAttempts > 0 {
                            Text("Attempt \(errorManager.recoveryAttempts) of 3")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                } else {
                    // Recovery Actions
                    VStack(spacing: 12) {
                        ForEach(errorManager.getRecoveryActions(), id: \.title) { action in
                            Button(action: {
                                errorManager.executeRecoveryAction(action)
                                if action == .dismiss {
                                    dismiss()
                                }
                            }) {
                                HStack {
                                    Text(action.title)
                                        .fontWeight(.medium)
                                    
                                    if action == .retry && errorManager.recoveryAttempts > 0 {
                                        Spacer()
                                        Text("(\(errorManager.recoveryAttempts)/3)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    action.isDestructive 
                                        ? Color.red.opacity(0.1)
                                        : Color.primary.opacity(0.1)
                                )
                                .foregroundColor(action.isDestructive ? .red : .primary)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Additional Info
                if let lastRecoveryTime = errorManager.lastRecoveryTime {
                    Text("Last attempt: \(lastRecoveryTime, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - Error Banner View

struct ErrorBannerView: View {
    
    @ObservedObject var errorManager: ErrorRecoveryManager
    @State private var isExpanded = false
    
    var body: some View {
        if let error = errorManager.currentError {
            VStack(spacing: 0) {
                // Banner Content
                HStack(spacing: 12) {
                    Image(systemName: error.severity.icon)
                        .foregroundColor(error.severity.color)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(errorTitle(for: error))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if isExpanded {
                            Text(error.localizedDescription)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                    
                    Spacer()
                    
                    if errorManager.isRecovering {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Retry") {
                            if let error = errorManager.currentError {
                                Task {
                                    await errorManager.attemptRecovery(for: error)
                                }
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(error.severity.color.opacity(0.2))
                        .foregroundColor(error.severity.color)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        errorManager.clearError()
                    }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(error.severity.color.opacity(0.1))
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
                
                // Expanded Actions
                if isExpanded {
                    Divider()
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(errorManager.getRecoveryActions().prefix(4), id: \.title) { action in
                                Button(action.title) {
                                    errorManager.executeRecoveryAction(action)
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.1))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
        }
    }
    
    private func errorTitle(for error: ErrorRecoveryManager.AppError) -> String {
        switch error {
        case .networkConnection:
            return "No Internet Connection"
        case .serverUnavailable:
            return "Server Unavailable"
        case .dataCorruption:
            return "Data Issue Detected"
        case .authenticationFailed:
            return "Authentication Failed"
        case .insufficientStorage:
            return "Storage Full"
        case .backgroundSync:
            return "Sync Issue"
        case .plaidConnection:
            return "Bank Connection Issue"
        case .locationServices:
            return "Location Unavailable"
        case .dataConversion:
            return "Data Processing Issue"
        case .unknown:
            return "Unexpected Error"
        }
    }
}

// MARK: - Error Sheet Modifier

struct ErrorSheetModifier: ViewModifier {
    
    @ObservedObject var errorManager: ErrorRecoveryManager
    @State private var showingErrorSheet = false
    
    func body(content: Content) -> some View {
        content
            .onChange(of: errorManager.currentError) { _, newError in
                let hasError = newError != nil
                let isHighSeverity = newError?.severity == .high
                let requiresUserAction = newError?.userActionRequired == true
                showingErrorSheet = hasError && (isHighSeverity || requiresUserAction)
            }
            .sheet(isPresented: $showingErrorSheet) {
                ErrorRecoveryView(errorManager: errorManager)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }
}

// MARK: - View Extensions

extension View {
    func errorRecovery(_ errorManager: ErrorRecoveryManager) -> some View {
        modifier(ErrorSheetModifier(errorManager: errorManager))
    }
    
    func errorBanner(_ errorManager: ErrorRecoveryManager) -> some View {
        VStack(spacing: 0) {
            ErrorBannerView(errorManager: errorManager)
                .animation(.easeInOut(duration: 0.3), value: errorManager.currentError != nil)
            
            self
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Text("Main Content")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .errorBanner(ErrorRecoveryManager())
}