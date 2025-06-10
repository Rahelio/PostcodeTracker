import Foundation
import CoreLocation

// Import model files
import PostcodeTracker

// MARK: - API Response Models
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let message: String?
    let data: T?
}

<<<<<<< HEAD
struct AuthResponse: Codable {
    let success: Bool
    let message: String
    let token: String?
    let user: User?
=======
// Add response struct for starting a journey
struct StartJourneyResponse: Codable {
    let journey_id: Int
    let message: String
}

// Enhanced response struct for starting a tracked journey with postcode data
struct StartTrackedJourneyResponse: Codable {
    let success: Bool
    let message: String
    let journey_id: Int
    let start_postcode: String
    let start_latitude: Double
    let start_longitude: Double
    let journey: Journey
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
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

<<<<<<< HEAD
struct PostcodeResponse: Codable {
    let success: Bool
    let postcode: String?
    let message: String?
=======
struct EndJourneyResponse: Codable {
    let message: String
    let journey: Journey
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
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
<<<<<<< HEAD
    
    private let baseURL = "http://rickys.ddns.net:8005/api"
    private let session = URLSession.shared
=======
    private let baseURL = "https://rickys.ddns.net/LocationApp/api"
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
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
    
<<<<<<< HEAD
    var isAuthenticated: Bool {
        return authToken != nil
=======
    private func performRequest<T: Decodable>(_ request: URLRequest, retryCount: Int = 0) async throws -> T {
        do {
            await waitForRateLimit()
            
            print("Making request to: \(request.url?.absoluteString ?? "unknown")")
            print("Request method: \(request.httpMethod ?? "unknown")")
            print("Request headers: \(request.allHTTPHeaderFields ?? [:])")
            if let body = request.httpBody {
                print("Request body: \(String(data: body, encoding: .utf8) ?? "none")")
            }
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type received")
                throw APIError.invalidResponse
            }
            
            print("Response status code: \(httpResponse.statusCode)")
            print("Response headers: \(httpResponse.allHeaderFields)")
            print("Response body: \(String(data: data, encoding: .utf8) ?? "none")")
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    print("Decoding error: \(error)")
                    throw APIError.decodingError(error)
                }
            case 401:
                throw APIError.unauthorized
            case 429:
                throw APIError.rateLimitExceeded
            case 500...599:
                throw APIError.serverError("Server error: \(httpResponse.statusCode)")
            default:
                throw APIError.unknown
            }
        } catch {
            if retryCount < maxRetries {
                print("Request failed, retrying... (Attempt \(retryCount + 1) of \(maxRetries))")
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                return try await performRequest(request, retryCount: retryCount + 1)
            }
            throw error
        }
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
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
    
<<<<<<< HEAD
    private func performRequest<T: Codable>(_ request: URLRequest, responseType: T.Type) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(NSError(domain: "Invalid response", code: -1))
=======
    // MARK: - Authentication
    
