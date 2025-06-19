import SwiftUI

extension Color {
    static let customBackground = Color(UIColor.systemBackground)
    static let customSecondaryBackground = Color(UIColor.secondarySystemBackground)
    static let customTertiaryBackground = Color(UIColor.tertiarySystemBackground)
    
    static let customText = Color(UIColor.label)
    static let customSecondaryText = Color(UIColor.secondaryLabel)
    
    static let systemGray6 = Color(UIColor.systemGray6)
    
    // Category colors
    static let categoryColors: [Color] = [
        .blue, .purple, .green, .orange, .pink, .yellow, .red, .teal, .indigo, .mint
    ]
    
    static func color(for category: String) -> Color {
        let hash = abs(category.hashValue)
        return categoryColors[hash % categoryColors.count]
    }
} 