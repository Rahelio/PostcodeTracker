import SwiftUI

@main
struct PostcodeTrackerApp: App {
    @StateObject private var authManager = AuthManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView(authManager: authManager)
                .environmentObject(authManager)
        }
    }
}

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var token: String?
    
    func login(token: String) {
        print("AuthManager: Setting token and updating authentication state")
        self.token = token
        self.isAuthenticated = true
        APIService.shared.setAuthToken(token)
        print("AuthManager: isAuthenticated is now \(isAuthenticated)")
    }
    
    func logout() {
        print("AuthManager: Logging out")
        self.token = nil
        self.isAuthenticated = false
        APIService.shared.setAuthToken(nil)
        print("AuthManager: isAuthenticated is now \(isAuthenticated)")
    }
} 
