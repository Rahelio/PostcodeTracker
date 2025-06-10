import Foundation

struct Journey: Codable, Identifiable {
    let id: Int
    let startPostcode: String
    let endPostcode: String?
    let startTime: String
    let endTime: String?
    let distanceMiles: Double?
    let isActive: Bool
    let userId: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case startPostcode = "start_postcode"
        case endPostcode = "end_postcode"
        case startTime = "start_time"
        case endTime = "end_time"
        case distanceMiles = "distance_miles"
        case isActive = "is_active"
        case userId = "user_id"
    }
    
    var formattedStartTime: Date? {
        ISO8601DateFormatter().date(from: startTime)
    }
    
    var formattedEndTime: Date? {
        guard let endTime = endTime else { return nil }
        return ISO8601DateFormatter().date(from: endTime)
    }
    
    var formattedDistance: String {
        guard let distance = distanceMiles else {
            return "Distance not calculated"
        }
        return String(format: "%.2f miles", distance)
    }
    
    var duration: String {
        guard let start = formattedStartTime,
              let end = formattedEndTime else {
            return "Duration not available"
        }
        
        let interval = end.timeIntervalSince(start)
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
} 