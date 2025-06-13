import SwiftUI
import CoreLocation

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
                    JourneysList()
                }
            }
            .navigationTitle("Journey History")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            loadJourneys()
        }
        .alert("Journey Update", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadJourneys() {
        Task {
            do {
                try await journeyManager.loadJourneys()
            } catch {
                alertMessage = "Failed to load journeys: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

struct EmptyJourneysView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Journeys Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start tracking your journeys to see them here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct JourneysList: View {
    @StateObject private var journeyManager = JourneyManager.shared
    
    var body: some View {
        List {
            ForEach(journeyManager.journeys, id: \.id) { journey in
                JourneyRowView(journey: journey)
                    .listRowBackground(Color(.systemBackground))
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            Task {
                try? await journeyManager.loadJourneys()
            }
        }
    }
}

struct JourneyRowView: View {
    let journey: Journey
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(journey.start_postcode) → \(journey.end_postcode ?? "In Progress")")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let startTime = journey.formattedStartTime, let endTime = journey.formattedEndTime {
                        Text(formatJourneyTime(start: startTime, end: endTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let startTime = journey.formattedStartTime {
                        Text("Started \(formatRelativeTime(startTime))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else {
                        Text("Started \(journey.start_time)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let distance = journey.distance_miles {
                        Text("\(String(format: "%.1f", distance)) mi")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    if journey.end_time == nil {
                        Text("Active")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatJourneyTime(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        if Calendar.current.isDate(start, inSameDayAs: end) {
            // Same day: show date and time range
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            
            return "\(dateFormatter.string(from: start)) \(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))"
        } else {
            // Different days: show full start and end
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    JourneysView()
} 