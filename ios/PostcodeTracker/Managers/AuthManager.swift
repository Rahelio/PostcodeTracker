import Foundation
import SwiftUI

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var token: String?
    
    private init() {
        print("AuthManager: Initializing...")
        // Check for existing token on init
        if let savedToken = UserDefaults.standard.string(forKey: "authToken") {
            print("AuthManager: Found saved token in UserDefaults")
            self.token = savedToken
            self.isAuthenticated = true
            APIService.shared.setAuthToken(savedToken)
            print("AuthManager: Restored authentication state, isAuthenticated: \(isAuthenticated)")
        } else {
            print("AuthManager: No saved token found in UserDefaults")
        }
    }
    
    func login(token: String) {
        print("AuthManager: Setting token and updating authentication state")
        self.token = token
        self.isAuthenticated = true
        APIService.shared.setAuthToken(token)
        UserDefaults.standard.set(token, forKey: "authToken")
        print("AuthManager: isAuthenticated is now \(isAuthenticated)")
    }
    
    func logout() {
        print("AuthManager: Logging out")
        self.token = nil
        self.isAuthenticated = false
        APIService.shared.setAuthToken(nil)
        UserDefaults.standard.removeObject(forKey: "authToken")
        print("AuthManager: isAuthenticated is now \(isAuthenticated)")
    }
} 