import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack {
                    Text("SpendConscience")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your Autonomous Budgeting Agent")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button("Get Started") {
                        // Navigation to onboarding
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("View Budget") {
                        // Navigation to budget view
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Budget Overview")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}