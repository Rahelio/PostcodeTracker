import Foundation
import SwiftUI

struct Postcode: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let postcode: String
    let latitude: Double?
    let longitude: Double?
    let created_at: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case postcode
        case latitude
        case longitude
        case created_at
    }
    
    // Add custom initializer for creating a Postcode from just a postcode string
    init(from postcodeString: String) {
        self.id = 0  // Temporary ID
        self.name = postcodeString
        self.postcode = postcodeString
        self.latitude = nil
        self.longitude = nil
        self.created_at = ISO8601DateFormatter().string(from: Date())
    }
    
    // Add comprehensive initializer for API response data
    init(id: Int, name: String, postcode: String, latitude: Double?, longitude: Double?, created_at: String?) {
        self.id = id
        self.name = name
        self.postcode = postcode
        self.latitude = latitude
        self.longitude = longitude
        self.created_at = created_at
    }
}

// MARK: - Journey Model
struct Journey: Codable, Identifiable {
    let id: Int
    let start_postcode: String
    let end_postcode: String?       // Make optional since it's null when starting
    let distance_miles: Double?     // Make optional since it's null when starting
    let start_time: String
    let end_time: String?          // Make optional since it's null when starting
    let is_active: Bool
    let is_manual: Bool
    let start_location: Postcode?
    let end_location: Postcode?
    let userId: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case start_postcode
        case end_postcode
        case distance_miles
        case start_time
        case end_time
        case is_active
        case is_manual
        case start_location
        case end_location
        case userId = "user_id"
    }
    
    // MARK: - Computed Properties for Compatibility
    var startPostcode: String {
        return start_postcode
    }
    
    var endPostcode: String? {
        return end_postcode
    }
    
    var distanceMiles: Double? {
        return distance_miles
    }
    
    var isActive: Bool {
        return is_active
    }
    
    var formattedStartTime: Date? {
        ISO8601DateFormatter().date(from: start_time)
    }
    
    var formattedEndTime: Date? {
        guard let endTime = end_time else { return nil }
        return ISO8601DateFormatter().date(from: endTime)
    }
    
    var formattedDistance: String {
        guard let distance = distance_miles else {
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

// Remove the duplicate Journey state persistence struct definition
/*
struct JourneyState: Codable {
    let isRecording: Bool
    let startPostcode: Postcode?
    let endPostcode: Postcode?
    let distance: Double?
    let startTime: Date
    
    static func save(_ state: JourneyState) {
        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: "activeJourney")
        }
    }
    
    static func load() -> JourneyState? {
        guard let data = UserDefaults.standard.data(forKey: "activeJourney"),
              let state = try? JSONDecoder().decode(JourneyState.self, from: data) else {
            return nil
        }
        return state
    }
    
    static func clear() {
        UserDefaults.standard.removeObject(forKey: "activeJourney")
    }
}
*/ 