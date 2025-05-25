import SwiftUI
import UniformTypeIdentifiers

struct JourneysView: View {
    @State private var journeys: [Journey] = []
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedJourneys: Set<Int> = []
    @State private var isEditing = false
    @State private var showingManualJourneySheet = false
    @State private var postcodes: [Postcode] = []
    @State private var showingExportSheet = false
    @State private var exportFormat: ExportFormat = .csv
    @State private var exportData: Data?
    @State private var exportFileName: String = ""
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    
    enum ExportFormat {
        case csv
        case excel
        
        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .excel: return "xlsx"
            }
        }
        
        var mimeType: String {
            switch self {
            case .csv: return "text/csv"
            case .excel: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            }
        }
    }
    
    var groupedJourneys: [(String, [Journey])] {
        let grouped = Dictionary(grouping: journeys) { journey in
            let date = ISO8601DateFormatter().date(from: journey.start_time) ?? Date()
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return grouped.sorted { $0.0 > $1.0 }
    }
    
    var body: some View {
        NavigationView {
            JourneysList(
                groupedJourneys: groupedJourneys,
                selectedJourneys: $selectedJourneys,
                isEditing: $isEditing,
                isLoading: isLoading,
                showingAlert: $showingAlert,
                alertMessage: $alertMessage,
                showingManualJourneySheet: $showingManualJourneySheet,
                showingExportSheet: $showingExportSheet,
                exportFormat: $exportFormat,
                postcodes: postcodes,
                onJourneyCreated: { newJourney in
                    journeys.insert(newJourney, at: 0)
                },
                onExport: exportJourneys,
                onDelete: deleteSelectedJourneys
            )
        }
        .onAppear {
            loadJourneys()
            loadPostcodes()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    private func exportJourneys() {
        guard !selectedJourneys.isEmpty else {
            alertMessage = "Please select at least one journey to export"
            showingAlert = true
            return
        }
        
        isLoading = true
        print("Starting export process for \(selectedJourneys.count) journeys")
        
        let journeyIds = Array(selectedJourneys)
        let format = exportFormat == .csv ? "csv" : "excel"
        
        Task {
            do {
                print("Making API call to export journeys...")
                let (data, response) = try await APIService.shared.exportJourneys(journeyIds: journeyIds, format: format)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Received response with status code: \(httpResponse.statusCode)")
                    print("Response headers: \(httpResponse.allHeaderFields)")
                    
                    if httpResponse.statusCode == 200 {
                        // Get filename from Content-Disposition header
                        if let contentDisposition = httpResponse.allHeaderFields["Content-Disposition"] as? String,
                           let filename = contentDisposition.split(separator: "filename=").last?.replacingOccurrences(of: "\"", with: "") {
                            print("Found filename in Content-Disposition: \(filename)")
                            exportFileName = filename
                        } else {
                            // Generate default filename
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                            exportFileName = "journey_history_\(dateFormatter.string(from: Date())).\(exportFormat.fileExtension)"
                            print("Generated default filename: \(exportFileName)")
                        }
                        
                        exportData = data
                        showingExportSheet = false
                        
                        // Share the file
                        if let data = exportData {
                            print("Preparing to share file...")
                            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(exportFileName)
                            try data.write(to: tempURL)
                            print("File written to temporary location: \(tempURL.path)")
                            
                            await MainActor.run {
                                shareURL = tempURL
                                showingShareSheet = true
                            }
                        } else {
                            print("No data available to share")
                            alertMessage = "No data available to export"
                            showingAlert = true
                        }
                    } else {
                        print("Export failed with status code: \(httpResponse.statusCode)")
                        alertMessage = "Failed to export journeys"
                        showingAlert = true
                    }
                }
            } catch {
                print("Export error: \(error.localizedDescription)")
                alertMessage = "Error: \(error.localizedDescription)"
                showingAlert = true
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func loadJourneys() {
        isLoading = true
        
        Task {
            do {
                let fetchedJourneys = try await APIService.shared.getJourneys()
                print("Fetched journeys from server:")
                for journey in fetchedJourneys {
                    print("Journey ID: \(journey.id), Start: \(journey.start_postcode), End: \(journey.end_postcode)")
                }
                
                await MainActor.run {
                    self.journeys = fetchedJourneys
                    self.isLoading = false
                }
            } catch {
                print("Error loading journeys: \(error)")
                await MainActor.run {
                    self.alertMessage = "Failed to load journeys: \(error.localizedDescription)"
                    self.showingAlert = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadPostcodes() {
        Task {
            do {
                let fetchedPostcodes = try await APIService.shared.getPostcodes()
                await MainActor.run {
                    self.postcodes = fetchedPostcodes
                }
            } catch {
                print("Failed to load postcodes: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteSelectedJourneys() {
        isLoading = true
        
        Task {
            do {
                // Create a copy of selected journeys to track progress
                let journeysToDelete = Array(selectedJourneys)
                
                print("Starting deletion of \(journeysToDelete.count) journeys")
                print("Selected journey IDs: \(journeysToDelete)")
                
                // Print current journeys for debugging
                print("Current journeys in list:")
                for journey in journeys {
                    print("Journey ID: \(journey.id), Start: \(journey.start_postcode), End: \(journey.end_postcode)")
                }
                
                // Delete all selected journeys in one request
                do {
                    print("Attempting to delete journeys: \(journeysToDelete)")
                    try await APIService.shared.deleteJourney(ids: journeysToDelete)
                    print("Successfully deleted journeys")
                    
                    await MainActor.run {
                        // Remove all selected journeys from the list
                        journeys.removeAll { journey in
                            journeysToDelete.contains(journey.id)
                        }
                        
                        // Clear selection
                        selectedJourneys.removeAll()
                        isEditing = false
                        isLoading = false
                        
                        // Show success message
                        alertMessage = "Successfully deleted \(journeysToDelete.count) journey(s)"
                        showingAlert = true
                        
                        // Refresh the journey list
                        loadJourneys()
                    }
                } catch APIError.unauthorized {
                    print("Authentication error while deleting journeys")
                    await MainActor.run {
                        alertMessage = "Your session has expired. Please log in again."
                        showingAlert = true
                        isLoading = false
                    }
                } catch let error as APIError {
                    print("API Error while deleting journeys: \(error.localizedDescription)")
                    await MainActor.run {
                        alertMessage = "Failed to delete journeys: \(error.localizedDescription)"
                        showingAlert = true
                        isLoading = false
                    }
                } catch {
                    print("Unexpected error while deleting journeys: \(error.localizedDescription)")
                    await MainActor.run {
                        alertMessage = "An unexpected error occurred: \(error.localizedDescription)"
                        showingAlert = true
                        isLoading = false
                    }
                }
            } catch {
                print("Unexpected error during deletion process: \(error)")
                await MainActor.run {
                    alertMessage = "An unexpected error occurred: \(error.localizedDescription)"
                    showingAlert = true
                    isLoading = false
                }
            }
        }
    }
}

struct JourneysList: View {
    let groupedJourneys: [(String, [Journey])]
    @Binding var selectedJourneys: Set<Int>
    @Binding var isEditing: Bool
    let isLoading: Bool
    @Binding var showingAlert: Bool
    @Binding var alertMessage: String
    @Binding var showingManualJourneySheet: Bool
    @Binding var showingExportSheet: Bool
    @Binding var exportFormat: JourneysView.ExportFormat
    let postcodes: [Postcode]
    let onJourneyCreated: (Journey) -> Void
    let onExport: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        JourneysListContent(
            groupedJourneys: groupedJourneys,
            selectedJourneys: $selectedJourneys,
            isEditing: isEditing
        )
        .navigationTitle("Journeys")
        .toolbar {
            JourneysToolbar(
                isEditing: $isEditing,
                selectedJourneys: $selectedJourneys,
                showingManualJourneySheet: $showingManualJourneySheet
            )
        }
        .overlay(Group {
            if isLoading {
                ProgressView()
            }
        })
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showingManualJourneySheet) {
            ManualJourneyView(postcodes: postcodes) { newJourney in
                onJourneyCreated(newJourney)
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportFormatView(
                exportFormat: $exportFormat,
                onCancel: { showingExportSheet = false },
                onExport: onExport
            )
        }
        .overlay(Group {
            if isEditing && !selectedJourneys.isEmpty {
                JourneysActionBar(
                    showingExportSheet: $showingExportSheet,
                    onDelete: onDelete
                )
            }
        })
    }
}

struct JourneysListContent: View {
    let groupedJourneys: [(String, [Journey])]
    @Binding var selectedJourneys: Set<Int>
    let isEditing: Bool
    
    var body: some View {
        List {
            ForEach(groupedJourneys, id: \.0) { date, journeys in
                JourneysSection(
                    date: date,
                    journeys: journeys,
                    selectedJourneys: $selectedJourneys,
                    isEditing: isEditing
                )
            }
        }
    }
}

struct JourneysSection: View {
    let date: String
    let journeys: [Journey]
    @Binding var selectedJourneys: Set<Int>
    let isEditing: Bool
    
    var body: some View {
        Section(header: Text(date)) {
            ForEach(journeys) { journey in
                JourneyRow(journey: journey, isSelected: selectedJourneys.contains(journey.id), isEditing: isEditing) {
                    if isEditing {
                        if selectedJourneys.contains(journey.id) {
                            selectedJourneys.remove(journey.id)
                        } else {
                            selectedJourneys.insert(journey.id)
                        }
                    }
                }
            }
        }
    }
}

struct JourneysToolbar: ToolbarContent {
    @Binding var isEditing: Bool
    @Binding var selectedJourneys: Set<Int>
    @Binding var showingManualJourneySheet: Bool
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if isEditing {
                Button("Done") {
                    isEditing = false
                    selectedJourneys.removeAll()
                }
            } else {
                Button("Select") {
                    isEditing = true
                }
            }
        }
        
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: {
                showingManualJourneySheet = true
            }) {
                Image(systemName: "plus")
            }
        }
    }
}

struct JourneysActionBar: View {
    @Binding var showingExportSheet: Bool
    let onDelete: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Button(action: {
                    showingExportSheet = true
                }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .shadow(radius: 5)
        }
    }
}

struct ExportFormatView: View {
    @Binding var exportFormat: JourneysView.ExportFormat
    let onCancel: () -> Void
    let onExport: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: { exportFormat = .csv }) {
                        HStack {
                            Text("CSV Format")
                            Spacer()
                            if exportFormat == .csv {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Button(action: { exportFormat = .excel }) {
                        HStack {
                            Text("Excel Format")
                            Spacer()
                            if exportFormat == .excel {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Export Format")
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel),
                trailing: Button("Export", action: onExport)
            )
        }
    }
}

struct JourneyRow: View {
    let journey: Journey
    let isSelected: Bool
    let isEditing: Bool
    let onSelected: () -> Void
    
    var body: some View {
        HStack {
            if isEditing {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 20))
                    .padding(.trailing, 8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("From: \(journey.start_postcode)")
                            .font(.subheadline)
                        Text("To: \(journey.end_postcode)")
                            .font(.subheadline)
                    }
                    Spacer()
                    Text(String(format: "%.1f mi", journey.distance_miles))
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text(formatTime(journey.start_time))
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("→")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(formatTime(journey.end_time))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelected()
        }
        .background(
            isSelected ? Color.blue.opacity(0.1) : Color.clear
        )
    }
    
    private func formatTime(_ isoString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoString) else {
            return isoString
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ManualJourneyView: View {
    let postcodes: [Postcode]
    let onJourneyCreated: (Journey) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStartPostcode: Postcode?
    @State private var selectedEndPostcode: Postcode?
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Start Postcode")) {
                    Picker("Select Start Postcode", selection: $selectedStartPostcode) {
                        Text("Select a postcode").tag(nil as Postcode?)
                        ForEach(postcodes) { postcode in
                            Text("\(postcode.name) (\(postcode.postcode))")
                                .tag(postcode as Postcode?)
                        }
                    }
                }
                
                Section(header: Text("End Postcode")) {
                    Picker("Select End Postcode", selection: $selectedEndPostcode) {
                        Text("Select a postcode").tag(nil as Postcode?)
                        ForEach(postcodes) { postcode in
                            Text("\(postcode.name) (\(postcode.postcode))")
                                .tag(postcode as Postcode?)
                        }
                    }
                }
            }
            .navigationTitle("Create Journey")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Create") {
                    createJourney()
                }
                .disabled(selectedStartPostcode == nil || selectedEndPostcode == nil || isLoading)
            )
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func createJourney() {
        guard let start = selectedStartPostcode, let end = selectedEndPostcode else { return }
        
        isLoading = true
        
        Task {
            do {
                let journey = try await APIService.shared.createManualJourney(
                    startPostcode: start.postcode,
                    endPostcode: end.postcode
                )
                await MainActor.run {
                    onJourneyCreated(journey)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to create journey: \(error.localizedDescription)"
                    showingAlert = true
                    isLoading = false
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    JourneysView()
} 