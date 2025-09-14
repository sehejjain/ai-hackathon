import SwiftUI
import SwiftData
import os.log

struct ContentView: View {
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.modelContext) private var modelContext
    @State private var dataManager: DataManager?
    @State private var initError: Error?
    
    // App-level dark mode control
    @AppStorage("darkModeEnabled") var darkModeEnabled = false

    private let logger = Logger(subsystem: "SpendConscience", category: "ContentView")
    
    var body: some View {
        Group {
            if !userManager.isAuthenticated {
                AuthenticationView()
            } else {
                authenticatedView
            }
        }
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
    }
    
    private var authenticatedView: some View {
        Group {
            if let dataManager = dataManager {
                MainTabView()
                    .environmentObject(userManager)
                    .environmentObject(dataManager)
            } else if let _ = initError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)

                    Text("Initialization Error")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Failed to initialize data manager. Please restart the app.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Retry") {
                        initError = nil
                        initializeDataManager()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                LoadingPlaceholderView(title: "SpendConscience", subtitle: "Your AI Financial Assistant")
            }
        }
        .onAppear {
            if userManager.isAuthenticated && dataManager == nil {
                initializeDataManager()
            }
        }
        .onChange(of: userManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                initError = nil
                initializeDataManager()
            } else {
                dataManager = nil
                initError = nil
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeDataManager() {
        if dataManager == nil {
            do {
                dataManager = DataManager(modelContext: modelContext)
                logger.info("DataManager initialized successfully")
            } catch {
                initError = error
                logger.error("Failed to initialize DataManager: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(UserManager())
}
