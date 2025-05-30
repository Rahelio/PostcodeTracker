import Foundation
import PostcodeTracker // Import the main module to access model structs

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(String)
    case unauthorized
<<<<<<< Updated upstream
=======
    case unknown
>>>>>>> Stashed changes
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
<<<<<<< Updated upstream
            return "Invalid URL - Please check your server configuration"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .unauthorized:
            return "Unauthorized"
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
=======
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Error processing server response: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unauthorized:
            return "Invalid username or password"
        case .unknown:
            return "An unknown error occurred"
        }
    }
>>>>>>> Stashed changes
}

class APIService {
    static let shared = APIService()
    private let baseURL = "https://rickys.ddns.net/LocationApp/api"
    private var authToken: String?
<<<<<<< Updated upstream
=======
    private let baseURL = "http://localhost:5319/api"
>>>>>>> Stashed changes
    
    private init() {}
    
    func setAuthToken(_ token: String?) {
        self.authToken = token
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
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("Created request with URL: \(request.url?.absoluteString ?? "nil")")
        return request
    }
    
    // MARK: - Authentication
    
    func register(username: String, password: String) async throws -> String {
        do {
            var request = try createRequest(path: "/auth/register", method: "POST")
        
        let body = ["username": username, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            print("Registration Request URL: \(request.url?.absoluteString ?? "")")
            print("Registration Request Headers: \(request.allHTTPHeaderFields ?? [:])")
            print("Registration Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")
        
        let (data, response) = try await URLSession.shared.data(for: request)
            
<<<<<<< Updated upstream
            print("Registration Response Data: \(String(data: data, encoding: .utf8) ?? "")")
        
        guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
            throw APIError.invalidResponse
        }
            
            print("Registration Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 201 {
=======
            // Print response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Server response: \(responseString)")
            }
            
            switch httpResponse.statusCode {
            case 200...299:
>>>>>>> Stashed changes
                do {
            let result = try JSONDecoder().decode(RegisterResponse.self, from: data)
            return result.message
                } catch {
<<<<<<< Updated upstream
                    print("Registration Decoding Error: \(error)")
=======
                    print("Decoding error: \(error)")
>>>>>>> Stashed changes
                    throw APIError.decodingError(error)
                }
        } else {
                do {
            let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(error.error)
                } catch {
                    print("Registration Error Decoding Error: \(error)")
                    throw APIError.decodingError(error)
                }
            }
        } catch {
            print("Registration Error: \(error)")
            throw error
        }
    }
    
    func login(username: String, password: String) async throws -> String {
        do {
            var request = try createRequest(path: "/auth/login", method: "POST")
        
        let body = ["username": username, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            print("Login Request URL: \(request.url?.absoluteString ?? "")")
            print("Login Request Headers: \(request.allHTTPHeaderFields ?? [:])")
            print("Login Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")
        
        let (data, response) = try await URLSession.shared.data(for: request)
            
            print("Login Response Data: \(String(data: data, encoding: .utf8) ?? "")")
        
        guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
            throw APIError.invalidResponse
        }
            
            print("Login Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
                do {
            let result = try JSONDecoder().decode(LoginResponse.self, from: data)
            return result.access_token
                } catch {
                    print("Login Decoding Error: \(error)")
                    throw APIError.decodingError(error)
                }
        } else {
                do {
            let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(error.error)
                } catch {
                    print("Login Error Decoding Error: \(error)")
                    throw APIError.decodingError(error)
                }
            }
        } catch {
            print("Login Error: \(error)")
            throw error
        }
    }
    
    // MARK: - Postcodes
    
    func getPostcodes() async throws -> [Postcode] {
        print("APIService: Attempting to fetch postcodes")
        let request = try createRequest(path: "/postcodes", method: "GET")
        
        print("APIService: Request URL: \(request.url?.absoluteString ?? "nil")")
        print("APIService: Request Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            print("APIService: Response received")
            print("APIService: Response Data: \(String(data: data, encoding: .utf8) ?? "")")
        
        guard let httpResponse = response as? HTTPURLResponse else {
                print("APIService: Invalid response type")
            throw APIError.invalidResponse
        }
            
            print("APIService: Response Status Code: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
                do {
                    let postcodes = try JSONDecoder().decode([Postcode].self, from: data)
                    print("APIService: Successfully decoded \(postcodes.count) postcodes")
                    return postcodes
                } catch {
                    print("APIService: Decoding error: \(error)")
                    throw APIError.decodingError(error)
                }
        } else if httpResponse.statusCode == 401 {
                print("APIService: Unauthorized error")
            throw APIError.unauthorized
        } else {
                do {
            let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
                    print("APIService: Server error: \(error.error)")
            throw APIError.serverError(error.error)
                } catch {
                    print("APIService: Error decoding error response: \(error)")
                    throw APIError.serverError("Unknown server error")
                }
            }
        } catch let error as APIError {
            print("APIService: API Error: \(error.localizedDescription)")
            throw error
        } catch {
            print("APIService: Network Error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
    }
    
    func addPostcode(_ postcode: String, name: String) async throws -> Postcode {
        var request = try createRequest(path: "/postcodes", method: "POST")
        
        let body = ["postcode": postcode, "name": name]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("Add Postcode Request URL: \(request.url?.absoluteString ?? "")")
        print("Add Postcode Request Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Add Postcode Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("Add Postcode Response Data: \(String(data: data, encoding: .utf8) ?? "")")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("Add Postcode Response Status: \(httpResponse.statusCode)")
        
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
        let request = try createRequest(path: "/postcodes/\(id)", method: "DELETE")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
    
    func getPostcodeFromCoordinates(latitude: Double, longitude: Double) async throws -> Postcode? {
        var request = try createRequest(path: "/postcode/from-coordinates", method: "POST")
        
        // Create request body with coordinates
        let body = ["latitude": latitude, "longitude": longitude]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("Get Postcode from Coords Request URL: \(request.url?.absoluteString ?? "")")
        print("Get Postcode from Coords Request Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Get Postcode from Coords Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode([Journey].self, from: data)
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
    
    func createManualJourney(startPostcode: String, endPostcode: String) async throws -> Journey {
        var request = try createRequest(path: "/journeys/manual", method: "POST")
        
        let body = ["start_postcode": startPostcode, "end_postcode": endPostcode]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("Create Manual Journey Request URL: \(request.url?.absoluteString ?? "")")
        print("Create Manual Journey Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            return try JSONDecoder().decode(Journey.self, from: data)
        } else if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        } else {
            let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(error.error)
        }
    }
    
    func deleteJourney(ids: [Int]) async throws {
        var request = try createRequest(path: "/journeys", method: "DELETE")
        
        let body = ["journey_ids": ids]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("Delete Journeys Request URL: \(request.url?.absoluteString ?? "")")
        print("Delete Journeys Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
        var request = try createRequest(path: "/journey/end", method: "POST")
        
        let body = ["journey_id": journeyId, "latitude": latitude, "longitude": longitude] as [String : Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("End Tracked Journey Request URL: \(request.url?.absoluteString ?? "")")
        print("End Tracked Journey Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("End Tracked Journey Raw Response Data: \(String(data: data, encoding: .utf8) ?? "")")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("End Tracked Journey Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let journey = try JSONDecoder().decode(Journey.self, from: data)
            return journey
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
