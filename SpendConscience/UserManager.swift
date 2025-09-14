//
//  UserManager.swift
//  SpendConscience
//
//  Created by AI Assistant on 9/14/25.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
final class UserManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var authError: AuthError?
    
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("currentUserId") private var currentUserId: String = ""
    
    private var modelContext: ModelContext?
    
    enum AuthError: LocalizedError {
        case invalidEmail
        case weakPassword
        case passwordMismatch
        case userAlreadyExists
        case userNotFound
        case invalidCredentials
        case missingRequiredFields
        case unknown(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidEmail:
                return "Please enter a valid email address"
            case .weakPassword:
                return "Password must be at least 6 characters long"
            case .passwordMismatch:
                return "Passwords do not match"
            case .userAlreadyExists:
                return "An account with this email already exists"
            case .userNotFound:
                return "No account found with this email"
            case .invalidCredentials:
                return "Invalid email or password"
            case .missingRequiredFields:
                return "Please fill in all required fields"
            case .unknown(let message):
                return message
            }
        }
    }
    
    init() {
        // Initialize authentication state from stored values
        self.isAuthenticated = isLoggedIn
        if isLoggedIn && !currentUserId.isEmpty {
            // Will load current user when model context is set
        }
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        if isLoggedIn && !currentUserId.isEmpty {
            Task {
                await loadCurrentUser()
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    func signUp(email: String, firstName: String, lastName: String, password: String, confirmPassword: String) async {
        isLoading = true
        authError = nil
        
        do {
            // Validate input
            try validateSignUpInput(email: email, firstName: firstName, lastName: lastName, password: password, confirmPassword: confirmPassword)
            
            // Check if user already exists
            if await userExists(email: email) {
                throw AuthError.userAlreadyExists
            }
            
            // Create new user (normalize email to lowercase for consistency/uniqueness)
            let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let newUser = try User(email: normalizedEmail, firstName: firstName, lastName: lastName)
            
            // Save to SwiftData
            guard let context = modelContext else {
                throw AuthError.unknown("Database not available")
            }
            
            context.insert(newUser)
            try context.save()
            
            // Update authentication state
            currentUser = newUser
            isAuthenticated = true
            isLoggedIn = true
            currentUserId = newUser.id.uuidString
        } catch {
            if let authError = error as? AuthError {
                self.authError = authError
            } else if let userValidationError = error as? User.ValidationError {
                // Map User.ValidationError to AuthError
                switch userValidationError {
                case .invalidEmail:
                    self.authError = AuthError.invalidEmail
                case .emptyFirstName, .emptyLastName:
                    self.authError = AuthError.missingRequiredFields
                }
            } else {
                self.authError = AuthError.unknown(error.localizedDescription)
            }
        }
        
        isLoading = false
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        authError = nil
        
        do {
            // Validate input
            try validateSignInInput(email: email, password: password)
            
            // Find user by email
            guard let user = await findUser(by: email) else {
                throw AuthError.userNotFound
            }
            
            // In a real app, we would verify the password here
            // For the demo, we'll just check if the user exists
            
            // Update authentication state
            currentUser = user
            isAuthenticated = true
            isLoggedIn = true
            currentUserId = user.id.uuidString
            
        } catch {
            if let authError = error as? AuthError {
                self.authError = authError
            } else {
                self.authError = AuthError.unknown(error.localizedDescription)
            }
        }
        
        isLoading = false
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        isLoggedIn = false
        currentUserId = ""
        authError = nil
    }
    
    func loadCurrentUser() async {
        guard !currentUserId.isEmpty, let context = modelContext else { return }
        
        do {
            // Parse currentUserId into UUID and use direct comparison
            guard let parsedUUID = UUID(uuidString: currentUserId) else {
                print("Invalid UUID format in currentUserId")
                signOut()
                return
            }
            
            let descriptor = FetchDescriptor<User>(
                predicate: #Predicate { user in
                    user.id == parsedUUID
                }
            )
            
            let users = try context.fetch(descriptor)
            if let user = users.first {
                currentUser = user
                isAuthenticated = true
            } else {
                // User not found, clear stored data
                signOut()
            }
        } catch {
            print("Error loading current user: \(error)")
            signOut()
        }
    }
    
    // MARK: - Validation Methods
    
    func validateEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func validatePassword(_ password: String) -> Bool {
        return password.count >= 6
    }
    
    func validateName(_ name: String) -> Bool {
        return !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Private Helper Methods
    
    private func validateSignUpInput(email: String, firstName: String, lastName: String, password: String, confirmPassword: String) throws {
        guard !email.isEmpty, !firstName.isEmpty, !lastName.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            throw AuthError.missingRequiredFields
        }
        
        guard validateEmail(email) else {
            throw AuthError.invalidEmail
        }
        
        guard validateName(firstName) && validateName(lastName) else {
            throw AuthError.missingRequiredFields
        }
        
        guard validatePassword(password) else {
            throw AuthError.weakPassword
        }
        
        guard password == confirmPassword else {
            throw AuthError.passwordMismatch
        }
    }
    
    private func validateSignInInput(email: String, password: String) throws {
        guard !email.isEmpty, !password.isEmpty else {
            throw AuthError.missingRequiredFields
        }
        
        guard validateEmail(email) else {
            throw AuthError.invalidEmail
        }
    }
    
    private func userExists(email: String) async -> Bool {
        guard let context = modelContext else { return false }
        
        do {
            let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let descriptor = FetchDescriptor<User>(
                predicate: #Predicate { user in
                    user.email == normalizedEmail
                }
            )
            
            let users = try context.fetch(descriptor)
            return !users.isEmpty
        } catch {
            print("Error checking if user exists: \(error)")
            return false
        }
    }
    
    private func findUser(by email: String) async -> User? {
        guard let context = modelContext else { return nil }
        
        do {
            let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let descriptor = FetchDescriptor<User>(
                predicate: #Predicate { user in
                    user.email == normalizedEmail
                }
            )
            
            let users = try context.fetch(descriptor)
            return users.first
        } catch {
            print("Error finding user: \(error)")
            return nil
        }
    }
    
    // MARK: - Backend-Ready Methods (Placeholders)
    
    // These methods are structured for future API integration
    private func syncUserWithBackend(_ user: User) async throws {
        // Placeholder for future backend sync
        // This would make API calls to sync user data
    }
    
    private func authenticateWithBackend(email: String, password: String) async throws -> String {
        // Placeholder for future backend authentication
        // This would return a JWT token or session ID
        return ""
    }
}
