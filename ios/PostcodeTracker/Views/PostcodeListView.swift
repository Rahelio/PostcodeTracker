import SwiftUI

struct PostcodeListView: View {
    @State private var postcodes: [Postcode] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddPostcode = false
    @State private var newPostcode = ""
    @State private var newName = ""
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    List {
                        ForEach(postcodes) { postcode in
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
                                Text("Added: \(formatDate(postcode.created_at))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .onDelete(perform: deletePostcode)
                    }
                }
            }
            .navigationTitle("Postcodes")
            .toolbar {
                Button(action: {
                    showingAddPostcode = true
                }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddPostcode) {
                NavigationView {
                    Form {
                        Section(header: Text("Postcode Details")) {
                            TextField("Enter name", text: $newName)
                            TextField("Enter postcode", text: $newPostcode)
                                .autocapitalization(.allCharacters)
                        }
                    }
                    .navigationTitle("Add Postcode")
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            showingAddPostcode = false
                            newPostcode = ""
                            newName = ""
                        },
                        trailing: Button("Add") {
                            Task {
                                await addPostcode()
                            }
                        }
                        .disabled(newPostcode.isEmpty)
                    )
                }
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
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
        return dateString
    }
}

#Preview {
    PostcodeListView()
} 
