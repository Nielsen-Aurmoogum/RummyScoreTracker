import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Color Hex Persistence

extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }

        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int(r * 255), gi = Int(g * 255), bi = Int(b * 255)
        return String(format: "#%02X%02X%02X", ri, gi, bi)
        #else
        return "#000000"
        #endif
    }
}

// MARK: - App Theme Colors

extension Color {
    /// Card-red accent — the app's signature color
    static let cardRed = Color(hex: "#C0392B")
}

// MARK: - Avatar Color Palette

extension Color {
    static let avatarPalette: [Color] = [
        Color(hex: "#C0392B"), // Card Red
        Color(hex: "#2C3E50"), // Charcoal
        Color(hex: "#27AE60"), // Emerald
        Color(hex: "#D4A017"), // Gold
        Color(hex: "#8E44AD"), // Amethyst
        Color(hex: "#2980B9"), // Steel Blue
        Color(hex: "#D35400"), // Burnt Orange
        Color(hex: "#16A085"), // Teal
    ]

    static func avatarColor(at index: Int) -> Color {
        avatarPalette[index % avatarPalette.count]
    }
}

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(.separator).opacity(0.4), lineWidth: 0.5)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Haptic Feedback

#if canImport(UIKit)
extension UIImpactFeedbackGenerator {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
#endif

// MARK: - Seeded RNG

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 6364136223846793005
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Date Formatting

extension Date {
    var friendlyFormat: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    var shortDateFormat: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}

// MARK: - Int Score Display

extension Int {
    var scoreString: String { "\(self)" }
}

// MARK: - Shared Avatar Picker Components

struct ColorCircle: View {
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 36, height: 36)
            .overlay(
                Circle()
                    .stroke(Color.primary, lineWidth: isSelected ? 3 : 0)
                    .padding(2)
            )
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .onTapGesture(perform: onTap)
    }
}

struct EmojiCell: View {
    let emoji: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        let bgColor: Color = isSelected ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemFill)
        let borderColor: Color = isSelected ? Color.accentColor : Color.clear

        Text(emoji)
            .font(.system(size: 28))
            .frame(width: 44, height: 44)
            .background(RoundedRectangle(cornerRadius: 10).fill(bgColor))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderColor, lineWidth: 2))
            .onTapGesture(perform: onTap)
    }
}
