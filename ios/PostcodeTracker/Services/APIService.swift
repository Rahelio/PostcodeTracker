import Foundation

// Import model files
import PostcodeTracker

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    case rateLimitExceeded
    case redirectError
    case connectionError
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL - Please check your server configuration"
        case .networkError(let error):
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    return "No internet connection. Please check your network settings."
                case .timedOut:
                    return "Connection timed out. Please try again."
                case .cannotFindHost:
                    return "Cannot connect to server. Please check your internet connection."
                case .cannotConnectToHost:
                    return "Cannot connect to server. Please try again later."
                case .secureConnectionFailed:
                    return "Secure connection failed. Please try again."
                default:
                    return "Network error: \(urlError.localizedDescription) (Code: \(urlError.code.rawValue))"
                }
            }
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server - The server returned an unexpected response"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unauthorized:
            return "Unauthorized - Please check your credentials and try logging in again"
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment and try again."
        case .redirectError:
            return "Connection error - The server is redirecting incorrectly. Please try again."
        case .connectionError:
            return "Unable to connect to server. Please check your internet connection and try again."
        case .unknown:
            return "An unknown error occurred. Please try again."
        }
    }
    
    var debugDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network Error: \(error)"
        case .invalidResponse:
            return "Invalid Response"
        case .decodingError(let error):
            return "Decoding Error: \(error)"
        case .serverError(let message):
            return "Server Error: \(message)"
        case .unauthorized:
            return "Unauthorized"
        case .rateLimitExceeded:
            return "Rate Limit Exceeded"
        case .redirectError:
            return "Redirect Error"
        case .connectionError:
            return "Connection Error"
        case .unknown:
            return "Unknown Error"
        }
    }
}

// MARK: - Model Structs (Defined in separate files)

// struct LoginResponse: Codable { ... }
// struct RegisterResponse: Codable { ... }
// struct ErrorResponse: Codable { ... }
// struct Postcode: Codable, Identifiable { ... }
// struct Journey: Codable, Identifiable { ... }

struct PostcodeResponse: Codable {
    let success: Bool
    let postcode: String  // The server returns the postcode as a string, not a Postcode object
}

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
}

// Add response wrapper structs
struct JourneyResponse: Codable {
    let success: Bool
    let journeys: [Journey]
}

struct EndJourneyResponse: Codable {
    let message: String
    let journey: Journey
}

// Custom URLSession delegate to handle redirects
class CustomURLSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        print("Redirect detected:")
        print("From: \(response.url?.absoluteString ?? "unknown")")
        print("To: \(request.url?.absoluteString ?? "unknown")")
        print("Status code: \(response.statusCode)")
        print("Headers: \(response.allHeaderFields)")
        
        // Only allow redirects to HTTPS URLs
        if let newURL = request.url, newURL.scheme == "https" {
            var newRequest = request
            // Add headers to prevent redirect loops
            newRequest.addValue("no-cache, no-store, must-revalidate", forHTTPHeaderField: "Cache-Control")
            newRequest.addValue("no-cache", forHTTPHeaderField: "Pragma")
            newRequest.addValue("0", forHTTPHeaderField: "Expires")
            newRequest.addValue("keep-alive", forHTTPHeaderField: "Connection")
            completionHandler(newRequest)
        } else {
            completionHandler(nil)
        }
    }
}

