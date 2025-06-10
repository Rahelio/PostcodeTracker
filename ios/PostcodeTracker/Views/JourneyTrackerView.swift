import SwiftUI
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastKnownLocation: CLLocation?
    private var isUpdatingLocation = false
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10 // Update every 10 meters
        manager.allowsBackgroundLocationUpdates = true // Enable background updates
        manager.pausesLocationUpdatesAutomatically = false // Don't pause updates
        startUpdatingLocation()
    }
    
    func startUpdatingLocation() {
        if !isUpdatingLocation {
            manager.startUpdatingLocation()
            isUpdatingLocation = true
        }
    }
    
    func stopUpdatingLocation() {
        if isUpdatingLocation {
            manager.stopUpdatingLocation()
            isUpdatingLocation = false
        }
    }
    
    func requestLocation() async throws -> CLLocation {
        // If we have a recent location (less than 5 seconds old), use it
        if let lastLocation = lastKnownLocation,
           Date().timeIntervalSince(lastLocation.timestamp) < 5 {
            return lastLocation
        }
        
        // Check authorization status
        if manager.authorizationStatus == .notDetermined {
            manager.requestAlwaysAuthorization() // Request always authorization for background
            // Wait for authorization
            try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
        }
        
        // Check if we have permission
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            throw NSError(domain: "LocationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Location access is denied. Please enable it in Settings."])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            lastKnownLocation = location
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
            
            // Save location to UserDefaults for background tracking
            if let encoded = try? JSONEncoder().encode([
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "timestamp": location.timestamp.timeIntervalSince1970
            ]) {
                UserDefaults.standard.set(encoded, forKey: "lastKnownLocation")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

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
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        VStack(spacing: 16) {
                            // Status Icon
                            ZStack {
                                Circle()
                                    .fill(journeyManager.hasActiveJourney ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: journeyManager.hasActiveJourney ? "location.fill" : "location")
                                    .font(.system(size: 50, weight: .medium))
                                    .foregroundColor(journeyManager.hasActiveJourney ? .red : .green)
                                    .symbolEffect(.pulse, options: .repeating, value: journeyManager.hasActiveJourney)
                            }
                            
                            // Status Text
                            VStack(spacing: 8) {
                                Text(journeyManager.hasActiveJourney ? "Journey in Progress" : "Ready to Track")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                if let journey = journeyManager.currentJourney {
                                    Text("Started from \(journey.startPostcode)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.top, 32)
                        
                        // Journey Details Card
                        if let journey = journeyManager.currentJourney {
                            JourneyDetailsCard(journey: journey)
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
                                    HStack {
                                        Image(systemName: "stop.fill")
                                        Text("End Journey")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(journeyManager.isLoading)
                            } else {
                                Button(action: {
                                    Task {
                                        await journeyManager.startJourney()
                                        if let error = journeyManager.errorMessage {
                                            alertMessage = error
                                            showingAlert = true
                                        }
                                    }
                                }) {
                                    HStack {
                                        if journeyManager.isLoading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "play.fill")
                                        }
                                        Text(journeyManager.isLoading ? "Starting..." : "Start Journey")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(journeyManager.isLoading || locationManager.authorizationStatus == .denied)
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        // Location Permission Card
                        if locationManager.authorizationStatus == .denied {
                            LocationPermissionCard()
                        }
                        
                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 20)
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
                Task {
                    await journeyManager.checkActiveJourney()
                }
            }
<<<<<<< HEAD
=======
            .onDisappear {
                locationManager.stopUpdatingLocation()
                // Save journey state
                if isRecording {
                    let state = JourneyState(
                        isRecording: isRecording,
                        startPostcode: startPostcode,
                        endPostcode: endPostcode,
                        distance: distance,
                        startTime: Date(),
                        journeyId: currentJourneyId
                    )
                    JourneyState.save(state)
                } else {
                    JourneyState.clear()
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func startJourney() {
        isLoading = true
        
        // Begin background task
        backgroundTask = UIApplication.shared.beginBackgroundTask { [self] in
            endBackgroundTask()
        }
        
        Task {
            defer {
                isLoading = false
                endBackgroundTask()
            }
            
            do {
                // Get location
                print("Attempting to get current location for start...")
                let location = try await locationManager.requestLocation()
                print("Location obtained for start: Latitude = \(location.coordinate.latitude), Longitude = \(location.coordinate.longitude)")
                
                // Call API to start the journey and get both ID and postcode data
                print("Calling API to start journey...")
                
                // Check if the API returned journey data
                if let result = try await APIService.shared.startTrackedJourney(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                ) {
                    currentJourneyId = result.journeyId // Store the journey ID
                    startPostcode = result.postcode     // Use postcode from API response
                    isRecording = true
                    
                    alertMessage = "Journey started! Start postcode: \(result.postcode.postcode)"
                    showingAlert = true

                    // Save state
                    let state = JourneyState(
                        isRecording: true,
                        startPostcode: startPostcode,
                        endPostcode: nil,
                        distance: nil,
                        startTime: Date(),
                        journeyId: currentJourneyId
                    )
                    JourneyState.save(state)
                } else {
                    // Server returned nil, meaning postcode was not found for start location
                    print("API returned nil for start tracked journey. Postcode not found.")
                    alertMessage = "Could not determine your starting postcode. Please try again in a different location."
                    showingAlert = true
                    // Do not start recording or save state if journey couldn't be started on server
                }
                
            } catch { // This catch block would also show an alert, but likely a different message
                print("Error in startJourney task: \(error.localizedDescription)")
                alertMessage = "Error starting journey: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func endJourney() {
        guard isRecording, let journeyId = currentJourneyId else {
            alertMessage = "No active journey to end."
            showingAlert = true
            return
        }
        
        isLoading = true
        
        // Begin background task
        backgroundTask = UIApplication.shared.beginBackgroundTask { [self] in
            endBackgroundTask()
        }
        
        Task {
            defer {
                isLoading = false
                endBackgroundTask()
            }
            
            do {
                // Get end location
                print("Attempting to get current location for end...")
                let location = try await locationManager.requestLocation()
                print("Location obtained for end: Latitude = \(location.coordinate.latitude), Longitude = \(location.coordinate.longitude)")
                
                // Call API to end the journey
                print("Calling API to end journey with ID: \(journeyId)...")
                let completedJourney = try await APIService.shared.endTrackedJourney(
                    journeyId: journeyId,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                
                // Update UI with completed journey details
                startPostcode = completedJourney.start_location
                endPostcode = completedJourney.end_location
                distance = completedJourney.distance_miles
                
                // Reset for next journey
                isRecording = false
                currentJourneyId = nil // Clear journey ID
                
                // Clear saved state
                JourneyState.clear()
                
                alertMessage = "Journey completed! Distance: \(String(format: "%.1f", completedJourney.distance_miles ?? 0.0)) miles"
                showingAlert = true
                
            } catch {
                print("Error in endJourney task: \(error.localizedDescription)")
                alertMessage = "Error ending journey: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func createManualJourney() {
        isLoading = true
        
        Task {
            do {
                // First, start the journey
                let journeyId = try await APIService.shared.startJourney(
                    startPostcode: manualStartPostcode,
                    isManual: true
                )
                
                // Then end it with the end postcode
                let journey = try await APIService.shared.endJourney(
                    journeyId: journeyId,
                    endPostcode: manualEndPostcode,
                    distanceMiles: 0.0  // The server will calculate the distance
                )
                
                // Update UI with journey details
                startPostcode = journey.start_location
                endPostcode = journey.end_location
                distance = journey.distance_miles
                
                // Clear manual entry fields
                manualStartPostcode = ""
                manualEndPostcode = ""
                isManualEntry = false
                
                alertMessage = "Manual journey created! Distance: \(String(format: "%.1f", journey.distance_miles ?? 0.0)) miles"
                showingAlert = true
            } catch {
                alertMessage = "Error: \(error.localizedDescription)"
                showingAlert = true
            }
            isLoading = false
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
        }
    }
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