import Foundation

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
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

class APIService {
    static let shared = APIService()
    private let baseURL = "https://rickys.ddns.net/LocationApp/api"
    private var authToken: String?
    
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
            
            print("Registration Response Data: \(String(data: data, encoding: .utf8) ?? "")")
        
        guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
            throw APIError.invalidResponse
        }
            
            print("Registration Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 201 {
                do {
            let result = try JSONDecoder().decode(RegisterResponse.self, from: data)
            return result.message
                } catch {
                    print("Registration Decoding Error: \(error)")
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
        
        let body = ["latitude": latitude, "longitude": longitude]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(PostcodeResponse.self, from: data)
            if result.success {
                // Create a temporary postcode object with the postcode
                return Postcode(
                    id: 0,  // Temporary ID
                    name: result.postcode,  // Use postcode as name
                    postcode: result.postcode,
                    latitude: latitude,
                    longitude: longitude,
                    created_at: ISO8601DateFormatter().string(from: Date())
                )
            }
            return nil
        } else {
            let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(error.error)
        }
    }
    
    func createJourney(startPostcode: String, endPostcode: String) async throws -> Journey {
        var request = try createRequest(path: "/journey/start", method: "POST")
        
        let body = ["start_postcode": startPostcode]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Start the journey
        let (startData, startResponse) = try await URLSession.shared.data(for: request)
        
        guard let startHttpResponse = startResponse as? HTTPURLResponse,
              startHttpResponse.statusCode == 200 else {
            let error = try JSONDecoder().decode(ErrorResponse.self, from: startData)
            throw APIError.serverError(error.error)
        }
        
        // End the journey
        var endRequest = try createRequest(path: "/journey/end", method: "POST")
        let endBody = ["end_postcode": endPostcode]
        endRequest.httpBody = try JSONSerialization.data(withJSONObject: endBody)
        
        let (endData, endResponse) = try await URLSession.shared.data(for: endRequest)
        
        guard let endHttpResponse = endResponse as? HTTPURLResponse,
              endHttpResponse.statusCode == 200 else {
            let error = try JSONDecoder().decode(ErrorResponse.self, from: endData)
            throw APIError.serverError(error.error)
        }
        
        let journeyResponse = try JSONDecoder().decode(JourneyResponse.self, from: endData)
        return journeyResponse.journey
    }
    
    func getJourneys() async throws -> [Journey] {
        let request = try createRequest(path: "/journeys", method: "GET")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(JourneysResponse.self, from: data)
            return result.journeys
        } else if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        } else {
            let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(error.error)
        }
    }
    
    func deleteJourney(ids: [Int]) async throws {
        print("Attempting to delete journeys with IDs: \(ids)")
        
        // Check if we have an auth token
        guard let token = authToken else {
            print("No auth token available for deletion")
            throw APIError.unauthorized
        }
        
        print("Auth token: \(token)")
        
        // Use the correct endpoint and format
        var request = try createRequest(path: "/journeys/delete", method: "POST")
        
        // Create the request body with all journey IDs
        let body = ["journey_ids": ids]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("Delete request URL: \(request.url?.absoluteString ?? "nil")")
        print("Delete request headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Delete request body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "nil")")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type for journey deletion")
                throw APIError.invalidResponse
            }
            
            print("Delete response status code: \(httpResponse.statusCode)")
            if !data.isEmpty {
                print("Delete response data: \(String(data: data, encoding: .utf8) ?? "unable to decode")")
            }
            
            switch httpResponse.statusCode {
            case 200:
                print("Successfully deleted journeys: \(ids)")
                return
            case 401:
                print("Unauthorized attempt to delete journeys")
                throw APIError.unauthorized
            case 404:
                print("One or more journeys not found during deletion")
                throw APIError.serverError("One or more journeys not found")
            default:
                if !data.isEmpty {
                    do {
                        let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
                        print("Server error for journeys: \(error.error)")
                        throw APIError.serverError(error.error)
                    } catch {
                        print("Failed to decode error response: \(error)")
                        throw APIError.serverError("Failed to delete journeys: \(error.localizedDescription)")
                    }
                } else {
                    print("Empty response with status code \(httpResponse.statusCode)")
                    throw APIError.serverError("Server returned status code \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("Network error during journey operation: \(error)")
            throw error
        }
    }
    
    func createManualJourney(startPostcode: String, endPostcode: String) async throws -> Journey {
        var request = try createRequest(path: "/journey/manual", method: "POST")
        
        // First, get the location IDs for the postcodes
        let postcodes = try await getPostcodes()
        guard let startLocation = postcodes.first(where: { $0.postcode == startPostcode }),
              let endLocation = postcodes.first(where: { $0.postcode == endPostcode }) else {
            throw APIError.serverError("Could not find locations for the selected postcodes")
        }
        
        // Create the request body with location IDs
        let body = [
            "start_location_id": startLocation.id,
            "end_location_id": endLocation.id
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("Manual journey request URL: \(request.url?.absoluteString ?? "nil")")
        print("Manual journey request headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Manual journey request body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "nil")")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            print("Response type: \(type(of: response))")
            print("Response description: \(response)")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type: \(type(of: response))")
                throw APIError.invalidResponse
            }
            
            print("Manual journey response status code: \(httpResponse.statusCode)")
            if !data.isEmpty {
                print("Manual journey response data: \(String(data: data, encoding: .utf8) ?? "unable to decode")")
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                do {
                    let result = try JSONDecoder().decode(JourneyResponse.self, from: data)
                    print("Successfully decoded journey response: \(result)")
                    return result.journey
                } catch {
                    print("Failed to decode journey response: \(error)")
                    print("Raw response data: \(String(data: data, encoding: .utf8) ?? "unable to decode")")
                    throw APIError.decodingError(error)
                }
            } else if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            } else {
                do {
                    let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
                    throw APIError.serverError(error.error)
                } catch {
                    print("Failed to decode error response: \(error)")
                    print("Raw error data: \(String(data: data, encoding: .utf8) ?? "unable to decode")")
                    throw APIError.serverError("Failed to decode server response")
                }
            }
        } catch {
            print("Network error during manual journey creation: \(error)")
            throw error
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
}

// MARK: - Response Models

struct Postcode: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let postcode: String
    let latitude: Double?
    let longitude: Double?
    let created_at: String
    
    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Postcode, rhs: Postcode) -> Bool {
        lhs.id == rhs.id
    }
}

struct Journey: Codable, Identifiable {
    let id: Int
    let start_postcode: String
    let end_postcode: String
    let distance_miles: Double
    let start_time: String
    let end_time: String
    let is_active: Bool
    let is_manual: Bool
    let start_location: Postcode?
    let end_location: Postcode?
}

struct PostcodeResponse: Codable {
    let success: Bool
    let postcode: String
}

struct JourneyResponse: Codable {
    let success: Bool
    let message: String
    let journey: Journey
}

struct JourneysResponse: Codable {
    let success: Bool
    let journeys: [Journey]
} 
