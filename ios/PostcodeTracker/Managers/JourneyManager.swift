import Foundation
import SwiftUI
import SwiftData

@MainActor
class JourneyManager: ObservableObject {
    static let shared = JourneyManager()
    
    @Published var currentJourney: Journey?
    @Published var isTrackingJourney = false
    @Published var journeys: [Journey] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIServiceV2.shared
    private let locationManager = LocationManager.shared
    private let modelContext: ModelContext = {
        let container = SwiftDataStack.shared
        return ModelContext(container)
    }()
    
    private init() {
        Task {
            await checkActiveJourney()
        }
    }
    
    // MARK: - Journey Management
    
    func startJourney() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get current location
            let location = try await locationManager.getCurrentLocation()
            
            // Start journey with API - with retry logic for network timeouts
            let response = try await startJourneyWithRetry(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            
            if response.success, let journey = response.journey {
                currentJourney = journey
                isTrackingJourney = true
                
                // Save journey state locally
                saveJourneyState()
                
                print("Journey started successfully: \(journey.startPostcode)")
            } else {
                errorMessage = response.message ?? "Failed to start journey"
            }
            
        } catch {
            errorMessage = handleError(error)
        }
        
        isLoading = false
    }
    
    private func startJourneyWithRetry(latitude: Double, longitude: Double, maxRetries: Int = 2) async throws -> JourneyResponse {
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                print("🚀 Starting journey attempt \(attempt + 1)/\(maxRetries + 1)")
                let response = try await apiService.startJourney(
                    latitude: latitude,
                    longitude: longitude
                )
                return response
            } catch let error as APIError {
                lastError = error
                
                // Don't retry for certain errors
                switch error {
                case .unauthorized:
                    // Don't retry auth errors
                    throw error
                case .serverError(let message) where message.contains("already have an active journey"):
                    // Don't retry if user already has active journey
                    throw error
                case .networkError(let networkError):
                    let nsError = networkError as NSError
                    if (nsError.code == NSURLErrorTimedOut || nsError.code == 408) && attempt < maxRetries {
                        print("⏰ Request timed out (code: \(nsError.code)), retrying in 2 seconds...")
                        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                        continue
                    } else {
                        throw error
                    }
                default:
                    if attempt < maxRetries {
                        print("🔄 Retrying after error: \(error.localizedDescription)")
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        continue
                    } else {
                        throw error
                    }
                }
            } catch {
                lastError = error
                if attempt < maxRetries {
                    print("🔄 Retrying after unexpected error: \(error.localizedDescription)")
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    continue
                } else {
                    throw error
                }
            }
        }
        
        // This shouldn't be reached, but just in case
        throw lastError ?? APIError.networkError(NSError(domain: "UnknownError", code: -1))
    }
    
    func endJourney() async {
        guard currentJourney != nil else {
            errorMessage = "No active journey found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Get current location
            let location = try await locationManager.getCurrentLocation()
            
            // End journey with API
            let response = try await apiService.endJourney(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            
            if response.success, let completedJourney = response.journey {
                // Update the journey list
                if let index = journeys.firstIndex(where: { $0.id == completedJourney.id }) {
                    journeys[index] = completedJourney
                } else {
                    journeys.insert(completedJourney, at: 0)
                }
                
                // Clear current journey
                currentJourney = nil
                isTrackingJourney = false
                
                // Clear saved journey state
                clearJourneyState()
                
                print("Journey completed successfully: \(completedJourney.startPostcode) to \(completedJourney.endPostcode ?? "unknown")")
            } else {
                errorMessage = response.message ?? "Failed to end journey"
            }
            
        } catch {
            errorMessage = handleError(error)
        }
        
        isLoading = false
    }
    
    func checkActiveJourney() async {
        do {
            let response = try await apiService.getActiveJourney()
            
            if response.success && response.active, let journey = response.journey {
                currentJourney = journey
                isTrackingJourney = true
                saveJourneyState()
            } else {
                currentJourney = nil
                isTrackingJourney = false
                clearJourneyState()
            }
            
        } catch {
            // Don't show error for checking active journey on startup
            print("Error checking active journey: \(error)")
        }
    }
    
    func loadJourneys() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await apiService.getJourneys()
            if response.success {
                journeys = response.journeys
                // Persist to SwiftData
                await persistJourneys(response.journeys)
            } else {
                errorMessage = "Failed to load journeys"
            }
        } catch {
            errorMessage = handleError(error)
            // Attempt to load cached journeys on network error
            await loadCachedJourneys()
        }
        isLoading = false
    }
    
    func refreshJourneys() async {
        await loadJourneys()
    }
    
    // MARK: - Local State Management
    
    private func saveJourneyState() {
        if let journey = currentJourney,
           let data = try? JSONEncoder().encode(journey) {
            UserDefaults.standard.set(data, forKey: "current_journey")
            UserDefaults.standard.set(isTrackingJourney, forKey: "is_tracking_journey")
        }
    }
    
    private func clearJourneyState() {
        UserDefaults.standard.removeObject(forKey: "current_journey")
        UserDefaults.standard.removeObject(forKey: "is_tracking_journey")
    }
    
    private func loadJourneyState() {
        if let data = UserDefaults.standard.data(forKey: "current_journey"),
           let journey = try? JSONDecoder().decode(Journey.self, from: data) {
            currentJourney = journey
            isTrackingJourney = UserDefaults.standard.bool(forKey: "is_tracking_journey")
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .networkError(let networkError):
                let nsError = networkError as NSError
                if nsError.code == NSURLErrorTimedOut {
                    return "Request timed out. This might be due to poor connection or server delays. Please try again."
                } else if nsError.code == 408 {
                    return "Server timed out while looking up your postcode. Please try again or move to a different location."
                } else if nsError.code == NSURLErrorNotConnectedToInternet {
                    return "No internet connection. Please check your network and try again."
                } else {
                    return "Network error: \(networkError.localizedDescription)"
                }
            case .unauthorized:
                return "Session expired. Please log in again."
            case .serverError(let message):
                return message.isEmpty ? "Server error occurred. Please try again." : message
            default:
                return apiError.localizedDescription
            }
        } else if let locationError = error as? LocationManager.LocationError {
            return locationError.localizedDescription
        } else {
            return error.localizedDescription
        }
    }
    
    // MARK: - Utility Methods
    
    func clearError() {
        errorMessage = nil
    }
    
    var hasActiveJourney: Bool {
        return currentJourney != nil && isTrackingJourney
    }
    
    // MARK: - SwiftData Persistence
    private func persistJourneys(_ journeys: [Journey]) async {
        for journey in journeys {
            // Upsert into SwiftData
            if let entity = try? modelContext.fetch(FetchDescriptor<JourneyLocal>(predicate: #Predicate { $0.id == journey.id })).first {
                // Update existing
                entity.startPostcode = journey.startPostcode
                entity.endPostcode = journey.endPostcode
                entity.startTime = journey.formattedStartTime ?? Date()
                entity.endTime = journey.formattedEndTime
                entity.distanceMiles = journey.distanceMiles
                entity.isActive = journey.isActive
            } else {
                // Insert new
                let newEntity = JourneyLocal(id: journey.id,
                                             startPostcode: journey.startPostcode,
                                             endPostcode: journey.endPostcode,
                                             startTime: journey.formattedStartTime ?? Date(),
                                             endTime: journey.formattedEndTime,
                                             distanceMiles: journey.distanceMiles,
                                             isActive: journey.isActive)
                modelContext.insert(newEntity)
            }
        }
        do {
            try modelContext.save()
        } catch {
            print("Failed to save journeys to SwiftData: \(error)")
        }
    }

    private func loadCachedJourneys() async {
        do {
            let localJourneys = try modelContext.fetch(FetchDescriptor<JourneyLocal>())
            let mapped = localJourneys.map { entity in
                Journey(id: entity.id,
                        start_postcode: entity.startPostcode,
                        end_postcode: entity.endPostcode,
                        distance_miles: entity.distanceMiles,
                        start_time: ISO8601DateFormatter().string(from: entity.startTime),
                        end_time: entity.endTime != nil ? ISO8601DateFormatter().string(from: entity.endTime!) : nil,
                        is_active: entity.isActive,
                        is_manual: false,
                        start_location: nil,
                        end_location: nil,
                        userId: nil)
            }
            self.journeys = mapped
        } catch {
            print("Failed to load cached journeys: \(error)")
        }
    }
} 