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