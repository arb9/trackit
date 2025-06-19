import SwiftUI

extension Color {
    static let categoryColors: [Color] = [
        .blue, .purple, .green, .orange, .pink, .yellow, .red, .teal, .indigo, .mint
    ]
        
    static func categoryColor(for category: String) -> Color {
        let colors: [Color] = [
            .blue,
            .green,
            .orange,
            .purple,
            .pink,
            .red,
            .yellow,
            .mint,
            .indigo,
            .teal
        ]
        
        let index = abs(category.hashValue) % colors.count
        return colors[index]
    }
} 
