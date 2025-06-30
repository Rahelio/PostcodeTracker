import SwiftUI

struct CreateManualJourneyView: View {
    @StateObject private var postcodeManager = PostcodeManager.shared
    @StateObject private var journeyManager = JourneyManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedStartPostcode: SavedPostcode?
    @State private var selectedEndPostcode: SavedPostcode?
    @State private var isCreating = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // Client information fields
    @State private var clientName = ""
    @State private var rechargeToClient = false
    @State private var description = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Start Location")) {
                    if postcodeManager.savedPostcodes.isEmpty {
                        Text("No saved postcodes available")
                            .foregroundColor(.secondary)
                        
                        Button("Add postcodes first") {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                    } else {
                        Picker("Start Postcode", selection: $selectedStartPostcode) {
                            Text("Select start postcode").tag(nil as SavedPostcode?)
                            ForEach(postcodeManager.savedPostcodes) { postcode in
                                VStack(alignment: .leading) {
                                    Text(postcode.formattedPostcode)
                                        .font(.headline)
                                    if !postcode.label.isEmpty {
                                        Text(postcode.label)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tag(postcode as SavedPostcode?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section(header: Text("End Location")) {
                    if !postcodeManager.savedPostcodes.isEmpty {
                        Picker("End Postcode", selection: $selectedEndPostcode) {
                            Text("Select end postcode").tag(nil as SavedPostcode?)
                            ForEach(postcodeManager.savedPostcodes) { postcode in
                                VStack(alignment: .leading) {
                                    Text(postcode.formattedPostcode)
                                        .font(.headline)
                                    if !postcode.label.isEmpty {
                                        Text(postcode.label)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tag(postcode as SavedPostcode?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                // Client Information Section
                Section(header: Text("Client Information")) {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Client Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            TextField("Enter client name", text: $clientName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            TextField("Enter description", text: $description)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.sentences)
                        }
                        
                        Toggle(isOn: $rechargeToClient) {
                            Text("Recharge to Client")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                    .padding(.vertical, 4)
                }
                
                if let start = selectedStartPostcode, let end = selectedEndPostcode {
                    Section(header: Text("Journey Preview")) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("From")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(start.formattedPostcode)
                                    .font(.headline)
                                if !start.label.isEmpty {
                                    Text(start.label)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("To")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(end.formattedPostcode)
                                    .font(.headline)
                                if !end.label.isEmpty {
                                    Text(end.label)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section(footer: Text("Distance will be calculated automatically when the journey is created")) {
                    EmptyView()
                }
            }
            .navigationTitle("Create Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createManualJourney()
                    }
                    .disabled(selectedStartPostcode == nil || selectedEndPostcode == nil || selectedStartPostcode?.id == selectedEndPostcode?.id || isCreating || !areAllFieldsValid)
                }
            }
            .alert("Journey Creation", isPresented: $showingAlert) {
                Button("OK") {
                    if !alertMessage.contains("Error") && !alertMessage.contains("Failed") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .overlay {
                if isCreating {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            
                            Text("Creating journey...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(24)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var areAllFieldsValid: Bool {
        !clientName.isEmpty && !description.isEmpty
    }
    
    // MARK: - Methods
    
    private func createManualJourney() {
        guard let startPostcode = selectedStartPostcode,
              let endPostcode = selectedEndPostcode else {
            return
        }
        
        Task {
            isCreating = true
            
            do {
                let response = try await journeyManager.createManualJourney(
                    startPostcode: startPostcode.formattedPostcode,
                    endPostcode: endPostcode.formattedPostcode,
                    clientName: clientName,
                    rechargeToClient: rechargeToClient,
                    description: description
                )
                
                await MainActor.run {
                    isCreating = false
                    if response.success {
                        alertMessage = "Journey created successfully!"
                    } else {
                        alertMessage = response.message ?? "Failed to create journey"
                    }
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    alertMessage = "Error creating journey: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

#Preview {
    CreateManualJourneyView()
} 