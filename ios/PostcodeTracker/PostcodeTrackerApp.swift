import SwiftUI

@main
struct PostcodeTrackerApp: App {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(authManager)
        }
    }
} 
