//
//  AuthFormField.swift
//  SpendConscience
//
//  Created by AI Assistant on 9/14/25.
//

import SwiftUI
import UIKit

struct AuthFormField: View {
    let title: String
    @Binding var text: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let validation: ValidationState
    
    enum ValidationState {
        case none
        case valid
        case invalid(String)
    }
    
    init(title: String, text: Binding<String>, isSecure: Bool = false, keyboardType: UIKeyboardType = .default, textContentType: UITextContentType? = nil, validation: ValidationState = .none) {
        self.title = title
        self._text = text
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.validation = validation
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            // Apply styling to the container HStack instead of individual fields
            HStack {
                if isSecure {
                    SecureField("", text: $text)
                        .keyboardType(keyboardType)
                        .textContentType(textContentType)
                        .textInputAutocapitalization(shouldDisableCapitalization ? .never : .words)
                        .autocorrectionDisabled(shouldDisableAutocorrection)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboardType)
                        .textContentType(textContentType)
                        .textInputAutocapitalization(shouldDisableCapitalization ? .never : .words)
                        .autocorrectionDisabled(shouldDisableAutocorrection)
                }
                
                // Validation indicator
                validationIcon
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            
            // Error message
            if case .invalid(let message) = validation {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
    }
    
    private var borderColor: Color {
        switch validation {
        case .valid:
            return .green
        case .invalid:
            return .red
        case .none:
            return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        switch validation {
        case .valid, .invalid:
            return 1
        case .none:
            return 0
        }
    }
    
    @ViewBuilder
    private var validationIcon: some View {
        switch validation {
        case .valid:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 16))
        case .invalid:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 16))
        case .none:
            EmptyView()
        }
    }
    
    private var shouldDisableCapitalization: Bool {
        return keyboardType == .emailAddress || textContentType == .emailAddress || textContentType == .password || textContentType == .newPassword || isSecure
    }
    
    private var shouldDisableAutocorrection: Bool {
        return keyboardType == .emailAddress || textContentType == .emailAddress || textContentType == .password || textContentType == .newPassword || isSecure
    }
    
    private var accessibilityHint: String {
        switch validation {
        case .valid:
            return "Valid input"
        case .invalid(let message):
            return "Invalid input: \(message)"
        case .none:
            return "Enter your \(title.lowercased())"
        }
    }
}


#Preview {
    VStack(spacing: 20) {
        AuthFormField(
            title: "Email",
            text: .constant("john@example.com"),
            keyboardType: .emailAddress,
            validation: .valid
        )
        
        AuthFormField(
            title: "Password",
            text: .constant("password123"),
            isSecure: true,
            validation: .none
        )
        
        AuthFormField(
            title: "Confirm Password",
            text: .constant("password"),
            isSecure: true,
            validation: .invalid("Passwords do not match")
        )
    }
    .padding()
}
