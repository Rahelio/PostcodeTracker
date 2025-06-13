import Foundation
import CoreLocation

// MARK: - API Response Models
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let message: String?
    let data: T?
}

// MARK: - Response Models
// Updated to match server API v2.0 - using "token" field
struct AuthResponseV2: Codable {
    let success: Bool
    let message: String
    let token: String?
    let user: User?
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case token
        case user
    }
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
class APIServiceV2: ObservableObject {
    static let shared = APIServiceV2()
    
    // Base URL includes LocationApp prefix to align with Nginx alias
    private let baseURL = "https://rickys.ddns.net/LocationApp/api"
    private let session = URLSession.shared
    private var authToken: String?
    
    private init() {
        // Load saved auth token
        self.authToken = UserDefaults.standard.string(forKey: "auth_token")
        print("🔥🔥🔥 NEW APIServiceV2 INITIALIZED - baseURL: \(baseURL)")
        print("🔥🔥🔥 Loaded auth token: \(authToken != nil ? "Present" : "None")")
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
        let fullURL = "\(baseURL)/\(endpoint)"
        print("Attempting to create URL from string: \(fullURL)")
        
        guard let url = URL(string: fullURL) else {
            print("Failed to create URL from: \(fullURL)")
            throw APIError.invalidURL
        }
        
        print("Successfully created URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("Created request with URL: \(request.url?.absoluteString ?? "nil")")
        
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
            
            // Additional debugging for auth endpoints
            if request.url?.path.contains("auth") == true {
                print("Auth endpoint called: \(request.url?.absoluteString ?? "unknown")")
                print("Response status: \(httpResponse.statusCode)")
            }
            
            // Check for HTTP errors
            if httpResponse.statusCode == 401 {
                clearAuthToken()
                throw APIError.unauthorized
            }
            
            // Content-Type check: ensure JSON
            if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"), !contentType.contains("application/json") {
                let snippet = String(data: data.prefix(200), encoding: .utf8) ?? "<non-utf8>"
                throw APIError.decodingError(NSError(domain: "APIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Expected JSON but got \(contentType). Snippet: \(snippet)"]))
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
                print("About to decode response data as type: \(responseType)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw JSON being decoded: \(responseString)")
                }
                let result = try decoder.decode(responseType, from: data)
                print("Successfully decoded response as: \(type(of: result))")
                return result
            } catch {
                print("JSON Decoding failed for type \(responseType): \(error)")
                throw APIError.decodingError(error)
            }
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Authentication
    func register(username: String, password: String) async throws -> AuthResponseV2 {
        var request = try createRequest(for: "auth/register", method: "POST")
        
        let body = [
            "username": username,
            "password": password
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let response = try await performRequest(request, responseType: AuthResponseV2.self)
        
        if response.success, let token = response.token {
            setAuthToken(token)
        }
        
        return response
    }
    
    func login(username: String, password: String) async throws -> AuthResponseV2 {
        print("🚀 NEW LOGIN METHOD CALLED - If you see this, the new code is working!")
        var request = try createRequest(for: "auth/login", method: "POST")
        
        let body = [
            "username": username,
            "password": password
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let response = try await performRequest(request, responseType: AuthResponseV2.self)
        
        if response.success, let token = response.token {
            setAuthToken(token)
        }
        
        return response
    }
    
    func logout() async throws {
        // Call server logout endpoint
        if isAuthenticated {
            do {
                let request = try createRequest(for: "auth/logout", method: "POST")
                let _: APIResponse<String> = try await performRequest(request, responseType: APIResponse<String>.self)
            } catch {
                // Log error but continue with local logout
                print("Server logout failed: \(error)")
            }
        }
        
        // Clear local token
        clearAuthToken()
    }
    
    func getProfile() async throws -> User {
        let request = try createRequest(for: "auth/profile", method: "GET")
        let response = try await performRequest(request, responseType: APIResponse<User>.self)
        
        if response.success, let user = response.data {
            return user
        } else {
            throw APIError.serverError(response.message ?? "Failed to get profile")
        }
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
    
    // MARK: - CSV Export
    func exportJourneysCSV() async throws -> Data {
        let request = try createRequest(for: "journeys/export/csv", method: "GET")
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                throw APIError.serverError("CSV export failed")
            }
            return data
        } catch {
            throw APIError.networkError(error)
        }
    }
} 