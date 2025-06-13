import Foundation
import CoreLocation
import SwiftUI

@MainActor
class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var location: CLLocation?
    @Published var error: LocationError?
    
    enum LocationError: Error, LocalizedError {
        case denied
        case restricted
        case unavailable
        case timeout
        case unknown(Error)
        
        var errorDescription: String? {
            switch self {
            case .denied:
                return "Location access denied. Please enable location services in Settings."
            case .restricted:
                return "Location services are restricted."
            case .unavailable:
                return "Location services are not available."
            case .timeout:
                return "Location request timed out."
            case .unknown(let error):
                return "Location error: \(error.localizedDescription)"
            }
        }
    }
    
    override init() {
        super.init()
        locationManager.delegate = self
        // Use balanced accuracy for faster location fixes
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        // Set distance filter to avoid too many updates
        locationManager.distanceFilter = 10.0
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            print("📍 Requesting location permission...")
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("❌ Location permission denied or restricted")
            error = .denied
        default:
            print("📍 Location permission already granted: \(authorizationStatus.rawValue)")
            break
        }
    }
    
    var hasLocationPermission: Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    func startLocationUpdates() {
        guard hasLocationPermission else { return }
        guard CLLocationManager.locationServicesEnabled() else { return }
        
        print("📍 Starting location updates for pre-warming...")
        locationManager.startUpdatingLocation()
        
        // Stop updates after getting a fix or timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.locationManager.stopUpdatingLocation()
            print("📍 Stopped pre-warming location updates")
        }
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    func requestLocationPermissionIfNeeded() async throws {
        if authorizationStatus == .notDetermined {
            requestLocationPermission()
            
            // Wait for permission response (up to 10 seconds)
            for _ in 0..<20 {
                if authorizationStatus != .notDetermined {
                    break
                }
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            if authorizationStatus == .notDetermined {
                throw LocationError.timeout
            }
        }
        
        guard hasLocationPermission else {
            throw LocationError.denied
        }
    }
    
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var locationTimeoutTask: Task<Void, Never>?
    
    func getCurrentLocation() async throws -> CLLocation {
        // Clear any previous errors
        error = nil
        
        // Check if location services are enabled
        guard CLLocationManager.locationServicesEnabled() else {
            print("❌ Location services not enabled")
            throw LocationError.unavailable
        }
        
        // Request permission if needed
        try await requestLocationPermissionIfNeeded()
        
        // If we have a recent location (less than 30 seconds old), use it
        if let cachedLocation = location,
           cachedLocation.timestamp.timeIntervalSinceNow > -30 {
            print("📍 Using cached location: \(cachedLocation.coordinate)")
            return cachedLocation
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Store the continuation for delegate callbacks
            locationContinuation = continuation
            
            // Set up timeout (25 seconds - longer timeout for better reliability)
            locationTimeoutTask = Task {
                try? await Task.sleep(nanoseconds: 25_000_000_000) // 25 seconds
                await MainActor.run {
                    if locationContinuation != nil {
                        print("⏰ Location request timed out after 25 seconds")
                        locationContinuation?.resume(throwing: LocationError.timeout)
                        locationContinuation = nil
                    }
                }
            }
            
            print("📍 Requesting current location...")
            // Request location
            locationManager.requestLocation()
        }
    }
    
    private func completeLocationRequest(with location: CLLocation) {
        if let continuation = locationContinuation {
            print("📍 Location obtained: \(location.coordinate)")
            locationTimeoutTask?.cancel()
            continuation.resume(returning: location)
            locationContinuation = nil
        }
    }
    
    private func failLocationRequest(with error: LocationError) {
        if let continuation = locationContinuation {
            print("❌ Location request failed: \(error.localizedDescription)")
            locationTimeoutTask?.cancel()
            continuation.resume(throwing: error)
            locationContinuation = nil
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Update stored location
        self.location = location
        error = nil
        
        // Complete any pending location request
        completeLocationRequest(with: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let locationError: LocationError
        
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = .denied
            case .locationUnknown:
                locationError = .unavailable
            case .network:
                locationError = .unavailable
            default:
                locationError = .unknown(error)
            }
        } else {
            locationError = .unknown(error)
        }
        
        // Update stored error
        self.error = locationError
        
        // Fail any pending location request
        failLocationRequest(with: locationError)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .denied, .restricted:
            let deniedError = LocationError.denied
            error = deniedError
            // Fail any pending location request due to permission denial
            failLocationRequest(with: deniedError)
        case .authorizedWhenInUse, .authorizedAlways:
            error = nil
        default:
            break
        }
    }
} 