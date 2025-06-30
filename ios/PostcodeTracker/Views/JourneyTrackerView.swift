import SwiftUI
import CoreLocation

// Postcode cache
class PostcodeCache {
    static let shared = PostcodeCache()
    private var cache: [String: Postcode] = [:]
    private let cacheTimeout: TimeInterval = 3600 // 1 hour
    
    private init() {}
    
    func getPostcode(for coordinates: CLLocationCoordinate2D) -> Postcode? {
        let key = "\(coordinates.latitude),\(coordinates.longitude)"
        return cache[key]
    }
    
    func setPostcode(_ postcode: Postcode, for coordinates: CLLocationCoordinate2D) {
        let key = "\(coordinates.latitude),\(coordinates.longitude)"
        cache[key] = postcode
    }
    
    func clearCache() {
        cache.removeAll()
    }
}

// Journey state persistence
struct JourneyState: Codable {
    let isRecording: Bool
    let startPostcode: Postcode?
    let endPostcode: Postcode?
    let distance: Double?
    let startTime: Date
    let journeyId: Int? // Add journey ID to state
    
    static func save(_ state: JourneyState) {
        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: "activeJourney")
        }
    }
    
    static func load() -> JourneyState? {
        guard let data = UserDefaults.standard.data(forKey: "activeJourney"),
              let state = try? JSONDecoder().decode(JourneyState.self, from: data) else {
            return nil
        }
        return state
    }
    
    static func clear() {
        UserDefaults.standard.removeObject(forKey: "activeJourney")
    }
}

struct JourneyTrackerView: View {
    @StateObject private var journeyManager = JourneyManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // New journey input fields
    @State private var clientName = ""
    @State private var rechargeToClient = false
    @State private var description = ""
    
    // Animation state
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Top spacer
                        Spacer()
                            .frame(height: 40)
                        
                        // Status Icon
                        ZStack {
                            Circle()
                                .fill(journeyManager.hasActiveJourney ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                                .frame(width: 120, height: 120)
                            
                            if journeyManager.isLoading {
                                // Loading animation overlay
                                Circle()
                                    .stroke(journeyManager.hasActiveJourney ? Color.red.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 3)
                                    .frame(width: 120, height: 120)
                                    .rotationEffect(.degrees(rotationAngle))
                                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotationAngle)
                                    .onAppear {
                                        rotationAngle = 360
                                    }
                            }
                            
                            Image(systemName: journeyManager.hasActiveJourney ? "location.fill" : "location")
                                .font(.system(size: 50, weight: .medium))
                                .foregroundColor(journeyManager.hasActiveJourney ? .red : .green)
                                .symbolEffect(.pulse, options: .repeating, value: journeyManager.hasActiveJourney)
                                .opacity(journeyManager.isLoading ? 0.6 : 1.0)
                        }
                        
