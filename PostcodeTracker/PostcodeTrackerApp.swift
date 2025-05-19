import SwiftUI

@main
struct PostcodeTrackerApp: App {
    @StateObject private var authManager = AuthManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView(authManager: authManager)
        }
    }
}

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var authToken: String?
    
    init() {
        // Initialize with default values
        self.isAuthenticated = false
        self.authToken = nil
    }
    
    func login(token: String) {
        self.authToken = token
        self.isAuthenticated = true
    }
    
    func logout() {
        self.authToken = nil
        self.isAuthenticated = false
    }
} 