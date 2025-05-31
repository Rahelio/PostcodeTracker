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
                    return "Network error: \(urlError.localizedDescription)"
                }
            }
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .unauthorized:
            return "Unauthorized - Please check your credentials"
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment and try again."
        case .redirectError:
            return "Connection error. Please check your internet connection and try again."
        case .connectionError:
            return "Unable to connect to server. Please check your internet connection."
        case .unknown:
            return "An unknown error occurred. Please try again."
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
}

// Add response wrapper structs
struct JourneyResponse: Codable {
    let success: Bool
    let journeys: [Journey]
}

struct EndJourneyResponse: Codable {
    let success: Bool
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
            case 301, 302, 307, 308:
                // Handle redirects
                if retryCount < maxRetries {
                    print("Following redirect...")
                    if let location = httpResponse.allHeaderFields["Location"] as? String,
                       let newURL = URL(string: location) {
                        var newRequest = request
                        newRequest.url = newURL
                        try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        return try await performRequest(newRequest, retryCount: retryCount + 1)
                    }
                }
                throw APIError.redirectError
            case 401:
                throw APIError.unauthorized
            case 429:
                throw APIError.rateLimitExceeded
            default:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw APIError.serverError(errorResponse.error)
                }
                throw APIError.serverError("Server error: \(httpResponse.statusCode)")
            }
        } catch let error as APIError {
            throw error
        } catch let error as URLError {
            print("URL Error occurred: \(error.localizedDescription)")
            switch error.code {
            case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost:
                throw APIError.connectionError
            case .httpTooManyRedirects:
                throw APIError.redirectError
            default:
                throw APIError.networkError(error)
            }
        } catch {
            print("Unexpected error occurred: \(error)")
            throw APIError.networkError(error)
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
        
        // Add headers to prevent redirect loops
        request.setValue("no-cache, no-store, must-revalidate", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("0", forHTTPHeaderField: "Expires")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
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
        return try await performRequest(request)
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
        
        print("Get Journeys Request URL: \(request.url?.absoluteString ?? "")")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let response = try JSONDecoder().decode(JourneyResponse.self, from: data)
            return response.journeys
        } else if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        } else {
            let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(error.error)
        }
    }
    
    func createJourney(startPostcode: String, endPostcode: String) async throws -> Journey {
        var request = try createRequest(path: "/journeys", method: "POST")
        
        let body = ["start_postcode": startPostcode, "end_postcode": endPostcode]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("Create Journey Request URL: \(request.url?.absoluteString ?? "")")
        print("Create Journey Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")
        
        let (data, response) = try await session.data(for: request)
        
        // Log raw response data
        print("Create Journey Raw Response Data: \(String(data: data, encoding: .utf8) ?? "")")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("Create Journey Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 201 {
            return try JSONDecoder().decode(Journey.self, from: data)
        } else if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        } else {
            let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(error.error)
        }
    }
    
    // Add this new method to get a postcode by its code
    func getPostcodeByCode(_ postcode: String) async throws -> Postcode? {
        let request = try createRequest(path: "/postcodes", method: "GET")
        let postcodes: [Postcode] = try await performRequest(request)
        return postcodes.first { $0.postcode == postcode }
    }
    
    func createManualJourney(startPostcode: String, endPostcode: String) async throws -> Journey {
        // First, check if the postcodes already exist
        let startLocation: Postcode
        if let existing = try await getPostcodeByCode(startPostcode) {
            print("Using existing start location with ID: \(existing.id)")
            startLocation = existing
        } else {
            print("Creating new start location")
            startLocation = try await addPostcode(startPostcode, name: "Start: \(startPostcode)")
        }
        
        let endLocation: Postcode
        if let existing = try await getPostcodeByCode(endPostcode) {
            print("Using existing end location with ID: \(existing.id)")
            endLocation = existing
        } else {
            print("Creating new end location")
            endLocation = try await addPostcode(endPostcode, name: "End: \(endPostcode)")
        }
        
        // Now create the journey using the location IDs
        var request = try createRequest(path: "/journey/manual", method: "POST")
        
        let body = [
            "start_location_id": startLocation.id,
            "end_location_id": endLocation.id
        ] as [String : Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("Create Manual Journey Request URL: \(request.url?.absoluteString ?? "")")
        print("Create Manual Journey Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")
        
        let (data, response) = try await session.data(for: request)
        
        // Log raw response data
        print("Create Manual Journey Raw Response Data: \(String(data: data, encoding: .utf8) ?? "")")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Create Manual Journey: Invalid response type")
            throw APIError.invalidResponse
        }
        
        print("Create Manual Journey Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            do {
                let response = try JSONDecoder().decode(EndJourneyResponse.self, from: data)
                print("Successfully decoded journey response")
                return response.journey
            } catch {
                print("Failed to decode journey response: \(error)")
                print("Response data: \(String(data: data, encoding: .utf8) ?? "")")
                throw APIError.decodingError(error)
            }
        } else if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
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
    
    func deleteJourney(ids: [Int]) async throws {
        var request = try createRequest(path: "/journeys", method: "DELETE")
        
        let body = ["journey_ids": ids]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("Delete Journeys Request URL: \(request.url?.absoluteString ?? "")")
        print("Delete Journeys Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            } else {
                let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
                throw APIError.serverError(error.error)
            }
        }
    }
    
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
    func startTrackedJourney(latitude: Double, longitude: Double) async throws -> Int? {
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
            let result = try JSONDecoder().decode(StartJourneyResponse.self, from: data)
            return result.journey_id
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
        // First, get the postcode from coordinates
        guard let postcode = try await getPostcodeFromCoordinates(latitude: latitude, longitude: longitude) else {
            throw APIError.serverError("Could not determine postcode for the provided coordinates")
        }
        
        // Now end the journey with the postcode
        var request = try createRequest(path: "/journey/end", method: "POST")
        
        let body = ["end_postcode": postcode.postcode] as [String : Any]
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
