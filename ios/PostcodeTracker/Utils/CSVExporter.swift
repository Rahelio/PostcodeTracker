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
        
        // Header
        let headers = [
            "Journey ID",
            "Start Postcode",
            "End Postcode", 
            "Start Time",
            "End Time",
            "Distance (Miles)",
            "Duration",
            "Status",
            "Start Latitude",
            "Start Longitude",
            "End Latitude",
            "End Longitude"
        ]
        csvLines.append(headers.joined(separator: ","))
        
        // Data rows
        for journey in journeys {
            let row = [
                "\(journey.id)",
                escapeCSVField(journey.startPostcode),
                escapeCSVField(journey.endPostcode ?? ""),
                escapeCSVField(journey.startTime),
                escapeCSVField(journey.endTime ?? ""),
                journey.distanceMiles != nil ? String(format: "%.2f", journey.distanceMiles!) : "",
                calculateDuration(start: journey.formattedStartTime, end: journey.formattedEndTime),
                journey.isActive ? "Active" : "Completed",
                journey.startLatitude != nil ? "\(journey.startLatitude!)" : "",
                journey.startLongitude != nil ? "\(journey.startLongitude!)" : "",
                journey.endLatitude != nil ? "\(journey.endLatitude!)" : "",
                journey.endLongitude != nil ? "\(journey.endLongitude!)" : ""
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
        
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = Int(duration % 3600) / 60
        
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