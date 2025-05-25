import Foundation

struct LoginResponse: Codable {
    let access_token: String
}

struct RegisterResponse: Codable {
    let message: String
}

struct ErrorResponse: Codable {
    let error: String
} 