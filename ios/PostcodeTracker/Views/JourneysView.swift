import SwiftUI
import CoreLocation

struct JourneysView: View {
    @StateObject private var journeyManager = JourneyManager.shared
    @State private var selectedJourneys = Set<Int>()
    @State private var isSelectionMode = false
    @State private var showingBulkDeleteAlert = false
    @State private var showingDeleteAllAlert = false
    @State private var showingExportSheet = false
    @State private var exportFileURL: URL?
    @State private var isExportingCSV = false
    @State private var isExportingExcel = false
    
    var body: some View {
        NavigationView {
            VStack {
                if journeyManager.isLoading && journeyManager.journeys.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading journeys...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if journeyManager.journeys.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "clock")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Journeys Yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Start tracking your journeys or create manual ones")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    // Journey list
                    List {
                        ForEach(journeyManager.journeys, id: \.id) { journey in
                            JourneyRow(
                                journey: journey,
                                isSelected: selectedJourneys.contains(journey.id),
                                isSelectionMode: isSelectionMode,
                                onTap: {
                                    if isSelectionMode {
                                        toggleSelection(journey)
                                    }
                                }
                            )
                        }
                        .onDelete(perform: deleteJourneys)
                    }
                    .refreshable {
                        await journeyManager.refreshJourneys()
                    }
                }
            }
            .navigationTitle("Journey History")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu("Export") {
                            // Export All section
                            Section("Export All") {
                                Button(action: {
                                    print("🔘 User tapped CSV Export button")
                                    exportJourneysCSV(journeyManager.journeys)
                                }) {
                                    HStack {
                                        Text("CSV Format")
                                        if isExportingCSV {
                                            Spacer()
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        }
                                    }
                                }
                                .disabled(isExportingCSV || isExportingExcel)
                                
                                Button(action: {
                                    print("🔘 User tapped Excel Export button")
                                    exportJourneysExcel(journeyManager.journeys)
                                }) {
                                    HStack {
                                        Text("Excel Format")
                                        if isExportingExcel {
                                            Spacer()
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        }
                                    }
                                }
                                .disabled(isExportingCSV || isExportingExcel)
                            }
                            
                            // Export Selected section (only show when in selection mode)
                            if isSelectionMode && !selectedJourneys.isEmpty {
                                Section("Export Selected (\(selectedJourneys.count))") {
                                    Button(action: {
                                        let selectedJourneyObjects = journeyManager.journeys.filter { selectedJourneys.contains($0.id) }
                                        exportJourneysCSV(selectedJourneyObjects)
                                    }) {
                                        HStack {
                                            Text("CSV Format")
                                            if isExportingCSV {
                                                Spacer()
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                            }
                                        }
                                    }
                                    .disabled(isExportingCSV || isExportingExcel)
                                    
                                    Button(action: {
                                        let selectedJourneyObjects = journeyManager.journeys.filter { selectedJourneys.contains($0.id) }
                                        exportJourneysExcel(selectedJourneyObjects)
                                    }) {
                                        HStack {
                                            Text("Excel Format")
                                            if isExportingExcel {
                                                Spacer()
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                            }
                                        }
                                    }
                                    .disabled(isExportingCSV || isExportingExcel)
                                }
                            }
                        }
                        
