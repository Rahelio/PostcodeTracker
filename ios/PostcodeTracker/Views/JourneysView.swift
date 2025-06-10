import SwiftUI
import UniformTypeIdentifiers

struct JourneysView: View {
    @StateObject private var journeyManager = JourneyManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if journeyManager.isLoading {
                    ProgressView("Loading journeys...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if journeyManager.journeys.isEmpty {
                    EmptyJourneysView()
                } else {
                    List {
                        ForEach(journeyManager.journeys) { journey in
                            JourneyRowView(journey: journey)
                                .listRowBackground(Color(.systemBackground))
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await journeyManager.refreshJourneys()
                    }
                }
            }
            .navigationTitle("Journey History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await journeyManager.loadJourneys()
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await journeyManager.loadJourneys()
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") {
                    journeyManager.clearError()
                }
            } message: {
                Text(alertMessage)
            }
            .onChange(of: journeyManager.errorMessage) { error in
                if let error = error {
                    alertMessage = error
                    showingAlert = true
                }
            }
        }
    }
}

struct JourneyRowView: View {
    let journey: Journey
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with date and status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let startTime = journey.formattedStartTime {
                        Text(formatDate(startTime))
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(formatTime(startTime))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if journey.isActive {
                    Text("Active")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
            }
            
            // Route information
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    RoutePoint(
                        icon: "circle.fill",
                        color: .green,
                        title: "From",
                        location: journey.startPostcode
                    )
                    
                    if let endPostcode = journey.endPostcode {
                        RoutePoint(
                            icon: "circle.fill",
                            color: .red,
                            title: "To",
                            location: endPostcode
                        )
                    }
                }
                
                Spacer()
                
                // Journey stats
                VStack(alignment: .trailing, spacing: 8) {
                    if let distance = journey.distanceMiles {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.2f", distance))
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("miles")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !journey.isActive {
                        Text(journey.duration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct RoutePoint: View {
    let icon: String
    let color: Color
    let title: String
    let location: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(location)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }
}

struct EmptyJourneysView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Journeys Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start tracking your journeys to see them here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    JourneysView()
} 