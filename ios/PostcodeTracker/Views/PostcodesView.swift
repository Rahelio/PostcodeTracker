import SwiftUI

struct PostcodesView: View {
    @StateObject private var postcodeManager = PostcodeManager.shared
    @State private var newPostcode = ""
    @State private var newLabel = ""
    @State private var showingAddSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingBulkDeleteAlert = false
    @State private var selectedPostcodes = Set<SavedPostcode.ID>()
    @State private var isSelectionMode = false
    @State private var editingPostcode: SavedPostcode?
    @State private var editingLabel = ""
    @State private var showingCreateJourney = false
    
    var body: some View {
        NavigationView {
            VStack {
                if postcodeManager.savedPostcodes.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Saved Postcodes")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Add postcodes to create manual journeys")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Add Postcode") {
                            showingAddSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    // Postcode list
                    List {
                        ForEach(postcodeManager.savedPostcodes) { postcode in
                            PostcodeRow(
                                postcode: postcode,
                                isSelected: selectedPostcodes.contains(postcode.id),
                                isSelectionMode: isSelectionMode,
                                onTap: {
                                    if isSelectionMode {
                                        toggleSelection(postcode)
                                    }
                                },
                                onEdit: {
                                    editingPostcode = postcode
                                    editingLabel = postcode.label
                                }
                            )
                        }
                        .onDelete(perform: deletePostcodes)
                    }
                }
            }
            .navigationTitle("Saved Postcodes")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !postcodeManager.savedPostcodes.isEmpty {
                        Button("Journey") {
                            showingCreateJourney = true
                        }
                        .font(.caption)
                        
                        Button(isSelectionMode ? "Done" : "Select") {
                            isSelectionMode.toggle()
                            if !isSelectionMode {
                                selectedPostcodes.removeAll()
                            }
                        }
                    }
                    
                    Button("Add") {
                        showingAddSheet = true
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if isSelectionMode && !selectedPostcodes.isEmpty {
                        Button("Delete Selected") {
                            showingBulkDeleteAlert = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddPostcodeSheet(
                    newPostcode: $newPostcode,
                    newLabel: $newLabel,
                    onSave: addPostcode,
                    onCancel: cancelAdd
                )
            }
            .sheet(isPresented: $showingCreateJourney) {
                CreateManualJourneyView()
            }
            .sheet(item: $editingPostcode) { postcode in
                EditPostcodeSheet(
                    postcode: postcode,
                    editingLabel: $editingLabel,
                    onSave: saveEdit,
                    onCancel: cancelEdit
                )
            }
            .alert("Delete Postcodes", isPresented: $showingBulkDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteBulkPostcodes()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete \(selectedPostcodes.count) postcode(s)?")
            }
            .alert("Error", isPresented: .constant(postcodeManager.errorMessage != nil)) {
                Button("OK") {
                    postcodeManager.clearError()
                }
            } message: {
                Text(postcodeManager.errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleSelection(_ postcode: SavedPostcode) {
        if selectedPostcodes.contains(postcode.id) {
            selectedPostcodes.remove(postcode.id)
        } else {
            selectedPostcodes.insert(postcode.id)
        }
    }
    
    private func deletePostcodes(offsets: IndexSet) {
        let postcodesToDelete = offsets.map { postcodeManager.savedPostcodes[$0] }
        postcodeManager.deletePostcodes(postcodesToDelete)
    }
    
    private func deleteBulkPostcodes() {
        let postcodesToDelete = postcodeManager.savedPostcodes.filter { selectedPostcodes.contains($0.id) }
        postcodeManager.deletePostcodes(postcodesToDelete)
        selectedPostcodes.removeAll()
        isSelectionMode = false
    }
    
    private func addPostcode() {
        postcodeManager.addPostcode(newPostcode, label: newLabel)
        newPostcode = ""
        newLabel = ""
        showingAddSheet = false
    }
    
    private func cancelAdd() {
        newPostcode = ""
        newLabel = ""
        showingAddSheet = false
    }
    
    private func saveEdit() {
        if let postcode = editingPostcode {
            postcodeManager.updatePostcode(postcode, newLabel: editingLabel)
        }
        editingPostcode = nil
        editingLabel = ""
    }
    
    private func cancelEdit() {
        editingPostcode = nil
        editingLabel = ""
    }
}

// MARK: - Supporting Views

struct PostcodeRow: View {
    let postcode: SavedPostcode
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .onTapGesture {
                        onTap()
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(postcode.formattedPostcode)
                    .font(.headline)
                    .fontWeight(.medium)
                
                if !postcode.label.isEmpty {
                    Text(postcode.label)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("Added \(postcode.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !isSelectionMode {
                Button("Edit") {
                    onEdit()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onTap()
            }
        }
    }
}

struct AddPostcodeSheet: View {
    @Binding var newPostcode: String
    @Binding var newLabel: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Postcode Details")) {
                    PostcodeInputField(text: $newPostcode, placeholder: "Enter postcode")
                    
                    TextField("Label (optional)", text: $newLabel)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section(footer: Text("Postcode will be automatically formatted and validated")) {
                    EmptyView()
                }
            }
            .navigationTitle("Add Postcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(newPostcode.isEmpty)
                }
            }
        }
    }
}

struct EditPostcodeSheet: View {
    let postcode: SavedPostcode
    @Binding var editingLabel: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Postcode")) {
                    Text(postcode.formattedPostcode)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Label")) {
                    TextField("Label", text: $editingLabel)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .navigationTitle("Edit Postcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                }
            }
        }
    }
}

#Preview {
    PostcodesView()
} 