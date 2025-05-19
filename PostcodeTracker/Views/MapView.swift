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
    @State private var postcodes: [Postcode] = []
    @State private var annotations: [PostcodeAnnotation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Map(coordinateRegion: $region, annotationItems: annotations) { annotation in
                    MapAnnotation(coordinate: annotation.coordinate) {
                        VStack {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                            Text(annotation.title)
                                .font(.caption)
                                .padding(4)
                                .background(Color.white)
                                .cornerRadius(4)
                                .shadow(radius: 2)
                        }
                    }
                }
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            .navigationTitle("Map")
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
            await geocodePostcodes()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func geocodePostcodes() async {
        let geocoder = CLGeocoder()
        var newAnnotations: [PostcodeAnnotation] = []
        
        for postcode in postcodes {
            do {
                let placemarks = try await geocoder.geocodeAddressString(postcode.postcode)
                if let location = placemarks.first?.location?.coordinate {
                    let annotation = PostcodeAnnotation(
                        id: postcode.id,
                        coordinate: location,
                        title: postcode.postcode,
                        postcode: postcode
                    )
                    newAnnotations.append(annotation)
                }
            } catch {
                print("Geocoding error for \(postcode.postcode): \(error.localizedDescription)")
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