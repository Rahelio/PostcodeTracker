import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case createdAt = "created_at"
    }
    
    var formattedCreatedAt: Date? {
        ISO8601DateFormatter().date(from: createdAt)
    }
} 