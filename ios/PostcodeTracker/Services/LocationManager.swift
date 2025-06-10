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
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            error = .denied
        default:
            break
        }
    }
    
    func getCurrentLocation() async throws -> CLLocation {
        // Clear any previous errors
        error = nil
        
        // Check authorization
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            if authorizationStatus == .notDetermined {
                requestLocationPermission()
                throw LocationError.denied
            } else {
                throw LocationError.denied
            }
        }
        
        // Check if location services are enabled
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationError.unavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            
            // Set up timeout
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(throwing: LocationError.timeout)
                }
            }
            
            // Request location
            locationManager.requestLocation()
            
            // Wait for location update
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                if let location = self.location, !hasResumed {
                    hasResumed = true
                    timeoutTask.cancel()
                    continuation.resume(returning: location)
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
        error = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                self.error = .denied
            case .locationUnknown:
                self.error = .unavailable
            case .network:
                self.error = .unavailable
            default:
                self.error = .unknown(error)
            }
        } else {
            self.error = .unknown(error)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .denied, .restricted:
            error = .denied
        case .authorizedWhenInUse, .authorizedAlways:
            error = nil
        default:
            break
        }
    }
} 