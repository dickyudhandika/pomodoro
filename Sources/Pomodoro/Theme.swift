import SwiftUI

// MARK: - Color helpers

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double(int         & 0xFF) / 255
        )
    }
}

// MARK: - shadcn design tokens (oklch → hex approximations)

struct ShadTheme {
    let background: Color  // --background
    let foreground: Color  // --foreground
    let card:       Color  // --card
    let border:     Color  // --border
    let muted:      Color  // --muted
    let mutedFg:    Color  // --muted-foreground
    let primary:    Color  // --primary
    let primaryFg:  Color  // --primary-foreground

    // Light: oklch(1 0 0) bg, oklch(0.145 0 0) fg, oklch(0.922 0 0) border
    static let light = ShadTheme(
        background: Color(hex: "FFFFFF"),
        foreground: Color(hex: "252626"),
        card:       Color(hex: "FFFFFF"),
        border:     Color(hex: "E8E8E8"),
        muted:      Color(hex: "F5F5F5"),
        mutedFg:    Color(hex: "8E8F91"),
        primary:    Color(hex: "252626"),
        primaryFg:  Color(hex: "FAFAFA")
    )

    // Dark: oklch(0.145 0 0) bg, oklch(0.985 0 0) fg, oklch(1 0 0 / 10%) border
    static let dark = ShadTheme(
        background: Color(hex: "252626"),
        foreground: Color(hex: "FAFAFA"),
        card:       Color(hex: "353637"),
        border:     Color(white: 1, opacity: 0.10),
        muted:      Color(hex: "414243"),
        mutedFg:    Color(hex: "A1A1AA"),
        primary:    Color(hex: "E8E8E8"),
        primaryFg:  Color(hex: "353637")
    )
}

// MARK: - Phase accent colors

extension Phase {
    var accent: Color {
        switch self {
        case .work:       return Color(hex: "E84C3D")
        case .shortBreak: return Color(hex: "40B87C")
        case .longBreak:  return Color(hex: "4080EB")
        }
    }
}
