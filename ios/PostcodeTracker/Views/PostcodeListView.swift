import SwiftUI

struct PostcodeTextField: ViewModifier {
    @Binding var text: String
    
    func body(content: Content) -> some View {
        content
            .textInputAutocapitalization(.characters)
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
            PostcodeListContentView(
                postcodes: postcodes,
                isLoading: isLoading,
                onDelete: deletePostcode
            )
            .navigationTitle("Postcodes")
            .toolbar {
                Button(action: {
                    showingAddPostcode = true
                }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddPostcode) {
                AddPostcodeView(
                    newPostcode: $newPostcode,
                    newName: $newName,
                    onAdd: addPostcode,
                    onCancel: {
                        showingAddPostcode = false
                        newPostcode = ""
                        newName = ""
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
                }
            }
        }
        .task {
            await loadPostcodes()
        }
    }
    
    private func loadPostcodes() async {
        isLoading = true
        errorMessage = nil
        
        do {
            postcodes = try await APIService.shared.getPostcodes()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func addPostcode() async {
        guard !newPostcode.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let postcode = try await APIService.shared.addPostcode(newPostcode, name: newName.isEmpty ? newPostcode : newName)
            postcodes.append(postcode)
            newPostcode = ""
            newName = ""
            showingAddPostcode = false
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func deletePostcode(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let postcode = postcodes[index]
                do {
                    try await APIService.shared.deletePostcode(id: postcode.id)
                    postcodes.remove(at: index)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
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
            } else {
                List {
                    ForEach(postcodes) { postcode in
                        PostcodeRow(postcode: postcode)
                    }
                    .onDelete(perform: onDelete)
                }
            }
        }
    }
}

struct PostcodeRow: View {
    let postcode: Postcode
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(postcode.name)
                .font(.headline)
            Text(postcode.postcode)
                .font(.subheadline)
                .foregroundColor(.gray)
            if let lat = postcode.latitude, let lon = postcode.longitude {
                Text("Location: \(String(format: "%.4f, %.4f", lat, lon))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct AddPostcodeView: View {
    @Binding var newPostcode: String
    @Binding var newName: String
    let onAdd: () async -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Postcode Details")) {
                    TextField("Postcode", text: $newPostcode)
                        .postcodeInput($newPostcode)
                    TextField("Name (optional)", text: $newName)
                }
            }
            .navigationTitle("Add Postcode")
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel),
                trailing: Button("Add", action: {
                    Task { await onAdd() }
                })
                .disabled(newPostcode.isEmpty)
            )
        }
    }
}

#Preview {
    PostcodeListView()
} 
