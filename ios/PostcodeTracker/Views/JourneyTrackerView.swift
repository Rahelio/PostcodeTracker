import SwiftUI
import CoreLocation

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
    @State private var showingLabelInput = false
    @State private var journeyLabel = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack {
                    // Top spacer for vertical centering
                    Spacer()
                    
                    // Centered content
                    VStack(spacing: 32) {
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
                                .multilineTextAlignment(.center)
                            
                            if let journey = journeyManager.currentJourney {
                                Text("Started from \(journey.startPostcode)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        
                        // Action Button
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
                                    } else if journeyManager.hasActiveJourney {
                                        // Journey started successfully, show label input
                                        showingLabelInput = true
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
                    
                    // Bottom spacer for vertical centering
                    Spacer()
                    
                    // Location Permission Card (fixed at bottom when needed)
                    if locationManager.authorizationStatus == .denied {
                        LocationPermissionCard()
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                    
                    // Journey Details Card (show at bottom when available)
                    if let journey = journeyManager.currentJourney {
                        ScrollView {
                            JourneyDetailsCard(journey: journey)
                                .padding(.horizontal, 20)
                        }
                        .frame(maxHeight: 200)
                        .padding(.bottom, 20)
                    }
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
                
                // Pre-warm location services for faster location fixes
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    locationManager.startLocationUpdates()
                }
                
                Task {
                    await journeyManager.refreshAuthenticationState()
                }
            }
            .onDisappear {
                locationManager.stopLocationUpdates()
            }
            .sheet(isPresented: $showingLabelInput) {
                JourneyLabelInputView(
                    journeyLabel: $journeyLabel,
                    onSave: {
                        if let journey = journeyManager.currentJourney {
                            Task {
                                await journeyManager.updateJourneyLabel(
                                    journeyId: journey.id,
                                    label: journeyLabel
                                )
                            }
                        }
                        journeyLabel = ""
                        showingLabelInput = false
                    },
                    onSkip: {
                        journeyLabel = ""
                        showingLabelInput = false
                    }
                )
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
                if let label = journey.label, !label.isEmpty {
                    DetailRow(title: "Label", value: label)
                    Divider()
                }
                
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

struct JourneyLabelInputView: View {
    @Binding var journeyLabel: String
    let onSave: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Label Your Journey")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Add a label to help you identify this journey later (optional)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Journey Label")
                        .font(.headline)
                    
                    TextField("e.g., To Work, Shopping Trip, Visit Family", text: $journeyLabel)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.done)
                        .onSubmit {
                            if !journeyLabel.isEmpty {
                                onSave()
                            }
                        }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Journey Started")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        onSkip()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(journeyLabel.isEmpty)
                }
            }
        }
    }
}

#Preview {
    JourneyTrackerView()
} 