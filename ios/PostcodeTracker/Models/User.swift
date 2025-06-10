import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let createdAt: String
    
    // Journey statistics (optional - only available from profile endpoint)
    let totalJourneys: Int?
    let completedJourneys: Int?
    let totalDistanceMiles: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case createdAt = "created_at"
        case totalJourneys = "total_journeys"
        case completedJourneys = "completed_journeys"
        case totalDistanceMiles = "total_distance_miles"
    }
    
    var formattedCreatedAt: Date? {
        ISO8601DateFormatter().date(from: createdAt)
    }
} 