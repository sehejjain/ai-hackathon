//
//  AuthenticationView.swift
//  SpendConscience
//
//  Created by AI Assistant on 9/14/25.
//

import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var userManager: UserManager
    
    @State private var authMode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    
    enum AuthMode: String, CaseIterable {
        case signIn = "Sign In"
        case signUp = "Sign Up"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerSection
                    
                    // Auth Mode Selector
                    authModeSelector
                    
                    // Form
                    authForm
                    
                    // Submit Button
                    submitButton
                    
                    // Forgot Password (placeholder)
                    if authMode == .signIn {
                        forgotPasswordButton
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .navigationBarHidden(true)
            .background(Color(.systemBackground))
        }
        .alert("Authentication Error", isPresented: Binding<Bool>(
            get: { userManager.authError != nil },
            set: { _ in userManager.authError = nil }
        )) {
            Button("OK") {
                userManager.authError = nil
            }
        } message: {
            Text(userManager.authError?.localizedDescription ?? "")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Icon/Logo placeholder
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text("Welcome to SpendConscience")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Track your spending and stay within budget")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("SpendConscience app welcome screen")
    }
    
    private var authModeSelector: some View {
        Picker("Authentication Mode", selection: $authMode) {
            ForEach(AuthMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .onChange(of: authMode) { oldValue, newValue in
            clearForm()
        }
    }
    
    private var authForm: some View {
        VStack(spacing: 20) {
            // Email field
            AuthFormField(
                title: "Email",
                text: $email,
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                validation: emailValidation
            )
            
            // Name fields (Sign Up only)
            if authMode == .signUp {
                HStack(spacing: 16) {
                    AuthFormField(
                        title: "First Name",
                        text: $firstName,
                        textContentType: .givenName,
                        validation: firstNameValidation
                    )
                    
                    AuthFormField(
                        title: "Last Name",
                        text: $lastName,
                        textContentType: .familyName,
                        validation: lastNameValidation
                    )
                }
            }
            
            // Password field
            AuthFormField(
                title: "Password",
                text: $password,
                isSecure: true,
                textContentType: authMode == .signUp ? .newPassword : .password,
                validation: passwordValidation
            )
            
            // Confirm Password (Sign Up only)
            if authMode == .signUp {
                AuthFormField(
                    title: "Confirm Password",
                    text: $confirmPassword,
                    isSecure: true,
                    textContentType: .newPassword,
                    validation: confirmPasswordValidation
                )
            }
        }
    }
    
    private var submitButton: some View {
        Button(action: handleSubmit) {
            HStack {
                if userManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(authMode.rawValue)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isFormValid ? Color.accentColor : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!isFormValid || userManager.isLoading)
        .accessibilityLabel("\(authMode.rawValue) button")
        .accessibilityHint(isFormValid ? "Tap to \(authMode.rawValue.lowercased())" : "Complete the form to enable this button")
    }
    
    private var forgotPasswordButton: some View {
        Button("Forgot Password?") {
            // Placeholder for future implementation
        }
        .font(.subheadline)
        .foregroundColor(.accentColor)
        .accessibilityLabel("Forgot password")
        .accessibilityHint("Tap to reset your password")
    }
    
    // MARK: - Validation
    
    private var emailValidation: AuthFormField.ValidationState {
        if email.isEmpty {
            return .none
        }
        return userManager.validateEmail(email) ? .valid : .invalid("Please enter a valid email address")
    }
    
    private var firstNameValidation: AuthFormField.ValidationState {
        if firstName.isEmpty {
            return .none
        }
        return userManager.validateName(firstName) ? .valid : .invalid("First name is required")
    }
    
    private var lastNameValidation: AuthFormField.ValidationState {
        if lastName.isEmpty {
            return .none
        }
        return userManager.validateName(lastName) ? .valid : .invalid("Last name is required")
    }
    
    private var passwordValidation: AuthFormField.ValidationState {
        if password.isEmpty {
            return .none
        }
        return userManager.validatePassword(password) ? .valid : .invalid("Password must be at least 6 characters")
    }
    
    private var confirmPasswordValidation: AuthFormField.ValidationState {
        if confirmPassword.isEmpty {
            return .none
        }
        if password != confirmPassword {
            return .invalid("Passwords do not match")
        }
        return .valid
    }
    
    private var isFormValid: Bool {
        let emailValid = userManager.validateEmail(email)
        let passwordValid = userManager.validatePassword(password)
        
        if authMode == .signIn {
            return emailValid && passwordValid
        } else {
            let nameValid = userManager.validateName(firstName) && userManager.validateName(lastName)
            let passwordsMatch = password == confirmPassword && !confirmPassword.isEmpty
            return emailValid && passwordValid && nameValid && passwordsMatch
        }
    }
    
    // MARK: - Actions
    
    private func handleSubmit() {
        Task {
            if authMode == .signIn {
                await userManager.signIn(email: email, password: password)
            } else {
                await userManager.signUp(
                    email: email,
                    firstName: firstName,
                    lastName: lastName,
                    password: password,
                    confirmPassword: confirmPassword
                )
            }
        }
    }
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        firstName = ""
        lastName = ""
        userManager.authError = nil
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(UserManager())
}
