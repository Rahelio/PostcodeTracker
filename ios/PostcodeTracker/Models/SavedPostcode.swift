import Foundation
import SwiftData

@Model
class SavedPostcode {
    @Attribute(.unique) var id: UUID
    var postcode: String
    var label: String
    var dateAdded: Date
    
    init(postcode: String, label: String) {
        self.id = UUID()
        self.postcode = postcode.uppercased()
        self.label = label
        self.dateAdded = Date()
    }
    
    var formattedPostcode: String {
        return postcode.uppercased()
    }
}

// Helper for postcode formatting
extension String {
    func formatAsPostcode() -> String {
        let cleaned = self.replacingOccurrences(of: " ", with: "").uppercased()
        if cleaned.count > 4 {
            let firstPart = String(cleaned.prefix(4))
            let secondPart = String(cleaned.dropFirst(4))
            return "\(firstPart) \(secondPart)"
        }
        return cleaned
    }
    
    var isValidUKPostcode: Bool {
        let pattern = "^[A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: self.count)
        return regex?.firstMatch(in: self.uppercased(), options: [], range: range) != nil
    }
} 