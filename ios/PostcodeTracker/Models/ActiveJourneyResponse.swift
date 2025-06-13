import Foundation

struct ActiveJourneyResponse: Codable {
    let success: Bool
    let active: Bool
    let journey: Journey?
} 