//
//  User.swift
//  SpendConscience
//
//  Created by AI Assistant on 9/14/25.
//

import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var email: String
    var firstName: String
    var lastName: String
    var dateCreated: Date
    
    // Backend-ready fields
    var backendUserId: String?
    var lastSyncDate: Date?
    
    // Validation errors
    enum ValidationError: LocalizedError {
        case invalidEmail
        case emptyFirstName
        case emptyLastName
        
        var errorDescription: String? {
            switch self {
            case .invalidEmail:
                return "Please enter a valid email address"
            case .emptyFirstName:
                return "First name cannot be empty"
            case .emptyLastName:
                return "Last name cannot be empty"
            }
        }
    }
    
    // Computed properties for UI display
    var fullName: String {
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    var initials: String {
        let firstInitial = firstName.first?.uppercased() ?? ""
        let lastInitial = lastName.first?.uppercased() ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
    
    init(email: String, firstName: String, lastName: String) throws {
        // Validate email format
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        guard emailPredicate.evaluate(with: email) else {
            throw ValidationError.invalidEmail
        }
        
        // Validate non-empty names
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedFirstName.isEmpty else {
            throw ValidationError.emptyFirstName
        }
        
        guard !trimmedLastName.isEmpty else {
            throw ValidationError.emptyLastName
        }
        
        self.id = UUID()
        self.email = email.lowercased().trimmingCharacters(in: .whitespaces)
        self.firstName = trimmedFirstName
        self.lastName = trimmedLastName
        self.dateCreated = Date()
        self.backendUserId = nil
        self.lastSyncDate = nil
    }
    
    // Static sample data methods for development/testing
    static func sampleUser() -> User {
        return try! User(
            email: "john.doe@example.com",
            firstName: "John",
            lastName: "Doe"
        )
    }
    
    static func sampleUsers() -> [User] {
        return [
            try! User(email: "john.doe@example.com", firstName: "John", lastName: "Doe"),
            try! User(email: "jane.smith@example.com", firstName: "Jane", lastName: "Smith"),
            try! User(email: "mike.johnson@example.com", firstName: "Mike", lastName: "Johnson")
        ]
    }
}
