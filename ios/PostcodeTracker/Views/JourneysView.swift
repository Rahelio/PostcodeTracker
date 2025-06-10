import SwiftUI
import UniformTypeIdentifiers

struct JourneysView: View {
    @StateObject private var journeyManager = JourneyManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
<<<<<<< HEAD
                if journeyManager.isLoading {
                    ProgressView("Loading journeys...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if journeyManager.journeys.isEmpty {
                    EmptyJourneysView()
                } else {
=======
                JourneysList(
                    groupedJourneys: groupedJourneys,
                    selectedJourneys: $selectedJourneys,
                    isEditing: $isEditing,
                    isLoading: isLoading,
                    showingAlert: $showingAlert,
                    alertMessage: $alertMessage,
                    showingManualJourneySheet: $showingManualJourneySheet,
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
                        HStack {
                            Button("Done") {
                                isEditing = false
                                selectedJourneys.removeAll()
                            }
                            .foregroundColor(.primary)
                            
                            Button("Select All") {
                                selectedJourneys = Set(journeys.map { $0.id })
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !selectedJourneys.isEmpty {
                            Button(action: {
                                exportJourneys()
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
        
        Task {
            do {
                print("Making API call to export journeys...")
                let (data, response) = try await APIService.shared.exportJourneys(journeyIds: journeyIds, format: "csv")
                
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
                            exportFileName = "journey_history_\(dateFormatter.string(from: Date())).csv"
                            print("Generated default filename: \(exportFileName)")
                        }
                        
                        exportData = data
                        
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
        guard !selectedJourneys.isEmpty else { return }
        
        isLoading = true
        
        Task {
            do {
                // Convert selected journeys set to array
                let journeysToDelete = Array(selectedJourneys)
                
                // Print current journeys for debugging
                print("Current journeys in list:")
                for journey in journeys {
                    print("Journey ID: \(journey.id), Start: \(journey.start_postcode), End: \(journey.end_postcode)")
                }
                
                // Delete each journey individually
                for journeyId in journeysToDelete {
                    do {
                        print("Attempting to delete journey: \(journeyId)")
                        try await APIService.shared.deleteJourney(journeyId: journeyId)
                        print("Successfully deleted journey \(journeyId)")
                    } catch {
                        print("Error deleting journey \(journeyId): \(error.localizedDescription)")
                        throw error
                    }
                }
                
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
                ZStack(alignment: .bottom) {
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
                    List {
                        ForEach(journeyManager.journeys) { journey in
                            JourneyRowView(journey: journey)
                                .listRowBackground(Color(.systemBackground))
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await journeyManager.refreshJourneys()
                    }
                }
            }
            .navigationTitle("Journey History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await journeyManager.loadJourneys()
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await journeyManager.loadJourneys()
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") {
                    journeyManager.clearError()
                }
            } message: {
                Text(alertMessage)
            }
            .onChange(of: journeyManager.errorMessage) { error in
                if let error = error {
                    alertMessage = error
                    showingAlert = true
                }
            }
        }
    }
<<<<<<< HEAD
=======
    
    private func deleteItems(at offsets: IndexSet) {
        // Convert index set to journey IDs and add them to selected journeys
        let journeysToDelete = offsets.map { groupedJourneys.flatMap { $0.1 }[$0].id }
        
        // Add to selected journeys set
        for id in journeysToDelete {
            selectedJourneys.insert(id)
        }
        
        // Call the parent's delete function
        onDelete()
    }
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
}

struct JourneyRowView: View {
    let journey: Journey
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with date and status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let startTime = journey.formattedStartTime {
                        Text(formatDate(startTime))
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(formatTime(startTime))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if journey.isActive {
                    Text("Active")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
            }
            
<<<<<<< HEAD
            // Route information
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    RoutePoint(
                        icon: "circle.fill",
                        color: .green,
                        title: "From",
                        location: journey.startPostcode
                    )
                    
                    if let endPostcode = journey.endPostcode {
                        RoutePoint(
                            icon: "circle.fill",
                            color: .red,
                            title: "To",
                            location: endPostcode
                        )
                    }
                }
                
                Spacer()
                
                // Journey stats
                VStack(alignment: .trailing, spacing: 8) {
                    if let distance = journey.distanceMiles {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.2f", distance))
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("miles")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !journey.isActive {
                        Text(journey.duration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
=======
            VStack(alignment: .leading, spacing: 8) {
                Text("\(journey.start_postcode) to \(journey.end_postcode ?? "In Progress")")
                    .playfairDisplay(.headline)
                    .foregroundColor(.primary)
                
                let startTime = ISO8601DateFormatter().date(from: journey.start_time) ?? Date()
                Text("Start: \(startTime, formatter: itemFormatter)")
                    .playfairDisplay(.subheadline)
                    .foregroundColor(.secondary)

                if let endTimeString = journey.end_time {
                    let endTimeDate = ISO8601DateFormatter().date(from: endTimeString) ?? Date()
                    Text("End: \(endTimeDate, formatter: itemFormatter)")
                        .playfairDisplay(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("End: In Progress")
                        .playfairDisplay(.subheadline)
                        .foregroundColor(.orange)
                }
                
                Text(String(format: "Distance: %.2f km", journey.distance_miles ?? 0.0))
                    .playfairDisplay(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !isEditing && journey.end_time == nil {
                Text("Ongoing...")
                    .playfairDisplay(.caption)
                    .foregroundColor(.orange)
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct RoutePoint: View {
    let icon: String
    let color: Color
    let title: String
    let location: String
    
    var body: some View {
<<<<<<< HEAD
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(location)
                    .font(.subheadline)
                    .fontWeight(.medium)
=======
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                Form {
                    Section {
                        Picker("Start Location", selection: $selectedStartPostcode) {
                            Text("Select Start Location").tag(nil as Postcode?)
                            ForEach(postcodes) { postcode in
                                Text("\(postcode.name) (\(postcode.postcode))")
                                    .tag(postcode as Postcode?)
                            }
                        }
                        .playfairDisplay(.body)
                        
                        Picker("End Location", selection: $selectedEndPostcode) {
                            Text("Select End Location").tag(nil as Postcode?)
                            ForEach(postcodes) { postcode in
                                Text("\(postcode.name) (\(postcode.postcode))")
                                    .tag(postcode as Postcode?)
                            }
                        }
                        .playfairDisplay(.body)
                    } header: {
                        Text("Journey Details")
                            .playfairDisplay(.headline)
                            .foregroundColor(.primary)
                    } footer: {
                        Text("Select start and end locations from your saved postcodes.")
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
                .disabled(selectedStartPostcode == nil || selectedEndPostcode == nil || isLoading)
                .foregroundColor(selectedStartPostcode == nil || selectedEndPostcode == nil || isLoading ? .gray : .primary)
            )
            .alert("Manual Journey", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
                    .playfairDisplay(.body)
                    .foregroundColor(.primary)
            }
            .task {
                await loadPostcodes()
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func loadPostcodes() async {
        do {
            postcodes = try await APIService.shared.getPostcodes()
        } catch {
            alertMessage = "Failed to load postcodes: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func createManualJourney() {
        guard let startPostcode = selectedStartPostcode,
              let endPostcode = selectedEndPostcode else {
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // First, start the journey
                let journeyId = try await APIService.shared.startJourney(
                    startPostcode: startPostcode.postcode,
                    isManual: true
                )
                
                // Then end it with the end postcode
                let journey = try await APIService.shared.endJourney(
                    journeyId: journeyId,
                    endPostcode: endPostcode.postcode,
                    distanceMiles: 0.0  // The server will calculate the distance
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
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
            }
        }
    }
}

struct EmptyJourneysView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Journeys Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start tracking your journeys to see them here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    JourneysView()
} 