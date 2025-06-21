import Foundation
import UIKit

class CSVExporter {
    static func exportJourneys(_ journeys: [Journey]) -> URL? {
        let csvContent = generateCSVContent(journeys)
        
        // Create temporary file
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "journeys_export_\(DateFormatter.filenameDateFormatter.string(from: Date())).csv"
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error writing CSV file: \(error)")
            return nil
        }
    }
    
    private static func generateCSVContent(_ journeys: [Journey]) -> String {
        print("📄 CSV Export: Starting to generate CSV for \(journeys.count) journeys")
        
        var csvLines: [String] = []
        
        // Header - matching user's requested format
        let headers = [
            "Label",
            "Date",
            "Start Time",
            "Start Postcode",
            "End Time", 
            "End Postcode",
            "Duration",
            "Distance (miles)"
        ]
        csvLines.append(headers.joined(separator: ","))
        
        // Data rows
        for journey in journeys {
            // Extract date and time components using DateFormatter
            let dateFormatter = DateFormatter()
            let timeFormatter = DateFormatter()
            
            dateFormatter.dateFormat = "yyyy-MM-dd"
            timeFormatter.dateFormat = "HH:mm:ss"
            
            let startDate = journey.formattedStartTime.map { dateFormatter.string(from: $0) } ?? ""
            let startTime = journey.formattedStartTime.map { timeFormatter.string(from: $0) } ?? ""
            let endTime = journey.formattedEndTime.map { timeFormatter.string(from: $0) } ?? ""
            
            let label = escapeCSVField(journey.label ?? "")
            let startPostcode = escapeCSVField(journey.startPostcode)
            let endPostcode = escapeCSVField(journey.endPostcode ?? "")
            let distance = journey.distanceMiles.map { String(format: "%.2f", $0) } ?? ""
            let duration = calculateDuration(start: journey.formattedStartTime, end: journey.formattedEndTime)
            
            print("CSV Export Debug - Journey \(journey.id):")
            print("  Raw startTime string: '\(journey.startTime)'")
            print("  Raw endTime string: '\(journey.endTime ?? "nil")'")
            print("  Parsed formattedStartTime: \(journey.formattedStartTime?.description ?? "nil")")
            print("  Parsed formattedEndTime: \(journey.formattedEndTime?.description ?? "nil")")
            print("  Label: '\(label)'")
            print("  Start Date: '\(startDate)'")
            print("  Start Time: '\(startTime)'")
            print("  End Time: '\(endTime)'")
            print("  Duration: '\(duration)'")
            print("  Distance: '\(distance)'")
            print("  Raw journey.label: '\(journey.label ?? "nil")'")
            print("  Raw journey.distanceMiles: '\(journey.distanceMiles?.description ?? "nil")'")
            print("  Journey.label is nil: \(journey.label == nil)")
            print("  Journey.label is empty: \(journey.label?.isEmpty ?? false)")
            print("  Escaped label: '\(label)'")
            print("  Full journey object: \(journey)")
            
            let row = [
                label,          // Label (user created)
                startDate,      // Date
                startTime,      // Start time
                startPostcode,  // Start postcode
                endTime,        // End time
                endPostcode,    // End postcode
                duration,       // Duration
                distance        // Distance
            ]
            csvLines.append(row.joined(separator: ","))
        }
        
        return csvLines.joined(separator: "\n")
    }
    
    private static func escapeCSVField(_ field: String) -> String {
        // Escape fields that contain commas, quotes, or newlines
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
    
    private static func calculateDuration(start: Date?, end: Date?) -> String {
        guard let start = start, let end = end else { return "" }
        
        let duration = Int(end.timeIntervalSince(start))
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

extension DateFormatter {
    static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
} 