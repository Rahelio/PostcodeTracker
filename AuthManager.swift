import Foundation
import SwiftUI

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var error: String?
    
    private let baseURL = "https://your-api-url.com/api"
    private let defaults = UserDefaults.standard
    private let tokenKey = "authToken"
    
    init() {
        // Check for existing token on launch
        if let token = defaults.string(forKey: tokenKey) {
            validateToken(token)
        }
    }
    
    private func validateToken(_ token: String) {
        // Make a request to validate the token
        guard let url = URL(string: "\(baseURL)/auth/validate") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.handleError(error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.handleError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    self?.isAuthenticated = true
                    self?.error = nil
                } else {
                    self?.isAuthenticated = false
                    self?.defaults.removeObject(forKey: self?.tokenKey ?? "")
                    self?.handleError(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid token"]))
                }
            }
        }.resume()
    }
    
    func login(username: String, password: String) {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            handleError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        let parameters = ["username": username, "password": password]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            handleError(error)
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.handleError(error)
                    return
                }
                
                guard let data = data else {
                    self?.handleError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = json["success"] as? Bool, success {
                            if let token = json["access_token"] as? String {
                                self?.defaults.set(token, forKey: self?.tokenKey ?? "")
                                self?.isAuthenticated = true
                                self?.error = nil
                            } else {
                                self?.handleError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No token received"]))
                            }
                        } else {
                            let message = json["message"] as? String ?? "Unknown error"
                            self?.handleError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
                        }
                    }
                } catch {
                    self?.handleError(error)
                }
            }
        }.resume()
    }
    
    func register(username: String, password: String) {
        guard let url = URL(string: "\(baseURL)/auth/register") else {
            handleError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        let parameters = ["username": username, "password": password]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            handleError(error)
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.handleError(error)
                    return
                }
                
                guard let data = data else {
                    self?.handleError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = json["success"] as? Bool, success {
                            // Registration successful, now login
                            self?.login(username: username, password: password)
                        } else {
                            let message = json["message"] as? String ?? "Unknown error"
                            self?.handleError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
                        }
                    }
                } catch {
                    self?.handleError(error)
                }
            }
        }.resume()
    }
    
    func logout() {
        defaults.removeObject(forKey: tokenKey)
        isAuthenticated = false
        currentUser = nil
        error = nil
    }
    
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.error = error.localizedDescription
            self.isAuthenticated = false
        }
    }
}

struct User: Codable {
    let id: Int
    let username: String
} 