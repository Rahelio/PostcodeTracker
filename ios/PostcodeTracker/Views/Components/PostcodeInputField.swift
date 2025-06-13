import SwiftUI

struct PostcodeInputField: View {
    @Binding var text: String
    let placeholder: String
    let maxLength: Int = 8 // UK postcode max length including space
    
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .autocapitalization(.allCharacters)
            .disableAutocorrection(true)
            .keyboardType(.asciiCapable)
            .onChange(of: text) { oldValue, newValue in
                formatPostcodeInput(newValue)
            }
    }
    
    private func formatPostcodeInput(_ input: String) {
        // Remove existing spaces and convert to uppercase
        let cleaned = input.replacingOccurrences(of: " ", with: "").uppercased()
        
        // Limit to max length (excluding space)
        let limited = String(cleaned.prefix(7)) // 7 chars max for postcode without space
        
        // Add space after 4 characters if we have more than 4
        var formatted = limited
        if limited.count > 4 {
            let firstPart = String(limited.prefix(4))
            let secondPart = String(limited.dropFirst(4))
            formatted = "\(firstPart) \(secondPart)"
        }
        
        // Only update if different to avoid infinite loop
        if formatted != text {
            text = formatted
        }
    }
}

#Preview {
    @State var testText = ""
    return PostcodeInputField(text: $testText, placeholder: "Enter postcode")
        .padding()
} 