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
}

// MARK: - Journey Model
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