                        // Status Text
                        VStack(spacing: 8) {
                            Text(statusText)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .animation(.easeInOut(duration: 0.3), value: statusText)
                            
                            if journeyManager.isLoading {
                                Text(loadingDetailText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .transition(.opacity.combined(with: .scale))
                            } else if let journey = journeyManager.currentJourney {
                                VStack(spacing: 4) {
                                    Text("Started from \(journey.startPostcode)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    if let clientName = journey.clientName, !clientName.isEmpty {
                                        Text("Client: \(clientName)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .multilineTextAlignment(.center)
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: journeyManager.isLoading)
                        
                        // Journey Input Form (only shown when no active journey)
                        if !journeyManager.hasActiveJourney {
                            VStack(spacing: 20) {
                                Text("Journey Details")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                VStack(spacing: 16) {
                                    // Client Name Field
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Client Name*")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        TextField("Enter client name", text: $clientName)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .autocapitalization(.words)
                                    }
                                    
                                    // Description Field
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Description*")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        TextField("Enter journey description", text: $description)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .autocapitalization(.sentences)
                                    }
                                    
                                    // Recharge to Client Toggle
                                    HStack {
                                        Text("Recharge to Client*")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Toggle("", isOn: $rechargeToClient)
                                            .labelsHidden()
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 32)
                        }
                        
                        // Action Button
                        VStack(spacing: 16) {
                            if journeyManager.hasActiveJourney {
                                Button(action: {
                                    Task {
                                        await journeyManager.endJourney()
                                        if let error = journeyManager.errorMessage {
                                            alertMessage = error
                                            showingAlert = true
                                        }
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        if journeyManager.isLoading {
                                            ProgressView()
                                                .scaleEffect(0.9)
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "stop.fill")
                                        }
                                        Text(journeyManager.isLoading ? "Ending Journey..." : "End Journey")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(journeyManager.isLoading ? Color.red.opacity(0.7) : Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                    .animation(.easeInOut(duration: 0.2), value: journeyManager.isLoading)
                                }
                                .disabled(journeyManager.isLoading)
                            } else {
                                Button(action: {
                                    Task {
                                        await startJourneyWithDetails()
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        if journeyManager.isLoading {
                                            ProgressView()
                                                .scaleEffect(0.9)
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "play.fill")
                                        }
                                        Text(journeyManager.isLoading ? "Starting Journey..." : "Start Journey")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(isStartButtonEnabled ? (journeyManager.isLoading ? Color.green.opacity(0.7) : Color.green) : Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                    .animation(.easeInOut(duration: 0.2), value: journeyManager.isLoading)
                                }
                                .disabled(!isStartButtonEnabled || journeyManager.isLoading)
                                
                                if !areAllFieldsValid {
                                    Text("Please fill in all required fields")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        // Loading Progress Card (shown when loading)
                        if journeyManager.isLoading {
                            LoadingProgressCard(isEndingJourney: journeyManager.hasActiveJourney)
                                .padding(.horizontal, 32)
                                .transition(.opacity.combined(with: .slide))
                        }
                        
                        // Location Permission Card (when needed)
                        if locationManager.authorizationStatus == .denied {
                            LocationPermissionCard()
                                .padding(.horizontal, 32)
                        }
                        
                        // Journey Details Card (show when available)
                        if let journey = journeyManager.currentJourney, !journeyManager.isLoading {
                            JourneyDetailsCard(journey: journey)
                                .padding(.horizontal, 32)
                        }
                        
                        // Bottom spacer
                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
            .navigationTitle("Journey Tracker")
            .navigationBarTitleDisplayMode(.large)
            .alert("Journey Update", isPresented: $showingAlert) {
                Button("OK") {
                    journeyManager.clearError()
                }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                locationManager.requestLocationPermission()
                
                // Pre-warm location services for faster location fixes
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    locationManager.startLocationUpdates()
                }
                
                Task {
                    await journeyManager.refreshAuthenticationState()
                }
            }
            .onDisappear {
                locationManager.stopLocationUpdates()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        if journeyManager.isLoading {
            return journeyManager.hasActiveJourney ? "Ending Journey" : "Starting Journey"
        } else {
            return journeyManager.hasActiveJourney ? "Journey in Progress" : "Ready to Track"
        }
    }
    
    private var loadingDetailText: String {
        if journeyManager.hasActiveJourney {
            return "Getting your current location and saving journey details..."
        } else {
            return "Getting your location and finding postcode..."
        }
    }
    
    private var isStartButtonEnabled: Bool {
        !clientName.isEmpty && !description.isEmpty && locationManager.authorizationStatus != .denied
    }
    
    private var areAllFieldsValid: Bool {
        !clientName.isEmpty && !description.isEmpty
    }
    
    private func startJourneyWithDetails() async {
        // Validate all required fields are filled
        guard !clientName.isEmpty && !description.isEmpty else {
            alertMessage = "Please fill in all required fields"
            showingAlert = true
            return
        }
        
        // Start the journey with the new details
        await journeyManager.startJourney(
            clientName: clientName,
            rechargeToClient: rechargeToClient,
            description: description
        )
        
        if let error = journeyManager.errorMessage {
            alertMessage = error
            showingAlert = true
        } else if journeyManager.hasActiveJourney {
            // Journey started successfully, clear the form
            clearInputFields()
        }
    }
    
    private func clearInputFields() {
        clientName = ""
        description = ""
        rechargeToClient = false
    }
}

// MARK: - Loading Progress Card

struct LoadingProgressCard: View {
    let isEndingJourney: Bool
    @State private var progressSteps: [ProgressStep] = []
    @State private var currentStep = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "location.circle.fill")
                    .foregroundColor(.blue)
                Text("Processing...")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(progressSteps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(step.isCompleted ? Color.green : (step.isActive ? Color.blue : Color.gray.opacity(0.3)))
                                .frame(width: 20, height: 20)
                            
                            if step.isActive && !step.isCompleted {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .tint(.white)
                            } else if step.isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Text(step.title)
                            .font(.subheadline)
                            .foregroundColor(step.isCompleted ? .primary : (step.isActive ? .blue : .secondary))
                    }
                    .animation(.easeInOut(duration: 0.3), value: step.isActive)
                    .animation(.easeInOut(duration: 0.3), value: step.isCompleted)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onAppear {
            setupProgressSteps()
            simulateProgress()
        }
    }
    
    private func setupProgressSteps() {
        if isEndingJourney {
            progressSteps = [
                ProgressStep(title: "Getting current location", isActive: true),
                ProgressStep(title: "Finding postcode"),
                ProgressStep(title: "Calculating distance"),
                ProgressStep(title: "Saving journey data")
            ]
        } else {
            progressSteps = [
                ProgressStep(title: "Getting current location", isActive: true),
                ProgressStep(title: "Finding postcode"),
                ProgressStep(title: "Creating journey record")
            ]
        }
    }
    
    private func simulateProgress() {
        // Simulate progress through the steps with realistic timing
        let intervals: [Double] = isEndingJourney ? [1.0, 2.0, 1.5, 2.0] : [1.0, 2.5, 1.5]
        var totalDelay = 0.0
        
        for (index, interval) in intervals.enumerated() {
            totalDelay += interval
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
                if index < self.progressSteps.count {
                    // Complete current step
                    self.progressSteps[index].isCompleted = true
                    self.progressSteps[index].isActive = false
                    
                    // Move to next step if available
                    let nextIndex = index + 1
                    if nextIndex < self.progressSteps.count {
                        self.progressSteps[nextIndex].isActive = true
                    }
                }
            }
        }
    }
}

struct ProgressStep {
    let title: String
    var isActive: Bool = false
    var isCompleted: Bool = false
}

struct JourneyDetailsCard: View {
    let journey: Journey
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map")
                    .foregroundColor(.blue)
                Text("Journey Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                if let clientName = journey.clientName, !clientName.isEmpty {
                    DetailRow(title: "Client", value: clientName)
                    Divider()
                }
                
                if let description = journey.description, !description.isEmpty {
                    DetailRow(title: "Description", value: description)
                    Divider()
                }
                
                if let rechargeToClient = journey.rechargeToClient {
                    DetailRow(title: "Recharge to Client", value: rechargeToClient ? "Yes" : "No")
                    Divider()
                }
                
                DetailRow(title: "Start Location", value: journey.startPostcode)
                
                if let endPostcode = journey.endPostcode {
                    DetailRow(title: "End Location", value: endPostcode)
                }
                
                if let startTime = journey.formattedStartTime {
                    DetailRow(title: "Started", value: formatTime(startTime))
                }
                
                if let distance = journey.distanceMiles {
                    DetailRow(title: "Distance", value: String(format: "%.2f miles", distance))
                }
                
                if !journey.isActive, let duration = journey.formattedEndTime {
                    DetailRow(title: "Duration", value: journey.duration)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct LocationPermissionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.slash")
                    .foregroundColor(.orange)
                Text("Location Access Required")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text("To track your journeys, please enable location access in Settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    JourneyTrackerView()
} 