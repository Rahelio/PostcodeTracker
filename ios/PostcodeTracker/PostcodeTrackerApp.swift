import SwiftUI
import SwiftData

@main
struct PostcodeTrackerApp: App {
    @StateObject private var authManager = AuthManager.shared
    private let modelContainer = SwiftDataStack.shared
    
    init() {
        _ = FontManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(authManager)
                .modelContainer(modelContainer)
                .onAppear {
                    print("🚨 POSTCODETRACKER APP STARTED - NEW VERSION")
                }
        }
    }
} 
