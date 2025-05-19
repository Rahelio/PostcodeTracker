import SwiftUI

struct PostcodeListView: View {
    var body: some View {
        NavigationView {
            List {
                Text("Postcode list will go here")
            }
            .navigationTitle("Postcodes")
            .toolbar {
                Button(action: {
                    // TODO: Add new postcode
                }) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

#Preview {
    PostcodeListView()
} 