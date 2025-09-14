//
//  LoadingPlaceholderView.swift
//  SpendConscience
//
//  Created by AI Assistant
//

import SwiftUI

struct LoadingPlaceholderView: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title)
                .fontWeight(.semibold)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView()
                .scaleEffect(0.8)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading \(title.lowercased())")
    }
}

#Preview {
    LoadingPlaceholderView(title: "SpendConscience", subtitle: "Your AI Financial Assistant")
}