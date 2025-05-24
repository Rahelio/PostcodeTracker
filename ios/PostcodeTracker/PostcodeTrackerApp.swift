import SwiftUI

@main
struct PostcodeTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var token: String?
    
    private init() {} // Make initializer private for singleton pattern
    
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
