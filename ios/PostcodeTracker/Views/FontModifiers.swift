import SwiftUI

struct PlayfairDisplayFont: ViewModifier {
    enum Style {
        case largeTitle
        case title
        case title2
        case title3
        case headline
        case body
        case subheadline
        case caption
        
        var size: CGFloat {
            switch self {
            case .largeTitle: return 34
            case .title: return 28
            case .title2: return 22
            case .title3: return 20
            case .headline: return 17
            case .body: return 17
            case .subheadline: return 15
            case .caption: return 12
            }
        }
        
        var weight: Font.Weight {
            switch self {
            case .largeTitle, .title, .title2, .title3, .headline:
                return .bold
            case .body, .subheadline, .caption:
                return .regular
            }
        }
    }
    
    let style: Style
    
    func body(content: Content) -> some View {
        content
            .font(.custom("PlayfairDisplay-\(style.weight == .bold ? "Bold" : "Regular")", size: style.size))
    }
}

extension View {
    func playfairDisplay(_ style: PlayfairDisplayFont.Style) -> some View {
        modifier(PlayfairDisplayFont(style: style))
    }
} 