class APIService {
    static let shared = APIService()
    private let baseURL = "https://rickys.ddns.net/LocationApp/api"
    private var authToken: String?
    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 1.0
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    private let session: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        // Configure URLSession to handle redirects
        let delegate = CustomURLSessionDelegate()
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
    
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }
    
    private func waitForRateLimit() async {
        if let lastRequest = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            if timeSinceLastRequest < minimumRequestInterval {
                try? await Task.sleep(nanoseconds: UInt64((minimumRequestInterval - timeSinceLastRequest) * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
    }
    
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
    }
    
    private func createRequest(path: String, method: String) throws -> URLRequest {
        let urlString = "\(baseURL)\(path)"
        print("Attempting to create URL from string: \(urlString)")
        
        guard let encodedString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedString) else {
            print("Failed to create valid URL from string: \(urlString)")
            throw APIError.invalidURL
        }
        
        print("Successfully created URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("Created request with URL: \(request.url?.absoluteString ?? "nil")")
        return request
    }
    
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
            }
            throw APIError.serverError("Cannot delete postcode that is used in journeys")
        } else if httpResponse.statusCode == 404 {
            throw APIError.serverError("Postcode not found")
        } else {
            do {
                let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
                print("Server error response: \(error.error)")
                throw APIError.serverError(error.error)
            } catch {
                print("Failed to decode error response: \(error)")
                print("Error response data: \(String(data: data, encoding: .utf8) ?? "")")
                throw APIError.serverError("Unknown server error: \(httpResponse.statusCode)")
            }
        }
    }
    
    func getPostcodeFromCoordinates(latitude: Double, longitude: Double) async throws -> Postcode? {
        var request = try createRequest(path: "/postcode/from-coordinates", method: "POST")
        
        // Create request body with coordinates
        let body = ["latitude": latitude, "longitude": longitude]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("Get Postcode from Coords Request URL: \(request.url?.absoluteString ?? "")")
        print("Get Postcode from Coords Request Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Get Postcode from Coords Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")
        
        let (data, response) = try await session.data(for: request)
        
        // Log raw response data
        print("Get Postcode from Coords Raw Response: \(String(data: data, encoding: .utf8) ?? "")")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Get Postcode from Coords: Invalid response type")
            throw APIError.invalidResponse
        }
        
        print("Get Postcode from Coords: Received HTTP Status Code: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            do {
                let response = try JSONDecoder().decode(PostcodeResponse.self, from: data)
                print("Get Postcode from Coords: Successfully decoded response.")
                if response.success {
                    // Create a Postcode object from the string using the new initializer
                    return Postcode(from: response.postcode)
                } else {
                    print("Get Postcode from Coords: Server returned success: false")
                    return nil
                }
            } catch {
                print("Get Postcode from Coords: Decoding error: \(error.localizedDescription)")
                print("Get Postcode from Coords: Failed to decode response: \(String(data: data, encoding: .utf8) ?? "")")
                throw APIError.decodingError(error)
            }
        } else if httpResponse.statusCode == 404 { // Handle 404 specifically for not found
            print("Get Postcode from Coords: Received 404, postcode not found.")
            return nil // Return nil if postcode is not found
        } else if httpResponse.statusCode == 401 {
            print("Get Postcode from Coords: Received 401, unauthorized.")
            throw APIError.unauthorized
        } else {
            print("Get Postcode from Coords: Received unexpected status code: \(httpResponse.statusCode)")
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                print("Get Postcode from Coords: Decoded server error message: \(errorResponse.error)")
                throw APIError.serverError(errorResponse.error)
            } else {
                print("Get Postcode from Coords: Failed to decode error response. Raw data: \(String(data: data, encoding: .utf8) ?? "")")
                throw APIError.invalidResponse
            }
        }
    }
    
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
        let url = URL(string: "\(baseURL)/journeys/\(journeyId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        if let token = authToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
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
        
        let body = ["latitude": latitude, "longitude": longitude]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
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
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("End Tracked Journey Request URL: \(request.url?.absoluteString ?? "")")
        print("End Tracked Journey Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")
        
        let (data, response) = try await session.data(for: request)
        
        print("End Tracked Journey Raw Response Data: \(String(data: data, encoding: .utf8) ?? "")")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("End Tracked Journey Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let response = try JSONDecoder().decode(EndJourneyResponse.self, from: data)
            return response.journey
        } else if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        } else if httpResponse.statusCode == 404 {
            // Journey not found, perhaps already ended or invalid ID
            throw APIError.serverError("Journey not found or already ended.")
        } else {
            let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(error.error)
        }
    }
} 
