import Foundation

struct Postcode: Codable, Identifiable {
    let id: Int
    let code: String
    let latitude: Double
    let longitude: Double
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case code
        case latitude
        case longitude
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Distance: Codable {
    let distance: Double
    let unit: String
}

struct User: Codable {
    let id: Int
    let username: String
} 