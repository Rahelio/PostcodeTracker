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
    
    // Custom URLSession with appropriate timeouts
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0  // 30 seconds for request timeout
        config.timeoutIntervalForResource = 60.0 // 60 seconds for resource timeout
        config.waitsForConnectivity = true       // Wait for connectivity if needed
        return URLSession(configuration: config)
    }()
    
    private var authToken: String?
    
    private init() {
        // Load saved auth token
        self.authToken = UserDefaults.standard.string(forKey: "auth_token")
        print("🔥🔥🔥 NEW APIServiceV2 INITIALIZED - baseURL: \(baseURL)")
        print("🔥🔥🔥 Loaded auth token: \(authToken != nil ? "Present" : "None")")
        if let token = authToken {
            print("🔥🔥🔥 Token preview: \(token.prefix(20))...")
        }
        
        // Ensure we have the latest token from UserDefaults
        Task {
            await refreshTokenFromStorageIfNeeded()
        }
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
    
    func refreshTokenFromStorage() {
        let storedToken = UserDefaults.standard.string(forKey: "auth_token")
        if storedToken != authToken {
            print("🔄 Refreshing token from UserDefaults")
            print("- Current token: \(authToken != nil ? "Present" : "None")")
            print("- Stored token: \(storedToken != nil ? "Present" : "None")")
            self.authToken = storedToken
        }
    }
    
    private func refreshTokenFromStorageIfNeeded() async {
        // Small delay to ensure UserDefaults are fully synchronized
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        refreshTokenFromStorage()
    }
    
    var isAuthenticated: Bool {
        let hasToken = authToken != nil
        print("🔍 APIService.isAuthenticated check: \(hasToken)")
        if let token = authToken {
            print("- Token exists, length: \(token.count)")
        } else {
            print("- No token found")
        }
        return hasToken
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
            print("🔑 Added auth header with token: \(token.prefix(20))...")
        } else {
            print("⚠️ No auth token available for request")
        }
        
        print("Created request with URL: \(request.url?.absoluteString ?? "nil")")
        
        return request
    }
    
    private func performRequest<T: Codable>(_ request: URLRequest, responseType: T.Type) async throws -> T {
        print("🚀 Starting request to: \(request.url?.absoluteString ?? "unknown")")
        print("🔑 Token state at request start: \(authToken != nil ? "Present (\(authToken!.count) chars)" : "None")")
        
        // Debug the exact Authorization header being sent
        if let authHeader = request.value(forHTTPHeaderField: "Authorization") {
            print("🔑 Authorization header: \(authHeader.prefix(50))...")
        } else {
            print("⚠️ No Authorization header in request")
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            print("🔑 Token state after request: \(authToken != nil ? "Present (\(authToken!.count) chars)" : "None")")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(NSError(domain: "Invalid response", code: -1))
            }
            
            // Use the new handleResponse method
            return try await handleResponse(httpResponse, data: data, request: request)
        } catch {
            // If it's already an APIError, re-throw it as-is (don't wrap it)
            if let apiError = error as? APIError {
                throw apiError
            }
            
            // Handle network errors (including timeouts) without clearing auth token
            let nsError = error as NSError
            if nsError.code == NSURLErrorTimedOut {
                print("⏰ Request timed out - keeping auth token")
                throw APIError.networkError(NSError(domain: "NetworkTimeout", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: "Request timed out. Please check your internet connection and try again."]))
            } else if nsError.code == NSURLErrorNotConnectedToInternet {
                print("📡 No internet connection")
                throw APIError.networkError(NSError(domain: "NoInternet", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: "No internet connection. Please check your network and try again."]))
            } else {
                print("🔌 Network error: \(error.localizedDescription)")
                throw APIError.networkError(error)
            }
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
    func startJourney(latitude: Double, longitude: Double, clientName: String? = nil, rechargeToClient: Bool? = nil, description: String? = nil) async throws -> JourneyResponse {
        var request = try createRequest(for: "journey/start", method: "POST")
        
        var body: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude
        ]
        
        // Add new fields if provided
        if let clientName = clientName {
            body["client_name"] = clientName
        }
        if let rechargeToClient = rechargeToClient {
            body["recharge_to_client"] = rechargeToClient
        }
        if let description = description {
            body["description"] = description
        }
        
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
    
    func createManualJourney(startPostcode: String, endPostcode: String, clientName: String? = nil, rechargeToClient: Bool? = nil, description: String? = nil, date: Date? = nil) async throws -> JourneyResponse {
        var request = try createRequest(for: "journey/manual", method: "POST")
        
        var body: [String: Any] = [
            "start_postcode": startPostcode,
            "end_postcode": endPostcode
        ]
        
        // Add new fields if provided
        if let clientName = clientName {
            body["client_name"] = clientName
        }
        if let rechargeToClient = rechargeToClient {
            body["recharge_to_client"] = rechargeToClient
        }
        if let description = description {
            body["description"] = description
        }
        if let date = date {
            // Format date as ISO 8601 string for backend
            let formatter = ISO8601DateFormatter()
            body["journey_date"] = formatter.string(from: date)
        }
        
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
    
    // MARK: - Journey Deletion
    func deleteJourneys(journeyIds: [Int]) async throws -> APIResponse<String> {
        var request = try createRequest(for: "journeys/delete", method: "POST")
        
        let body = ["journey_ids": journeyIds]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return try await performRequest(request, responseType: APIResponse<String>.self)
    }
    
    // MARK: - Export Functions
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
    
    func exportJourneysExcel() async throws -> Data {
        let request = try createRequest(for: "journeys/export/excel", method: "GET")
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                throw APIError.serverError("Excel export failed")
            }
            return data
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    private func handleResponse<T: Decodable>(_ response: HTTPURLResponse, data: Data, request: URLRequest) async throws -> T {
        print("API Response (\(response.statusCode)): \(String(data: data, encoding: .utf8) ?? "No data")")
        
        // Check for 401 errors
        if response.statusCode == 401 {
            print("⚠️ Received 401 Unauthorized")
            print("- Request URL: \(request.url?.absoluteString ?? "unknown")")
            print("- Request had auth header: \(request.allHTTPHeaderFields?["Authorization"] != nil)")
            
            // Clear local token and throw unauthorized error
            print("🔄 401 Error: Clearing auth token...")
            clearAuthToken()
            throw APIError.unauthorized
        }
        
        // Handle other error status codes
        guard response.statusCode >= 200 && response.statusCode < 300 else {
            print("❌ API Error: \(response.statusCode)")
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Error details: \(errorJson)")
            }
            throw APIError.serverError("HTTP \(response.statusCode)")
        }
        
        // Decode the response
        do {
            print("About to decode response data as type: \(T.self)")
            print("Raw JSON being decoded: \(String(data: data, encoding: .utf8) ?? "No data")")
            let decodedResponse = try JSONDecoder().decode(T.self, from: data)
            print("Successfully decoded response as: \(T.self)")
            return decodedResponse
        } catch {
            print("JSON Decoding failed for type \(T.self): \(error)")
            throw APIError.decodingError(error)
        }
    }
} 