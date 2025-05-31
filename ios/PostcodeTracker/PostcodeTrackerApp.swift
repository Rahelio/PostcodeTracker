import SwiftUI

@main
struct PostcodeTrackerApp: App {
    @StateObject private var authManager = AuthManager.shared
    
    init() {
        _ = FontManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(authManager)
        }
    }
} 
