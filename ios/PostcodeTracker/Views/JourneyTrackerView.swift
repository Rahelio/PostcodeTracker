import SwiftUI
import CoreLocation

struct JourneyTrackerView: View {
    @State private var isRecording = false
    @State private var startPostcode: Postcode?
    @State private var endPostcode: Postcode?
    @State private var distance: Double?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var locationManager = CLLocationManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status Card
                VStack(spacing: 10) {
                    Text(isRecording ? "Journey in Progress" : "Ready to Start")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isRecording ? .red : .green)
                    
                    if let start = startPostcode {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Start Location")
                                .font(.headline)
                            Text(start.name)
                                .font(.subheadline)
                            Text(start.postcode)
                                .font(.caption)
                                .foregroundColor(.gray)
                            if let lat = start.latitude, let lon = start.longitude {
                                Text("Coordinates: \(String(format: "%.4f, %.4f", lat, lon))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    if let end = endPostcode {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("End Location")
                                .font(.headline)
                            Text(end.name)
                                .font(.subheadline)
                            Text(end.postcode)
                                .font(.caption)
                                .foregroundColor(.gray)
                            if let lat = end.latitude, let lon = end.longitude {
                                Text("Coordinates: \(String(format: "%.4f, %.4f", lat, lon))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    if let distance = distance {
                        Text(String(format: "Distance: %.1f miles", distance))
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(15)
                .shadow(radius: 5)
                
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
            }
            .padding()
            .navigationTitle("Track Journey")
            .alert("Journey Update", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                locationManager.requestWhenInUseAuthorization()
            }
        }
    }
    
    private func startJourney() {
        isLoading = true
        locationManager.requestLocation()
        
        Task {
            do {
                let location = try await getCurrentLocation()
                let postcode = try await APIService.shared.getPostcodeFromCoordinates(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                
                if let postcode = postcode {
                    startPostcode = postcode
                    isRecording = true
                    alertMessage = "Journey started at \(postcode.name) (\(postcode.postcode))"
                    showingAlert = true
                } else {
                    alertMessage = "Could not determine your postcode"
                    showingAlert = true
                }
            } catch {
                alertMessage = "Error: \(error.localizedDescription)"
                showingAlert = true
            }
            isLoading = false
        }
    }
    
    private func endJourney() {
        isLoading = true
        locationManager.requestLocation()
        
        Task {
            do {
                let location = try await getCurrentLocation()
                let postcode = try await APIService.shared.getPostcodeFromCoordinates(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                
                if let postcode = postcode {
                    endPostcode = postcode
                    
                    // Calculate distance
                    if let start = startPostcode {
                        let journey = try await APIService.shared.createJourney(
                            startPostcode: start.postcode,
                            endPostcode: postcode.postcode
                        )
                        distance = journey.distance_miles
                        
                        // Reset for next journey
                        isRecording = false
                        startPostcode = nil
                        endPostcode = nil
                        
                        alertMessage = "Journey completed! Distance: \(String(format: "%.1f", journey.distance_miles)) miles"
                        showingAlert = true
                    }
                } else {
                    alertMessage = "Could not determine your postcode"
                    showingAlert = true
                }
            } catch {
                alertMessage = "Error: \(error.localizedDescription)"
                showingAlert = true
            }
            isLoading = false
        }
    }
    
    private func getCurrentLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            locationManager.delegate = LocationDelegate(continuation: continuation)
        }
    }
}

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    let continuation: CheckedContinuation<CLLocation, Error>
    
    init(continuation: CheckedContinuation<CLLocation, Error>) {
        self.continuation = continuation
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            continuation.resume(returning: location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation.resume(throwing: error)
    }
}

#Preview {
    JourneyTrackerView()
} 