    func register(username: String, password: String) async throws -> String {
        var request = try createRequest(path: "/auth/register", method: "POST")
        let body = ["username": username, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let response: RegisterResponse = try await performRequest(request)
        return response.message
    }
    
    func login(username: String, password: String) async throws -> String {
        var request = try createRequest(path: "/auth/login", method: "POST")
        let body = ["username": username, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let response: LoginResponse = try await performRequest(request)
        return response.access_token
    }
    
    // MARK: - Postcodes
    
    func getPostcodes() async throws -> [Postcode] {
        let request = try createRequest(path: "/postcodes", method: "GET")
        print("GetPostcodes Request URL: \(request.url?.absoluteString ?? "unknown")")
        print("GetPostcodes Request Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let (data, response) = try await session.data(for: request)
        
        // Log raw response data
        print("GetPostcodes Raw Response Data: \(String(data: data, encoding: .utf8) ?? "none")")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("GetPostcodes: Invalid response type")
            throw APIError.invalidResponse
        }
        
        print("GetPostcodes Response Status: \(httpResponse.statusCode)")
        print("GetPostcodes Response Headers: \(httpResponse.allHeaderFields)")
        
        if httpResponse.statusCode == 200 {
            do {
                let postcodes = try JSONDecoder().decode([Postcode].self, from: data)
                print("Successfully decoded \(postcodes.count) postcodes")
                return postcodes
            } catch {
                print("GetPostcodes Decoding Error: \(error)")
                print("Failed to decode response: \(String(data: data, encoding: .utf8) ?? "none")")
                throw APIError.decodingError(error)
            }
        } else if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }
    
    func addPostcode(_ postcode: String, name: String) async throws -> Postcode {
        var request = try createRequest(path: "/postcodes", method: "POST")
        let body = ["postcode": postcode, "name": name]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return try await performRequest(request)
    }
    
    func deletePostcode(id: Int) async throws {
        let request = try createRequest(path: "/postcodes/\(id)", method: "DELETE")
        
        print("Delete Postcode Request URL: \(request.url?.absoluteString ?? "")")
        
        let (data, response) = try await session.data(for: request)
        
        // Log raw response data
        print("Delete Postcode Raw Response Data: \(String(data: data, encoding: .utf8) ?? "")")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Delete Postcode: Invalid response type")
            throw APIError.invalidResponse
        }
        
        print("Delete Postcode Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            print("Successfully deleted postcode with ID: \(id)")
            return
        } else if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        } else if httpResponse.statusCode == 400 {
            // Try to decode the error message
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
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
    
<<<<<<< HEAD
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
=======
    // MARK: - Journeys
    
    func getJourneys() async throws -> [Journey] {
        let request = try createRequest(path: "/journeys", method: "GET")
        
        let response: JourneyResponse = try await performRequest(request)
        return response.journeys
    }
    
    func startJourney(startPostcode: String, isManual: Bool = false) async throws -> Int {
        let url = URL(string: "\(baseURL)/journeys/start")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = [
            "start_postcode": startPostcode,
            "is_manual": isManual
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let response: StartJourneyResponse = try await performRequest(request)
        return response.journey_id
    }
    
    func endJourney(journeyId: Int, endPostcode: String, distanceMiles: Double) async throws -> Journey {
        let url = URL(string: "\(baseURL)/journeys/\(journeyId)/end")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = [
            "end_postcode": endPostcode,
            "distance_miles": distanceMiles
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let response: EndJourneyResponse = try await performRequest(request)
        return response.journey
    }
    
    func deleteJourney(journeyId: Int) async throws {
        // Use the correct endpoint that matches the server implementation
        var request = try createRequest(path: "/journeys/delete", method: "POST")
        
        // Create request body with journey_ids array
        let requestBody = ["journey_ids": [journeyId]]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let _: EmptyResponse = try await performRequest(request)
    }
    
    // Add this struct for empty responses
    private struct EmptyResponse: Codable {}
    
    func exportJourneys(journeyIds: [Int], format: String) async throws -> (Data, URLResponse) {
        print("Exporting journeys: \(journeyIds) in \(format) format")
        
        var request = try createRequest(path: "/journeys/export/\(format)", method: "POST")
        
        // Create request body
        let requestBody = ["journey_ids": journeyIds]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("Export request URL: \(request.url?.absoluteString ?? "unknown")")
        print("Export request headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Export request body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "none")")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Export response status code: \(httpResponse.statusCode)")
            print("Export response headers: \(httpResponse.allHeaderFields)")
            
            if httpResponse.statusCode == 200 {
                return (data, response)
            } else if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            } else {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw APIError.serverError(errorResponse.error)
                }
                throw APIError.invalidResponse
            }
        }
        
        throw APIError.invalidResponse
    }
    
    // Function to start a tracked journey
    func startTrackedJourney(latitude: Double, longitude: Double) async throws -> (journeyId: Int, postcode: Postcode)? {
        var request = try createRequest(path: "/journey/start", method: "POST")
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
<<<<<<< HEAD
        return try await performRequest(request, responseType: JourneyResponse.self)
    }
    
    func endJourney(latitude: Double, longitude: Double) async throws -> JourneyResponse {
        var request = try createRequest(for: "journey/end", method: "POST")
        
        let body = [
            "latitude": latitude,
            "longitude": longitude
        ]
        
=======
        print("Start Tracked Journey Request URL: \(request.url?.absoluteString ?? "")")
        print("Start Tracked Journey Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")
        
        let (data, response) = try await session.data(for: request)
        
        print("Start Tracked Journey Raw Response Data: \(String(data: data, encoding: .utf8) ?? "")")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("Start Tracked Journey Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 201 {
            let result = try JSONDecoder().decode(StartTrackedJourneyResponse.self, from: data)
            
            // Create a Postcode object from the response data
            let postcode = Postcode(
                id: 0, // Temporary ID for tracked postcodes
                name: result.start_postcode,
                postcode: result.start_postcode,
                latitude: result.start_latitude,
                longitude: result.start_longitude,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            return (journeyId: result.journey_id, postcode: postcode)
        } else if httpResponse.statusCode == 400 { // Handle 400 specifically for invalid postcode
             print("Start Tracked Journey: Received 400, invalid postcode.")
             return nil // Return nil if postcode is not found or invalid
        } else if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        } else {
            let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(error.error)
        }
    }
    
    // Function to end a tracked journey
    func endTrackedJourney(journeyId: Int, latitude: Double, longitude: Double) async throws -> Journey {
        // Send coordinates directly to server - let server handle postcode lookup
        var request = try createRequest(path: "/journey/end", method: "POST")
        
        let body = [
            "latitude": latitude,
            "longitude": longitude
        ] as [String : Any]
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return try await performRequest(request, responseType: JourneyResponse.self)
    }
    
    func getActiveJourney() async throws -> ActiveJourneyResponse {
        let request = try createRequest(for: "journey/active")
        return try await performRequest(request, responseType: ActiveJourneyResponse.self)
    }
    
    func getJourneys() async throws -> JourneysResponse {
        let request = try createRequest(for: "journeys")
        return try await performRequest(request, responseType: JourneysResponse.self)
    }
    
    // MARK: - Postcode
    func getPostcodeFromCoordinates(latitude: Double, longitude: Double) async throws -> PostcodeResponse {
        var request = try createRequest(for: "postcode/from-coordinates", method: "POST")
        
        let body = [
            "latitude": latitude,
            "longitude": longitude
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return try await performRequest(request, responseType: PostcodeResponse.self)
    }
    
    // MARK: - Health Check
    func healthCheck() async throws -> Bool {
        let request = try createRequest(for: "health")
        let response = try await performRequest(request, responseType: [String: String].self)
        return response["status"] == "healthy"
    }
} 
