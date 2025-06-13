import SwiftUI

struct ProfileView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var apiService = APIServiceV2.shared
    @State private var showingLogoutAlert = false
    @State private var isLoading = false
    @State private var userProfile: User?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            List {
                // Loading indicator
                if isLoading && userProfile == nil {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading profile...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // User Info Section
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userProfile?.username ?? authManager.currentUser?.username ?? "User")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            if let createdAt = userProfile?.formattedCreatedAt {
                                Text("Member since \(createdAt, formatter: dateFormatter)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Postcode Tracker User")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                // Journey Statistics Section
                if let profile = userProfile {
                    Section("Journey Statistics") {
                        HStack {
                            Image(systemName: "map")
                                .foregroundColor(.blue)
                            Text("Total Journeys")
                            Spacer()
                            Text("\(profile.totalJourneys ?? 0)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Text("Completed Journeys")
                            Spacer()
                            Text("\(profile.completedJourneys ?? 0)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "road.lanes")
                                .foregroundColor(.orange)
                            Text("Total Distance")
                            Spacer()
                            Text(String(format: "%.1f miles", profile.totalDistanceMiles ?? 0))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // App Info Section
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Version")
                        Spacer()
                        Text("2.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "location.circle")
                            .foregroundColor(.green)
                        Text("Location Services")
                        Spacer()
                        Text("Enabled")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Actions Section
                Section("Account") {
                    Button(action: {
                        showingLogoutAlert = true
                    }) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadProfile()
            }
            .task {
                await loadProfile()
            }
            .alert("Sign Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await performLogout()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    private func loadProfile() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            userProfile = try await apiService.getProfile()
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load profile: \(error)")
        }
        
        isLoading = false
    }
    
    private func performLogout() async {
        isLoading = true
        
        do {
            // Call server logout endpoint
            try await apiService.logout()
            print("✅ Server logout successful")
        } catch {
            print("⚠️ Logout error (continuing with local logout): \(error)")
        }
        
        // Clear auth manager state
        authManager.logout()
        print("✅ Auth manager state cleared")
        
        // Clear journey manager state
        await JourneyManager.shared.refreshAuthenticationState()
        print("✅ Journey manager state cleared")
        
        // Clear postcode cache for privacy
        PostcodeCache.shared.clearCache()
        print("✅ Postcode cache cleared")
        
        // Clear legacy journey state (if any)
        JourneyState.clear()
        print("✅ Legacy journey state cleared")
        
        isLoading = false
        print("✅ Complete logout finished")
        
        // Verify all state is cleared
        verifyLogoutComplete()
    }
    
    private func verifyLogoutComplete() {
        print("🔍 Verifying logout completeness...")
        
        // Check API service state
        let hasToken = apiService.isAuthenticated
        print("- API Service authenticated: \(hasToken)")
        
        // Check AuthManager state
        let authState = authManager.isAuthenticated
        print("- AuthManager authenticated: \(authState)")
        
        // Check UserDefaults keys
        let hasAuthToken = UserDefaults.standard.string(forKey: "auth_token") != nil
        let hasCurrentUser = UserDefaults.standard.data(forKey: "current_user") != nil
        let hasIsAuthenticated = UserDefaults.standard.bool(forKey: "is_authenticated")
        let hasCurrentJourney = UserDefaults.standard.data(forKey: "current_journey") != nil
        let hasIsTracking = UserDefaults.standard.bool(forKey: "is_tracking_journey")
        let hasActiveJourney = UserDefaults.standard.data(forKey: "activeJourney") != nil
        
        print("- UserDefaults auth_token: \(hasAuthToken)")
        print("- UserDefaults current_user: \(hasCurrentUser)")
        print("- UserDefaults is_authenticated: \(hasIsAuthenticated)")
        print("- UserDefaults current_journey: \(hasCurrentJourney)")
        print("- UserDefaults is_tracking_journey: \(hasIsTracking)")
        print("- UserDefaults activeJourney (legacy): \(hasActiveJourney)")
        
        // Check if all state is properly cleared
        let isCompletelyLoggedOut = !hasToken && !authState && !hasAuthToken && !hasCurrentUser && !hasIsAuthenticated && !hasCurrentJourney && !hasIsTracking && !hasActiveJourney
        
        if isCompletelyLoggedOut {
            print("✅ Logout verification PASSED - All state cleared")
        } else {
            print("❌ Logout verification FAILED - Some state remains")
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

#Preview {
    ProfileView()
} 