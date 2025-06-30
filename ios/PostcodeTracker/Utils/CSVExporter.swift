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
        
        // Header - new format as requested
        let headers = [
            "Date",
            "Postcode From",
            "Postcode To",
            "Client Name",
            "Recharge to Client",
            "Description",
            "Total Miles"
        ]
        csvLines.append(headers.joined(separator: ","))
        
        // Data rows
        for journey in journeys {
            // Extract date component only (no time)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            let date = journey.formattedStartTime.map { dateFormatter.string(from: $0) } ?? ""
            let postcodeFrom = escapeCSVField(journey.startPostcode)
            let postcodeTo = escapeCSVField(journey.endPostcode ?? "")
            let clientName = escapeCSVField(journey.clientName ?? "")
            let rechargeToClient = journey.rechargeToClient == true ? "Yes" : (journey.rechargeToClient == false ? "No" : "")
            let description = escapeCSVField(journey.description ?? "")
            let totalMiles = journey.distanceMiles.map { String(format: "%.2f", $0) } ?? ""
            
            print("CSV Export Debug - Journey \(journey.id):")
            print("  Date: '\(date)'")
            print("  Postcode From: '\(postcodeFrom)'")
            print("  Postcode To: '\(postcodeTo)'")
            print("  Client Name: '\(clientName)'")
            print("  Recharge to Client: '\(rechargeToClient)'")
            print("  Description: '\(description)'")
            print("  Total Miles: '\(totalMiles)'")
            
            let row = [
                date,
                postcodeFrom,
                postcodeTo,
                clientName,
                rechargeToClient,
                description,
                totalMiles
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