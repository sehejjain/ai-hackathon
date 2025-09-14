//
//  FloatingActionButton.swift
//  SpendConscience
//
//  Created by AI Assistant
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FloatingActionButtonStyle: ButtonStyle {
    let isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct FloatingActionButton: View {
    let action: () -> Void
    let isDisabled: Bool

    init(action: @escaping () -> Void, isDisabled: Bool = false) {
        self.action = action
        self.isDisabled = isDisabled
    }

    var body: some View {
        Button(action: {
            // Provide haptic feedback
            #if canImport(UIKit)
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            #endif

            action()
        }) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(isDisabled ? Color.gray : Color.accentColor)
                )
                .shadow(
                    color: Color.black.opacity(0.2),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        }
        .buttonStyle(FloatingActionButtonStyle(isDisabled: isDisabled))
        .disabled(isDisabled)
        .accessibilityLabel("AI Financial Assistant")
        .accessibilityHint("Opens AI assistant to ask financial questions")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    VStack(spacing: 20) {
        FloatingActionButton(action: {
            print("FAB tapped")
        })
        
        FloatingActionButton(action: {
            print("Disabled FAB tapped")
        }, isDisabled: true)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