                        Button(isSelectionMode ? "Done" : "Select") {
                            isSelectionMode.toggle()
                            if !isSelectionMode {
                                selectedJourneys.removeAll()
                            }
                        }
                }
                
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if isSelectionMode {
                        Menu("Delete") {
                            if !selectedJourneys.isEmpty {
                                Button("Delete Selected (\(selectedJourneys.count))", role: .destructive) {
                                    showingBulkDeleteAlert = true
                                }
                            }
                            
                            Button("Delete All", role: .destructive) {
                                showingDeleteAllAlert = true
                            }
                        }
                    }
                }
            }
            .alert("Delete Journeys", isPresented: $showingBulkDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteBulkJourneys()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete \(selectedJourneys.count) journey(s)?")
            }
            .alert("Delete All Journeys", isPresented: $showingDeleteAllAlert) {
                Button("Delete All", role: .destructive) {
                    deleteAllJourneys()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete all \(journeyManager.journeys.count) journeys? This cannot be undone.")
            }
            .sheet(isPresented: $showingExportSheet, onDismiss: {
                // Clean up when sheet is dismissed
                exportFileURL = nil
                isExportingCSV = false
                isExportingExcel = false
                print("📄 Export: Sheet dismissed, cleaned up file URL")
            }) {
                if let fileURL = exportFileURL {
                    ActivityViewController(activityItems: [fileURL])
                } else {
                    // Fallback content to prevent white screen
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Preparing export...")
                            .font(.subheadline)
                        
                        if isExportingCSV {
                            Text("Generating CSV file...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if isExportingExcel {
                            Text("Generating Excel file...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .onAppear {
                        // If we somehow get here without a file URL and not exporting, dismiss the sheet
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if !isExportingCSV && !isExportingExcel {
                                showingExportSheet = false
                            }
                        }
                    }
                }
            }
            .alert("Error", isPresented: .constant(journeyManager.errorMessage != nil)) {
                Button("OK") {
                    journeyManager.clearError()
                }
            } message: {
                Text(journeyManager.errorMessage ?? "")
            }
        }
        .onAppear {
            Task {
                await journeyManager.loadJourneys()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleSelection(_ journey: Journey) {
        if selectedJourneys.contains(journey.id) {
            selectedJourneys.remove(journey.id)
        } else {
            selectedJourneys.insert(journey.id)
        }
    }
    
    private func deleteJourneys(offsets: IndexSet) {
        let journeysToDelete = offsets.map { journeyManager.journeys[$0] }
        Task {
            await journeyManager.deleteJourneys(journeysToDelete)
        }
    }
    
    private func deleteBulkJourneys() {
        let journeysToDelete = journeyManager.journeys.filter { selectedJourneys.contains($0.id) }
        Task {
            await journeyManager.deleteJourneys(journeysToDelete)
        }
        selectedJourneys.removeAll()
        isSelectionMode = false
    }
    
    private func deleteAllJourneys() {
        Task {
            await journeyManager.deleteJourneys(journeyManager.journeys)
        }
        selectedJourneys.removeAll()
        isSelectionMode = false
    }
    
    private func exportJourneysCSV(_ journeys: [Journey]) {
        print("📄 Export: Starting CSV export for \(journeys.count) journeys")
        print("📄 Export: User is authenticated: \(AuthManager.shared.isAuthenticated)")
        isExportingCSV = true
        
        // Clear any previous export file URL first
        exportFileURL = nil
        
        Task {
            do {
                let csvData = try await journeyManager.exportJourneysCSV()
                
                // Save to temporary file
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("journeys_export_\(DateFormatter.filenameDateFormatter.string(from: Date())).csv")
                
                try csvData.write(to: tempURL)
                
                await MainActor.run {
                    print("📄 Export: CSV file created at: \(tempURL)")
                    exportFileURL = tempURL
                    showingExportSheet = true
                    isExportingCSV = false
                }
            } catch {
                await MainActor.run {
                    print("📄 Export: Failed to create CSV file: \(error)")
                    // Could show error alert here
                    isExportingCSV = false
                }
            }
        }
    }
    
    private func exportJourneysExcel(_ journeys: [Journey]) {
        print("📄 Export: Starting Excel export for \(journeys.count) journeys")
        print("📄 Export: User is authenticated: \(AuthManager.shared.isAuthenticated)")
        isExportingExcel = true
        
        // Clear any previous export file URL first
        exportFileURL = nil
        
        Task {
            do {
                let excelData = try await journeyManager.exportJourneysExcel()
                
                // Save to temporary file
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("journeys_export_\(DateFormatter.filenameDateFormatter.string(from: Date())).xlsx")
                
                try excelData.write(to: tempURL)
                
                await MainActor.run {
                    print("📄 Export: Excel file created at: \(tempURL)")
                    exportFileURL = tempURL
                    showingExportSheet = true
                    isExportingExcel = false
                }
            } catch {
                await MainActor.run {
                    print("📄 Export: Failed to create Excel file: \(error)")
                    // Could show error alert here
                    isExportingExcel = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct JourneyRow: View {
    let journey: Journey
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .onTapGesture {
                        onTap()
                    }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Journey client info (if exists)
                if let clientName = journey.clientName, !clientName.isEmpty {
                    HStack {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text(clientName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        if let rechargeToClient = journey.rechargeToClient {
                            Spacer()
                            Text(rechargeToClient ? "Rechargeable" : "Non-rechargeable")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(rechargeToClient ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                                .foregroundColor(rechargeToClient ? .green : .gray)
                                .cornerRadius(4)
                        }
                    }
                }
                
                // Description (if exists)
                if let description = journey.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Postcodes
                HStack {
                    Text(journey.startPostcode)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(journey.endPostcode ?? "In Progress")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(journey.endPostcode == nil ? .orange : .primary)
                }
                
                // Details row
                HStack {
                    if let distance = journey.distanceMiles {
                        Label("\(String(format: "%.1f", distance)) miles", 
                              systemImage: "road.lanes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if journey.isActive {
                        Label("Active", systemImage: "dot.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    if let startTime = journey.formattedStartTime {
                        Text(startTime.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // GPS indicator for manual vs tracked journeys
                if journey.startLatitude == nil && journey.startLongitude == nil {
                    HStack {
                        Image(systemName: "hand.point.up.left")
                            .font(.caption2)
                        Text("Manual Journey")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onTap()
            }
        }
    }
}

// MARK: - Activity View Controller for Sharing

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    JourneysView()
} 