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