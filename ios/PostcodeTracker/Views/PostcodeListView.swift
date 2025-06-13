import SwiftUI

struct PostcodeTextField: ViewModifier {
    @Binding var text: String
    
    func body(content: Content) -> some View {
        content
            .textInputAutocapitalization(.characters)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .foregroundColor(.primary)
            .onChange(of: text) { newValue in
                // Convert to uppercase and remove any existing spaces
                let cleaned = newValue.uppercased().replacingOccurrences(of: " ", with: "")
                
                // Add space after 4 characters if there are more than 4 characters
                if cleaned.count > 4 {
                    let index = cleaned.index(cleaned.startIndex, offsetBy: 4)
                    let firstPart = cleaned[..<index]
                    let secondPart = cleaned[index...]
                    text = "\(firstPart) \(secondPart)"
                } else {
                    text = cleaned
                }
            }
    }
}

extension View {
    func postcodeInput(_ text: Binding<String>) -> some View {
        modifier(PostcodeTextField(text: text))
    }
}

struct PostcodeListView: View {
    @State private var postcodes: [Postcode] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddPostcode = false
    @State private var newPostcode = ""
    @State private var newName = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                PostcodeListContentView(
                    postcodes: postcodes,
                    isLoading: isLoading,
                    onDelete: deletePostcode
                )
            }
            .navigationTitle("Postcodes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                Button(action: {
                    withAnimation {
                        showingAddPostcode = true
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            .sheet(isPresented: $showingAddPostcode) {
                AddPostcodeView(
                    newPostcode: $newPostcode,
                    newName: $newName,
                    onAdd: addPostcode,
                    onCancel: {
                        withAnimation {
                            showingAddPostcode = false
                            newPostcode = ""
                            newName = ""
                        }
                    }
                )
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .playfairDisplay(.body)
                        .foregroundColor(.primary)
                }
            }
            .task {
                await loadPostcodes()
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func loadPostcodes() async {
        isLoading = true
        errorMessage = nil
        
        // Postcode management has been removed from the API
        // The app now focuses on journey tracking instead
        postcodes = []
        
        isLoading = false
    }
    
    private func addPostcode() async {
        // Postcode management has been removed from the API
        // Show message to user that this feature is no longer available
        errorMessage = "Postcode management is no longer available. The app now focuses on journey tracking."
        showingAddPostcode = false
    }
    
    private func deletePostcode(at offsets: IndexSet) {
        // Postcode management has been removed from the API
        // This function is kept for compatibility but does nothing
        errorMessage = "Postcode management is no longer available. The app now focuses on journey tracking."
    }
}

struct PostcodeListContentView: View {
    let postcodes: [Postcode]
    let isLoading: Bool
    let onDelete: (IndexSet) -> Void
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.primary)
            } else if postcodes.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Postcode Management Removed")
                        .playfairDisplay(.title2)
                        .foregroundColor(.primary)
                    Text("The app now focuses on journey tracking. Use the Journey Tracker tab instead.")
                        .playfairDisplay(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(postcodes) { postcode in
                        PostcodeRow(postcode: postcode)
                            .listRowBackground(Color(.systemBackground))
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 4)
                    }
                    .onDelete(perform: onDelete)
                }
                .listStyle(.plain)
                .background(Color(.systemBackground))
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct PostcodeRow: View {
    let postcode: Postcode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.accentColor)
                Text(postcode.name)
                    .playfairDisplay(.headline)
                    .foregroundColor(.primary)
            }
            
            Text(postcode.postcode)
                .playfairDisplay(.subheadline)
                .foregroundColor(.secondary)
            
            if let lat = postcode.latitude, let lon = postcode.longitude {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.4f, %.4f", lat, lon))")
                        .playfairDisplay(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct AddPostcodeView: View {
    @Binding var newPostcode: String
    @Binding var newName: String
    let onAdd: () async -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                Form {
                    Section {
                        TextField("Postcode", text: $newPostcode)
                            .postcodeInput($newPostcode)
                            .playfairDisplay(.body)
                            .foregroundColor(.primary)
                        TextField("Name (optional)", text: $newName)
                            .playfairDisplay(.body)
                            .foregroundColor(.primary)
                    } header: {
                        Text("Postcode Details")
                            .playfairDisplay(.headline)
                            .foregroundColor(.primary)
                    } footer: {
                        Text("Enter a UK postcode and optionally give it a name for easy reference.")
                            .playfairDisplay(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Postcode")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel)
                    .playfairDisplay(.body)
                    .foregroundColor(.primary),
                trailing: Button("Add") {
                    Task { await onAdd() }
                }
                .playfairDisplay(.body)
                .disabled(newPostcode.isEmpty)
                .foregroundColor(newPostcode.isEmpty ? .gray : .primary)
            )
            .navigationViewStyle(.stack)
        }
    }
}

#Preview {
    PostcodeListView()
}
