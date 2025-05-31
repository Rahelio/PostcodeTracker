import SwiftUI
import MapKit

struct PostcodeAnnotation: Identifiable {
    let id: Int
    let coordinate: CLLocationCoordinate2D
    let title: String
    let postcode: Postcode
}

struct MapView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var selectedPostcode: Postcode?
    @State private var postcodes: [Postcode] = []
    @State private var annotations: [PostcodeAnnotation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                Map(coordinateRegion: $region, annotationItems: postcodes) { postcode in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(
                        latitude: postcode.latitude ?? 0,
                        longitude: postcode.longitude ?? 0
                    )) {
                        VStack {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundColor(.accentColor)
                                .shadow(radius: 2)
                            Text(postcode.name)
                                .playfairDisplay(.caption)
                                .padding(4)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(radius: 1)
                        }
                        .onTapGesture {
                            selectedPostcode = postcode
                        }
                    }
                }
                .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.8))
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedPostcode) { postcode in
                NavigationView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(postcode.name)
                                .playfairDisplay(.title2)
                                .foregroundColor(.primary)
                            
                            Text(postcode.postcode)
                                .playfairDisplay(.headline)
                                .foregroundColor(.secondary)
                            
                            if let lat = postcode.latitude, let lon = postcode.longitude {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.4f, %.4f", lat, lon))")
                                        .playfairDisplay(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Location Details")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                selectedPostcode = nil
                            }
                            .playfairDisplay(.body)
                        }
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .playfairDisplay(.body)
                }
            }
            .task {
                await loadPostcodes()
            }
        }
    }
    
    private func loadPostcodes() async {
        isLoading = true
        errorMessage = nil
        
        do {
            postcodes = try await APIService.shared.getPostcodes()
            await createAnnotations()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func createAnnotations() async {
        var newAnnotations: [PostcodeAnnotation] = []
        
        for postcode in postcodes {
            if let latitude = postcode.latitude, let longitude = postcode.longitude {
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    let annotation = PostcodeAnnotation(
                        id: postcode.id,
                    coordinate: coordinate,
                        title: postcode.postcode,
                        postcode: postcode
                    )
                    newAnnotations.append(annotation)
            }
        }
        
        await MainActor.run {
            annotations = newAnnotations
            if let firstAnnotation = newAnnotations.first {
                region = MKCoordinateRegion(
                    center: firstAnnotation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                )
            }
        }
    }
}

#Preview {
    MapView()
} 
