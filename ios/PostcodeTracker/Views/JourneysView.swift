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
                    if !journeyManager.journeys.isEmpty {
                        Menu("Export") {
                            Button("Export All") {
                                exportJourneys(journeyManager.journeys)
                            }
                            
                            if isSelectionMode && !selectedJourneys.isEmpty {
                                Button("Export Selected") {
                                    let selectedJourneyObjects = journeyManager.journeys.filter { selectedJourneys.contains($0.id) }
                                    exportJourneys(selectedJourneyObjects)
                                }
                            }
                        }
                        .disabled(journeyManager.journeys.isEmpty)
                        
                        Button(isSelectionMode ? "Done" : "Select") {
                            isSelectionMode.toggle()
                            if !isSelectionMode {
                                selectedJourneys.removeAll()
                            }
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
            .sheet(isPresented: $showingExportSheet) {
                if let fileURL = exportFileURL {
                    ActivityViewController(activityItems: [fileURL])
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
    
    private func exportJourneys(_ journeys: [Journey]) {
        if let fileURL = CSVExporter.exportJourneys(journeys) {
            exportFileURL = fileURL
            showingExportSheet = true
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
                // Journey label (if exists)
                if let label = journey.label, !label.isEmpty {
                    HStack {
                        Image(systemName: "tag.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text(label)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
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