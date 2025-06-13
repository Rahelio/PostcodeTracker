import Foundation
import SwiftUI
import SwiftData

@MainActor
class PostcodeManager: ObservableObject {
    static let shared = PostcodeManager()
    
    @Published var savedPostcodes: [SavedPostcode] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let modelContext: ModelContext = {
        let container = SwiftDataStack.shared
        return ModelContext(container)
    }()
    
    private init() {
        loadSavedPostcodes()
    }
    
    // MARK: - CRUD Operations
    
    func addPostcode(_ postcode: String, label: String) {
        let formattedPostcode = postcode.formatAsPostcode()
        
        // Validate postcode
        guard formattedPostcode.isValidUKPostcode else {
            errorMessage = "Invalid UK postcode format"
            return
        }
        
        // Check for duplicates
        if savedPostcodes.contains(where: { $0.postcode.lowercased() == formattedPostcode.lowercased() }) {
            errorMessage = "Postcode already exists"
            return
        }
        
        let newPostcode = SavedPostcode(postcode: formattedPostcode, label: label)
        modelContext.insert(newPostcode)
        
        do {
            try modelContext.save()
            loadSavedPostcodes()
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save postcode: \(error.localizedDescription)"
        }
    }
    
    func deletePostcodes(_ postcodes: [SavedPostcode]) {
        for postcode in postcodes {
            modelContext.delete(postcode)
        }
        
        do {
            try modelContext.save()
            loadSavedPostcodes()
            errorMessage = nil
        } catch {
            errorMessage = "Failed to delete postcodes: \(error.localizedDescription)"
        }
    }
    
    func deleteAllPostcodes() {
        for postcode in savedPostcodes {
            modelContext.delete(postcode)
        }
        
        do {
            try modelContext.save()
            loadSavedPostcodes()
            errorMessage = nil
        } catch {
            errorMessage = "Failed to delete all postcodes: \(error.localizedDescription)"
        }
    }
    
    func updatePostcode(_ postcode: SavedPostcode, newLabel: String) {
        postcode.label = newLabel
        
        do {
            try modelContext.save()
            loadSavedPostcodes()
            errorMessage = nil
        } catch {
            errorMessage = "Failed to update postcode: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Data Loading
    
    private func loadSavedPostcodes() {
        do {
            let descriptor = FetchDescriptor<SavedPostcode>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
            savedPostcodes = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load postcodes: \(error.localizedDescription)"
            savedPostcodes = []
        }
    }
    
    func refreshPostcodes() {
        loadSavedPostcodes()
    }
    
    // MARK: - Utility Methods
    
    func clearError() {
        errorMessage = nil
    }
    
    var hasPostcodes: Bool {
        return !savedPostcodes.isEmpty
    }
} 