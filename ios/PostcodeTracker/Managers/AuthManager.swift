import Foundation
import SwiftUI

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private init() {
        checkAuthenticationStatus()
    }
    
    func login(user: User) {
        self.currentUser = user
        self.isAuthenticated = true
        
        // Save user data
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "current_user")
        }
        UserDefaults.standard.set(true, forKey: "is_authenticated")
    }
    
    func logout() {
        self.currentUser = nil
        self.isAuthenticated = false
        
        // Clear saved data
        UserDefaults.standard.removeObject(forKey: "current_user")
        UserDefaults.standard.removeObject(forKey: "is_authenticated")
        UserDefaults.standard.removeObject(forKey: "auth_token")
    }
    
    private func checkAuthenticationStatus() {
        let isAuth = UserDefaults.standard.bool(forKey: "is_authenticated")
        
        if isAuth, let userData = UserDefaults.standard.data(forKey: "current_user"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
            self.isAuthenticated = true
        } else {
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }
} 