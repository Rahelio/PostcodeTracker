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
            // Extract date and time components
            let startDate = journey.formattedStartTime?.formatted(date: .numeric, time: .omitted) ?? ""
            let startTime = journey.formattedStartTime?.formatted(date: .omitted, time: .standard) ?? ""
            let endTime = journey.formattedEndTime?.formatted(date: .omitted, time: .standard) ?? ""
            
            let label = escapeCSVField(journey.label ?? "")
            let startPostcode = escapeCSVField(journey.startPostcode)
            let endPostcode = escapeCSVField(journey.endPostcode ?? "")
            let distance = journey.distanceMiles.map { String(format: "%.2f", $0) } ?? ""
            let duration = calculateDuration(start: journey.formattedStartTime, end: journey.formattedEndTime)
            
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
        return formatter
    }()
} 