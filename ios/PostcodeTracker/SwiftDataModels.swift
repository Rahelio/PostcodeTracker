import Foundation
import SwiftData

@Model
final class JourneyLocal {
    @Attribute(.unique) var id: Int
    var startPostcode: String
    var endPostcode: String?
    var startTime: Date
    var endTime: Date?
    var distanceMiles: Double?
    var isActive: Bool

    init(id: Int,
         startPostcode: String,
         endPostcode: String? = nil,
         startTime: Date,
         endTime: Date? = nil,
         distanceMiles: Double? = nil,
         isActive: Bool = false) {
        self.id = id
        self.startPostcode = startPostcode
        self.endPostcode = endPostcode
        self.startTime = startTime
        self.endTime = endTime
        self.distanceMiles = distanceMiles
        self.isActive = isActive
    }
}

@MainActor
enum SwiftDataStack {
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: JourneyLocal.self)
        } catch {
            fatalError("Failed to initialise SwiftData container: \(error)")
        }
    }()
} 