import Foundation

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(String)
}

class APIService {
    static let shared = APIService()
    private let baseURL = "http://localhost:5000/api"
    
    private init() {}
    
    func register(username: String, password: String) async throws -> String {
        let url = URL(string: "\(baseURL)/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["username": username, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            let result = try JSONDecoder().decode(RegisterResponse.self, from: data)
            return result.message
        } else {
            let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(error.error)
        }
    }
    
    func login(username: String, password: String) async throws -> String {
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["username": username, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(LoginResponse.self, from: data)
            return result.access_token
        } else {
            let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(error.error)
        }
    }
}

// Response models
struct RegisterResponse: Codable {
    let message: String
}

struct LoginResponse: Codable {
    let access_token: String
}

struct ErrorResponse: Codable {
    let error: String
} 