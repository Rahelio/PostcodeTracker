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
    
    private var isCheckingActiveJourney = false
    private var isRefreshingAuth = false
    
    private let apiService = APIServiceV2.shared
    private let locationManager = LocationManager.shared
    private let modelContext: ModelContext = {
        let container = SwiftDataStack.shared
        return ModelContext(container)
    }()
    
    private init() {
        Task {
            // Small delay to ensure auth state is fully loaded before making API calls
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await checkActiveJourney()
        }
    }
    
    // MARK: - Journey Management
    
    func startJourney() async {
        // Debug authentication state
        print("🔍 StartJourney - Authentication Debug:")
        print("- APIService.isAuthenticated: \(apiService.isAuthenticated)")
        print("- AuthManager.isAuthenticated: \(AuthManager.shared.isAuthenticated)")
        
        // Double-check authentication state consistency
        if AuthManager.shared.isAuthenticated && !apiService.isAuthenticated {
            print("⚠️ Authentication state mismatch detected - refreshing...")
            await refreshAuthenticationState()
        }
        
        // Check if we're authenticated before starting a journey
        guard apiService.isAuthenticated else {
            print("❌ StartJourney blocked: APIService not authenticated")
            errorMessage = "Your session has expired. Please log in again."
            return
        }
        
        print("✅ StartJourney proceeding: Authentication check passed")
        
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
        
        // Check if we're authenticated before ending a journey
        guard apiService.isAuthenticated else {
            errorMessage = "Please log in to end your journey"
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
        // Prevent concurrent calls
        guard !isCheckingActiveJourney else {
            print("📝 Already checking active journey, skipping...")
            return
        }
        
        isCheckingActiveJourney = true
        defer { isCheckingActiveJourney = false }
        
        print("📝 Starting active journey check...")
        print("📝 Current journey state BEFORE check: \(currentJourney?.id ?? -1)")
        print("📝 Is tracking BEFORE check: \(isTrackingJourney)")
        
        // First, let's test the token with a simpler endpoint
        do {
            print("🔍 Testing token with profile endpoint first...")
            let _ = try await apiService.getProfile()
            print("✅ Token validation successful with profile endpoint")
        } catch {
            print("❌ Token validation failed with profile endpoint: \(error)")
            if case APIError.unauthorized = error {
                print("📝 Token is invalid - clearing journey state")
                currentJourney = nil
                isTrackingJourney = false
                clearJourneyState()
                return
            }
        }
        
        do {
            print("🔍 About to call getActiveJourney API")
            let response = try await apiService.getActiveJourney()
            print("📝 Active journey check successful")
            print("📝 Server response: active=\(response.active), journey=\(response.journey?.id ?? -1)")
            
            if response.active, let journey = response.journey {
                print("📝 Found active journey: \(journey.id)")
                print("📝 Journey details: \(journey.startPostcode) started at \(journey.startTime)")
                print("🚨 SETTING currentJourney and isTrackingJourney to TRUE")
                currentJourney = journey
                isTrackingJourney = true
                saveJourneyState()
            } else {
                print("📝 No active journey found")
                print("🚨 CLEARING currentJourney and isTrackingJourney")
                currentJourney = nil
                isTrackingJourney = false
                clearJourneyState()
            }
        } catch {
            print("📝 Active journey check failed: \(error)")
            errorMessage = handleError(error)
            
            // Don't clear journey state on network errors, only on auth errors
            if case APIError.unauthorized = error {
                print("📝 Unauthorized error - clearing journey state")
                currentJourney = nil
                isTrackingJourney = false
                clearJourneyState()
            }
        }
        
        print("📝 FINAL STATE after check: journey=\(currentJourney?.id ?? -1), tracking=\(isTrackingJourney)")
    }
    
    func loadJourneys() async {
        // Check if we're authenticated before making API calls
        guard apiService.isAuthenticated else {
            print("📝 Not authenticated, loading cached journeys only")
            await loadCachedJourneys()
            return
        }
        
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
                // Always show session expired message for 401 errors
                // (APIService will have triggered logout automatically)
                return "Your session has expired. Please log in again."
            case .serverError(let message):
                return message.isEmpty ? "Server error occurred. Please try again." : message
            default:
                return apiError.localizedDescription
            }
        } else if let locationError = error as? LocationManager.LocationError {
            switch locationError {
            case .timeout:
                return "Location request timed out. Please ensure you're in an area with good GPS signal and try again."
            case .denied:
                return "Location access denied. Please enable location services in Settings > Privacy & Security > Location Services."
            case .unavailable:
                return "Location services are not available. Please check your device settings."
            case .restricted:
                return "Location services are restricted on this device."
            default:
                return locationError.localizedDescription
            }
        } else {
            return error.localizedDescription
        }
    }
    
    // MARK: - Authentication Management
    
    func refreshAuthenticationState() async {
        // Prevent concurrent calls
        guard !isRefreshingAuth else {
            print("📝 Already refreshing authentication state, skipping...")
            return
        }
        
        isRefreshingAuth = true
        defer { isRefreshingAuth = false }
        
        print("📝 Refreshing authentication state...")
        
        // Refresh token from storage in case of sync issues
        apiService.refreshTokenFromStorage()
        
        // Wait longer for authentication to fully complete and sync
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        if apiService.isAuthenticated {
            print("📝 User is authenticated, checking for active journey...")
            await checkActiveJourney()
        } else {
            print("📝 User is not authenticated, clearing all journey state...")
            currentJourney = nil
            isTrackingJourney = false
            journeys = [] // Clear journeys list
            clearJourneyState()
            clearError()
            // Clear cached journeys for security
            await clearCachedJourneys()
        }
    }
    
    private func clearCachedJourneys() async {
        do {
            // Delete all cached journeys from SwiftData
            let localJourneys = try modelContext.fetch(FetchDescriptor<JourneyLocal>())
            for journey in localJourneys {
                modelContext.delete(journey)
            }
            try modelContext.save()
            print("📝 Cleared \(localJourneys.count) cached journeys from SwiftData")
        } catch {
            print("❌ Failed to clear cached journeys: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    
    func clearError() {
        errorMessage = nil
    }
    
    var hasActiveJourney: Bool {
        return currentJourney != nil && isTrackingJourney
    }
    
    // MARK: - Journey Label Management
    
    func updateJourneyLabel(journeyId: Int, label: String) async {
        guard apiService.isAuthenticated else {
            errorMessage = "Please log in to update journey label"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let response = try await apiService.updateJourneyLabel(journeyId: journeyId, label: label)
            
            if response.success, let updatedJourney = response.journey {
                // Update the current journey if it's the one being labeled
                if currentJourney?.id == updatedJourney.id {
                    currentJourney = updatedJourney
                }
                
                // Update in journeys list
                if let index = journeys.firstIndex(where: { $0.id == updatedJourney.id }) {
                    journeys[index] = updatedJourney
                }
                
                print("Journey label updated successfully: '\(label)'")
            } else {
                errorMessage = response.message ?? "Failed to update journey label"
            }
        } catch {
            errorMessage = handleError(error)
        }
    }
    
    // MARK: - Manual Journey Creation
    
    func createManualJourney(startPostcode: String, endPostcode: String) async throws -> JourneyResponse {
        guard apiService.isAuthenticated else {
            throw APIError.unauthorized
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let response = try await apiService.createManualJourney(
                startPostcode: startPostcode,
                endPostcode: endPostcode
            )
            
            if response.success, let journey = response.journey {
                // Add to journeys list
                journeys.insert(journey, at: 0)
                
                // Persist to SwiftData
                await persistJourneys([journey])
                
                print("Manual journey created successfully: \(journey.startPostcode) to \(journey.endPostcode ?? "unknown")")
            }
            
            return response
        } catch {
            errorMessage = handleError(error)
            throw error
        }
    }
    
    // MARK: - Journey Deletion
    
    func deleteJourneys(_ journeysToDelete: [Journey]) async {
        guard apiService.isAuthenticated else {
            errorMessage = "Please log in to delete journeys"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        // For now, we'll just remove from local storage
        // In the future, you could add server-side deletion API
        
        do {
            // Remove from local journeys array
            let idsToDelete = Set(journeysToDelete.map { $0.id })
            journeys.removeAll { idsToDelete.contains($0.id) }
            
            // Remove from SwiftData
            let localJourneys = try modelContext.fetch(FetchDescriptor<JourneyLocal>())
            for localJourney in localJourneys {
                if idsToDelete.contains(localJourney.id) {
                    modelContext.delete(localJourney)
                }
            }
            try modelContext.save()
            
            print("Successfully deleted \(journeysToDelete.count) journey(s)")
        } catch {
            errorMessage = "Failed to delete journeys: \(error.localizedDescription)"
        }
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
                       userId: 0, // Default value since we don't store this locally
                       startTime: ISO8601DateFormatter().string(from: entity.startTime),
                       endTime: entity.endTime != nil ? ISO8601DateFormatter().string(from: entity.endTime!) : nil,
                       startLatitude: nil, // Manual journeys don't have coordinates
                       startLongitude: nil, // Manual journeys don't have coordinates
                       endLatitude: nil,
                       endLongitude: nil,
                       startPostcode: entity.startPostcode,
                       endPostcode: entity.endPostcode,
                       distanceMiles: entity.distanceMiles,
                       isActive: entity.isActive,
                       label: nil) // Labels not stored locally for cached journeys
            }
            self.journeys = mapped
        } catch {
            print("Failed to load cached journeys: \(error)")
        }
    }
} 