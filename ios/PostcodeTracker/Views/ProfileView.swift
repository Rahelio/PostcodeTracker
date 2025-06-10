import SwiftUI

struct ProfileView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var apiService = APIService.shared
    @State private var showingLogoutAlert = false
    @State private var isLoading = false
    @State private var userProfile: User?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            List {
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
                Section {
                    Button(action: {
                        showingLogoutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
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
            try await apiService.logout()
        } catch {
            print("Logout error: \(error)")
        }
        
        authManager.logout()
        isLoading = false
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