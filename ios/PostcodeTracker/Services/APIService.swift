import Foundation
import CoreLocation

// MARK: - API Response Models
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let message: String?
    let data: T?
}

struct AuthResponse: Codable {
    let success: Bool
    let message: String
    let token: String?
    let user: User?
}

struct JourneyResponse: Codable {
    let success: Bool
    let message: String
    let journey: Journey?
}

struct ActiveJourneyResponse: Codable {
    let success: Bool
    let active: Bool
    let journey: Journey?
}

struct JourneysResponse: Codable {
    let success: Bool
    let journeys: [Journey]
}

struct PostcodeResponse: Codable {
    let success: Bool
    let postcode: String?
    let message: String?
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case serverError(String)
    case unauthorized
    case noLocationPermission
    case locationUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unauthorized:
            return "Unauthorized access"
        case .noLocationPermission:
            return "Location permission required"
        case .locationUnavailable:
            return "Unable to determine location"
        }
    }
}

// MARK: - API Service
@MainActor
class APIService: ObservableObject {
    static let shared = APIService()
    
    private let baseURL = "http://rickys.ddns.net:8005/api"
    private let session = URLSession.shared
    private var authToken: String?
    
    private init() {
        // Load saved auth token
        self.authToken = UserDefaults.standard.string(forKey: "auth_token")
    }
    
    // MARK: - Auth Token Management
    func setAuthToken(_ token: String) {
        self.authToken = token
        UserDefaults.standard.set(token, forKey: "auth_token")
    }
    
    func clearAuthToken() {
        self.authToken = nil
        UserDefaults.standard.removeObject(forKey: "auth_token")
    }
    
    var isAuthenticated: Bool {
        return authToken != nil
    }
    
    // MARK: - HTTP Methods
    private func createRequest(for endpoint: String, method: String = "GET") throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    private func performRequest<T: Codable>(_ request: URLRequest, responseType: T.Type) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(NSError(domain: "Invalid response", code: -1))
            }
            
            // Log response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("API Response (\(httpResponse.statusCode)): \(responseString)")
            }
            
            // Check for HTTP errors
            if httpResponse.statusCode == 401 {
                clearAuthToken()
                throw APIError.unauthorized
            }
            
            guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                // Try to decode error message
                if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                    throw APIError.serverError(errorResponse.message ?? "Unknown server error")
                }
                throw APIError.serverError("HTTP \(httpResponse.statusCode)")
            }
            
            // Decode response
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(responseType, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Authentication
    func register(username: String, password: String) async throws -> AuthResponse {
        var request = try createRequest(for: "auth/register", method: "POST")
        
        let body = [
            "username": username,
            "password": password
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let response = try await performRequest(request, responseType: AuthResponse.self)
        
        if response.success, let token = response.token {
            setAuthToken(token)
        }
        
        return response
    }
    
    func login(username: String, password: String) async throws -> AuthResponse {
        var request = try createRequest(for: "auth/login", method: "POST")
        
        let body = [
            "username": username,
            "password": password
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let response = try await performRequest(request, responseType: AuthResponse.self)
        
        if response.success, let token = response.token {
            setAuthToken(token)
        }
        
        return response
    }
    
    func logout() {
        clearAuthToken()
    }
    
    // MARK: - Journey Management
    func startJourney(latitude: Double, longitude: Double) async throws -> JourneyResponse {
        var request = try createRequest(for: "journey/start", method: "POST")
        
        let body = [
            "latitude": latitude,
            "longitude": longitude
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return try await performRequest(request, responseType: JourneyResponse.self)
    }
    
    func endJourney(latitude: Double, longitude: Double) async throws -> JourneyResponse {
        var request = try createRequest(for: "journey/end", method: "POST")
        
        let body = [
            "latitude": latitude,
            "longitude": longitude
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return try await performRequest(request, responseType: JourneyResponse.self)
    }
    
    func getActiveJourney() async throws -> ActiveJourneyResponse {
        let request = try createRequest(for: "journey/active", method: "GET")
        return try await performRequest(request, responseType: ActiveJourneyResponse.self)
    }
    
    func getJourneys() async throws -> JourneysResponse {
        let request = try createRequest(for: "journeys", method: "GET")
        return try await performRequest(request, responseType: JourneysResponse.self)
    }
    
    // MARK: - Postcode Services
    func getPostcodeFromCoordinates(latitude: Double, longitude: Double) async throws -> PostcodeResponse {
        var request = try createRequest(for: "postcode/from-coordinates", method: "GET")
        
        // Add query parameters
        var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude))
        ]
        request.url = components.url
        
        return try await performRequest(request, responseType: PostcodeResponse.self)
    }
    
    // MARK: - Legacy Support (for compatibility)
    func getPostcodes() async throws -> [String] {
        // Return empty array since we removed postcode management
        // This prevents 404 errors from old code
        return []
    }
    
    // MARK: - Health Check
    func healthCheck() async throws -> APIResponse<String> {
        let request = try createRequest(for: "health", method: "GET")
        return try await performRequest(request, responseType: APIResponse<String>.self)
    }
} 