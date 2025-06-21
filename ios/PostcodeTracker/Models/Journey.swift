import Foundation

struct Journey: Codable, Identifiable {
    let id: Int
    let userId: Int
    let startTime: String
    let endTime: String?
    let startLatitude: Double?
    let startLongitude: Double?
    let endLatitude: Double?
    let endLongitude: Double?
    let startPostcode: String
    let endPostcode: String?
    let distanceMiles: Double?
    let isActive: Bool
    let label: String?
    private let _isManual: Bool?
    let startLocation: Postcode?
    let endLocation: Postcode?
    
    init(id: Int,
         userId: Int,
         startTime: String,
         endTime: String?,
         startLatitude: Double?,
         startLongitude: Double?,
         endLatitude: Double?,
         endLongitude: Double?,
         startPostcode: String,
         endPostcode: String?,
         distanceMiles: Double?,
         isActive: Bool,
         label: String? = nil,
         isManual: Bool? = nil,
         startLocation: Postcode? = nil,
         endLocation: Postcode? = nil) {
        self.id = id
        self.userId = userId
        self.startTime = startTime
        self.endTime = endTime
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.startPostcode = startPostcode
        self.endPostcode = endPostcode
        self.distanceMiles = distanceMiles
        self.isActive = isActive
        self.label = label
        self._isManual = isManual
        self.startLocation = startLocation
        self.endLocation = endLocation
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case startLatitude = "start_latitude"
        case startLongitude = "start_longitude"
        case endLatitude = "end_latitude"
        case endLongitude = "end_longitude"
        case startPostcode = "start_postcode"
        case endPostcode = "end_postcode"
        case distanceMiles = "distance_miles"
        case isActive = "is_active"
        case label = "label"
        case _isManual = "is_manual"
        case startLocation = "start_location"
        case endLocation = "end_location"
    }
    
    var isManual: Bool {
        return _isManual ?? false
    }
    
    // MARK: - Computed Properties
    var formattedStartTime: Date? {
        return parseISODate(startTime)
    }
    
    var formattedEndTime: Date? {
        guard let endTime = endTime else { return nil }
        return parseISODate(endTime)
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
    
    // Helper method to parse ISO dates with microseconds
    private func parseISODate(_ dateString: String) -> Date? {
        // Try multiple formatters to handle different timestamp formats
        let formatters = [
            // Format with microseconds and Z timezone
            createDateFormatter(format: "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"),
            // Format with microseconds, no timezone (assume UTC)
            createDateFormatter(format: "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"),
            // Format with milliseconds and Z timezone
            createDateFormatter(format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"),
            // Format with milliseconds, no timezone (assume UTC)
            createDateFormatter(format: "yyyy-MM-dd'T'HH:mm:ss.SSS"),
            // Format without fractional seconds and Z timezone
            createDateFormatter(format: "yyyy-MM-dd'T'HH:mm:ss'Z'"),
            // Format without fractional seconds, no timezone (assume UTC)
            createDateFormatter(format: "yyyy-MM-dd'T'HH:mm:ss")
        ]
        
        // Try parsing with each formatter
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        // If all else fails, try ISO8601DateFormatter as backup
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return isoFormatter.date(from: dateString)
    }
    
    private func createDateFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
} 