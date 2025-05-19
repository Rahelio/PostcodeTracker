import Foundation

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(String)
    case unauthorized
}

class APIService {
    static let shared = APIService()
    private let baseURL = "http://rickys.ddns.net:5319/api"
    private var authToken: String?
    
    private init() {}
    
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }
    
    private func createRequest(path: String, method: String) -> URLRequest {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    // MARK: - Authentication
    
    func register(username: String, password: String) async throws -> String {
        var request = createRequest(path: "/auth/register", method: "POST")
        
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
        var request = createRequest(path: "/auth/login", method: "POST")
        
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
    
    // MARK: - Postcodes
    
    func getPostcodes() async throws -> [Postcode] {
        let request = createRequest(path: "/postcodes", method: "GET")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode([Postcode].self, from: data)
        } else if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        } else {
            let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(error.error)
        }
    }
    
    func addPostcode(_ postcode: String) async throws -> Postcode {
        var request = createRequest(path: "/postcodes", method: "POST")
        
        let body = ["postcode": postcode]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            return try JSONDecoder().decode(Postcode.self, from: data)
        } else if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        } else {
            let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(error.error)
        }
    }
    
    func deletePostcode(id: Int) async throws {
        let request = createRequest(path: "/postcodes/\(id)", method: "DELETE")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 204 {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            } else {
                let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
                throw APIError.serverError(error.error)
            }
        }
    }
}

// MARK: - Response Models

struct RegisterResponse: Codable {
    let message: String
}

struct LoginResponse: Codable {
    let access_token: String
}

struct ErrorResponse: Codable {
    let error: String
}

struct Postcode: Codable, Identifiable {
    let id: Int
    let postcode: String
    let user_id: Int
    let created_at: String
    let updated_at: String
} 