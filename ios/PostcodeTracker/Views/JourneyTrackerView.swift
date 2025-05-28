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
    @State private var isRecording = false
    @State private var startPostcode: Postcode?
    @State private var endPostcode: Postcode?
    @State private var distance: Double?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @StateObject private var locationManager = LocationManager()
    @State private var isManualEntry = false
    @State private var manualStartPostcode = ""
    @State private var manualEndPostcode = ""
<<<<<<< HEAD
    @State private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    @State private var currentJourneyId: Int? // State variable to hold journey ID
=======
>>>>>>> 4896a22 (updates to server side and ios app)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // Spacer to push content down
                    Spacer()
                        .frame(height: isRecording ? UIScreen.main.bounds.height * 0.05 : UIScreen.main.bounds.height * 0.15)
                    
                    // Main Status and Controls
                    VStack(spacing: 30) {
                        // Status Header
                        VStack(spacing: 12) {
                            Image(systemName: isRecording ? "location.fill" : "location")
                                .font(.system(size: 60))
                                .foregroundColor(isRecording ? .red : .green)
                                .symbolEffect(.bounce, options: .repeating, value: isRecording)
                            
                            Text(isRecording ? "Journey in Progress" : "Ready to Start")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(isRecording ? .red : .green)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Action Button
                        if !isRecording {
                            Button(action: startJourney) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Start Journey")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                                .shadow(color: Color.green.opacity(0.3), radius: 5, x: 0, y: 3)
                            }
                            .padding(.horizontal, 40)
                        } else {
                            Button(action: endJourney) {
                                HStack {
                                    Image(systemName: "stop.fill")
                                    Text("End Journey")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                                .shadow(color: Color.red.opacity(0.3), radius: 5, x: 0, y: 3)
                            }
                            .padding(.horizontal, 40)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Spacer to balance the layout
                    Spacer()
                        .frame(height: isRecording ? UIScreen.main.bounds.height * 0.05 : UIScreen.main.bounds.height * 0.15)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                    }
                    
                    // Journey Details Section
                    if startPostcode != nil || endPostcode != nil {
                        VStack(spacing: 15) {
                            // Start Location Card
                            if let start = startPostcode {
                                LocationCard(
                                    title: "Start Location",
                                    name: start.name,
                                    postcode: start.postcode,
                                    latitude: start.latitude,
                                    longitude: start.longitude
                                )
                            }
                            
                            // End Location Card
                            if let end = endPostcode {
                                LocationCard(
                                    title: "End Location",
                                    name: end.name,
                                    postcode: end.postcode,
                                    latitude: end.latitude,
                                    longitude: end.longitude
                                )
                            }
                            
                            // Distance Card
                            if let distance = distance {
                                VStack(spacing: 8) {
                                    Text("Distance")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.1f miles", distance))
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(15)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        )
                        .padding(.horizontal)
                    }
                    
                    // Manual Entry Section
                    if isManualEntry {
                        VStack(spacing: 20) {
                            TextField("Start Postcode", text: $manualStartPostcode)
                                .postcodeInput($manualStartPostcode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                                .padding(.horizontal)
                            
                            TextField("End Postcode", text: $manualEndPostcode)
                                .postcodeInput($manualEndPostcode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                                .padding(.horizontal)
                            
                            Button(action: createManualJourney) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Create Manual Journey")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                                .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                            }
                            .disabled(manualStartPostcode.isEmpty || manualEndPostcode.isEmpty)
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        )
                        .padding(.horizontal)
                    }
                }
<<<<<<< HEAD
                .padding(.vertical)
=======
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(15)
                .shadow(radius: 5)
                
                if isManualEntry {
                    VStack(spacing: 20) {
                        TextField("Start Postcode", text: $manualStartPostcode)
                            .postcodeInput($manualStartPostcode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                        
                        TextField("End Postcode", text: $manualEndPostcode)
                            .postcodeInput($manualEndPostcode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                        
                        Button(action: createManualJourney) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create Manual Journey")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(manualStartPostcode.isEmpty || manualEndPostcode.isEmpty)
                    }
                    .padding()
                }
                
                // Action Buttons
                VStack(spacing: 15) {
                    if !isRecording {
                        Button(action: startJourney) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start Journey")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    } else {
                        Button(action: endJourney) {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("End Journey")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                }
>>>>>>> 4896a22 (updates to server side and ios app)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Track Journey")
            .alert("Journey Update", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                locationManager.startUpdatingLocation()
                // Restore journey state if it exists
                if let state = JourneyState.load() {
                    isRecording = state.isRecording
                    startPostcode = state.startPostcode
                    endPostcode = state.endPostcode
                    distance = state.distance
                    currentJourneyId = state.journeyId // Load journey ID
                }
            }
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
                        journeyId: currentJourneyId // Save journey ID
                    )
                    JourneyState.save(state)
                } else {
                    JourneyState.clear()
                }
            }
        }
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
                
                // Call API to start the journey and get the ID
                print("Calling API to start journey...")
                
                // Check if the API returned a journey ID
                if let journeyId = try await APIService.shared.startTrackedJourney(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                ) {
                    currentJourneyId = journeyId // Store the journey ID
                    isRecording = true
                    
                    // Optionally fetch start postcode after starting journey if needed for display
                    // or rely on the server response for initial details
                    if let postcode = try await APIService.shared.getPostcodeFromCoordinates(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    ) {
                         startPostcode = postcode
                         alertMessage = "Journey started! Start postcode: \(postcode.postcode)"
                    } else {
                         startPostcode = nil
                         alertMessage = "Journey started! Could not determine start postcode."
                    }
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
                
                alertMessage = "Journey completed! Distance: \(String(format: "%.1f", completedJourney.distance_miles)) miles"
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
                let journey = try await APIService.shared.createManualJourney(
                    startPostcode: manualStartPostcode,
                    endPostcode: manualEndPostcode
                )
                
                // Update UI with journey details
                startPostcode = journey.start_location
                endPostcode = journey.end_location
                distance = journey.distance_miles
                
                // Clear manual entry fields
                manualStartPostcode = ""
                manualEndPostcode = ""
                isManualEntry = false
                
                alertMessage = "Manual journey created! Distance: \(String(format: "%.1f", journey.distance_miles)) miles"
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
        }
    }
    
    private func createManualJourney() {
        isLoading = true
        
        Task {
            do {
                let journey = try await APIService.shared.createManualJourney(
                    startPostcode: manualStartPostcode,
                    endPostcode: manualEndPostcode
                )
                
                // Update UI with journey details
                startPostcode = journey.start_location
                endPostcode = journey.end_location
                distance = journey.distance_miles
                
                // Clear manual entry fields
                manualStartPostcode = ""
                manualEndPostcode = ""
                isManualEntry = false
                
                alertMessage = "Manual journey created! Distance: \(String(format: "%.1f", journey.distance_miles)) miles"
                showingAlert = true
            } catch {
                alertMessage = "Error: \(error.localizedDescription)"
                showingAlert = true
            }
            isLoading = false
        }
    }
}

// Location Card View
struct LocationCard: View {
    let title: String
    let name: String
    let postcode: String
    let latitude: Double?
    let longitude: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(name)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(postcode)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let lat = latitude, let lon = longitude {
                Text("Location: \(String(format: "%.4f, %.4f", lat, lon))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

#Preview {
    JourneyTrackerView()
} 