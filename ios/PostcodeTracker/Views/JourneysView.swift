import SwiftUI
import UniformTypeIdentifiers

struct JourneysView: View {
    @State private var journeys: [Journey] = []
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage: String? = nil
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
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
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
            .navigationTitle("Journeys")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing {
                        Button("Done") {
                            isEditing = false
                            selectedJourneys.removeAll()
                        }
                        .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !selectedJourneys.isEmpty {
                            Button(action: {
                                showingExportSheet = true
                            }) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        Button(action: {
                            withAnimation {
                                isEditing.toggle()
                                selectedJourneys.removeAll()
                            }
                        }) {
                            Text(isEditing ? "Cancel" : "Select")
                        }
                        .foregroundColor(.primary)
                        Button(action: {
                             showingManualJourneySheet = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .alert("Journey", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "")
                    .playfairDisplay(.body)
                    .foregroundColor(.primary)
            }
            .sheet(isPresented: $showingManualJourneySheet) {
                 AddManualJourneyView(onJourneyCreated: { newJourney in
                     journeys.insert(newJourney, at: 0)
                 })
             }
             .sheet(isPresented: $showingExportSheet) {
                 ExportOptionsView(
                     exportFormat: $exportFormat,
                     onExport: exportJourneys
                 )
             }
             .sheet(isPresented: $showingShareSheet) {
                if let url = shareURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            loadJourneys()
            loadPostcodes()
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
    @Binding var alertMessage: String?
    @Binding var showingManualJourneySheet: Bool
    @Binding var showingExportSheet: Bool
    @Binding var exportFormat: JourneysView.ExportFormat
    let postcodes: [Postcode]
    let onJourneyCreated: (Journey) -> Void
    let onExport: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.primary)
            } else if groupedJourneys.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "map")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No Journeys Recorded")
                        .playfairDisplay(.title2)
                        .foregroundColor(.primary)
                    Text("Start tracking or add a manual journey to see them here.")
                        .playfairDisplay(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(groupedJourneys, id: \.0) { date, journeys in
                        Section(header: Text(date).playfairDisplay(.headline).foregroundColor(.primary)) {
                            ForEach(journeys) { journey in
                                JourneyRow(
                                    journey: journey,
                                    isSelected: selectedJourneys.contains(journey.id),
                                    isEditing: isEditing,
                                    onSelect: {
                                        if selectedJourneys.contains(journey.id) {
                                            selectedJourneys.remove(journey.id)
                                        } else {
                                            selectedJourneys.insert(journey.id)
                                        }
                                    }
                                )
                                .listRowBackground(Color(.systemBackground))
                                .listRowSeparator(.hidden)
                                .padding(.vertical, 4)
                            }
                            .onDelete(perform: deleteItems)
                        }
                    }
                    // Add padding to the bottom of the list
                    Color.clear.frame(height: 50)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .background(Color(.systemBackground))
                .scrollContentBackground(.hidden)
            }
        }
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button("Delete Selected") {
                            onDelete()
                        }
                        .disabled(selectedJourneys.isEmpty)
                        .foregroundColor(selectedJourneys.isEmpty ? .gray : .red)
                        
                        Spacer()
                        
                        Button("Export Selected") {
                            onExport()
                        }
                        .disabled(selectedJourneys.isEmpty)
                        .foregroundColor(selectedJourneys.isEmpty ? .gray : .primary)
                    }
                }
            }
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
         // Convert index set to journey IDs
        let journeysToDelete = offsets.map { groupedJourneys.flatMap { $0.1 }[$0].id }
        
        // Add to selected journeys set and then call the main delete function
        for id in journeysToDelete {
            selectedJourneys.insert(id)
        }
        onDelete()
    }
}

struct JourneyRow: View {
    let journey: Journey
    let isSelected: Bool
    let isEditing: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            if isEditing {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(.primary)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("\(journey.start_postcode) to \(journey.end_postcode)")
                    .playfairDisplay(.headline)
                    .foregroundColor(.primary)
                
                let startTime = ISO8601DateFormatter().date(from: journey.start_time) ?? Date()
                Text("Start: \(startTime, formatter: itemFormatter)")
                    .playfairDisplay(.subheadline)
                    .foregroundColor(.secondary)

                let endTimeDate = ISO8601DateFormatter().date(from: journey.end_time) ?? Date()
                Text("End: \(endTimeDate, formatter: itemFormatter)")
                    .playfairDisplay(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(String(format: "Distance: %.2f km", journey.distance_miles))
                    .playfairDisplay(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !isEditing && journey.distance_miles == 0 {
                Text("Ongoing...")
                    .playfairDisplay(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

struct AddManualJourneyView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var startPostcode = ""
    @State private var endPostcode = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    let onJourneyCreated: (Journey) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                Form {
                     Section {
                         TextField("Start Postcode", text: $startPostcode)
                             .postcodeInput($startPostcode)
                             .playfairDisplay(.body)
                             .foregroundColor(.primary)
                         TextField("End Postcode", text: $endPostcode)
                             .postcodeInput($endPostcode)
                             .playfairDisplay(.body)
                             .foregroundColor(.primary)
                     } header: {
                         Text("Manual Journey Details")
                             .playfairDisplay(.headline)
                             .foregroundColor(.primary)
                     } footer: {
                         Text("Enter the start and end postcodes for a journey.")
                             .playfairDisplay(.subheadline)
                             .foregroundColor(.secondary)
                     }
                    
                     if isLoading {
                         ProgressView()
                             .scaleEffect(1.0)
                             .frame(maxWidth: .infinity, alignment: .center)
                             .foregroundColor(.primary)
                     }
                }
                .scrollContentBackground(.hidden)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Add Manual Journey")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.primary),
                trailing: Button("Add") {
                     createManualJourney()
                }
                .disabled(startPostcode.isEmpty || endPostcode.isEmpty || isLoading)
                .foregroundColor(startPostcode.isEmpty || endPostcode.isEmpty || isLoading ? .gray : .primary)
            )
            .alert("Manual Journey", isPresented: $showingAlert) {
                 Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
                    .playfairDisplay(.body)
                    .foregroundColor(.primary)
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func createManualJourney() {
        isLoading = true
        
        Task {
            do {
                let journey = try await APIService.shared.createManualJourney(
                    startPostcode: startPostcode,
                    endPostcode: endPostcode
                )
                
                await MainActor.run {
                    onJourneyCreated(journey)
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Error creating manual journey: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct ExportOptionsView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var exportFormat: JourneysView.ExportFormat
    let onExport: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                Form {
                    Section(header: Text("Export Format").playfairDisplay(.headline).foregroundColor(.primary)) {
                        Picker("Format", selection: $exportFormat) {
                            Text("CSV").tag(JourneysView.ExportFormat.csv).playfairDisplay(.body)
                            Text("Excel").tag(JourneysView.ExportFormat.excel).playfairDisplay(.body)
                        }
                        .pickerStyle(.inline)
                        .foregroundColor(.primary)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.primary),
                trailing: Button("Export") {
                    onExport()
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.primary)
            )
        }
        .navigationViewStyle(.stack)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        
    }
}

#Preview {
    JourneysView()
} 