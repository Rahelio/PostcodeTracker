import Foundation

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(String)
}

class APIClient {
    static let shared = APIClient()
    private let baseURL = "http://rickys.ddns.net:5319/api" // Updated to use the new server address
    private var authToken: String?
    
    private init() {}
    
    func setAuthToken(_ token: String) {
        self.authToken = token
    }
    
    private func createRequest(_ endpoint: String, method: String = "GET", body: Data? = nil) -> URLRequest? {
        guard let url = URL(string: baseURL + endpoint) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    // MARK: - Authentication
    
    func login(username: String, password: String) async throws -> String {
        let body = try JSONEncoder().encode([
            "username": username,
            "password": password
        ])
        
        guard let request = createRequest("/auth/login", method: "POST", body: body) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let error = try? JSONDecoder().decode([String: String].self, from: data)
            throw APIError.serverError(error?["error"] ?? "Unknown error")
        }
        
        let result = try JSONDecoder().decode([String: String].self, from: data)
        guard let token = result["access_token"] else {
            throw APIError.invalidResponse
        }
        
        return token
    }
    
    func register(username: String, password: String) async throws {
        let body = try JSONEncoder().encode([
            "username": username,
            "password": password
        ])
        
        guard let request = createRequest("/auth/register", method: "POST", body: body) else {
            throw APIError.invalidURL
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 201 else {
            throw APIError.serverError("Registration failed")
        }
    }
    
    // MARK: - Postcodes
    
    func getPostcodes() async throws -> [Postcode] {
        guard let request = createRequest("/postcodes") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError("Failed to fetch postcodes")
        }
        
        return try JSONDecoder().decode([Postcode].self, from: data)
    }
    
    func calculateDistance(postcode1: String, postcode2: String) async throws -> Distance {
        let body = try JSONEncoder().encode([
            "postcode1": postcode1,
            "postcode2": postcode2
        ])
        
        guard let request = createRequest("/postcodes/distance", method: "POST", body: body) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError("Failed to calculate distance")
        }
        
        return try JSONDecoder().decode(Distance.self, from: data)
    }
} 