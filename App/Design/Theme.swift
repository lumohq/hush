import SwiftUI
import UIKit

/// Hush's design tokens. 60/30/10: lavender-white base, ink text, violet
/// accent; mint for success and coral for "noise", used sparingly.
enum Theme {
    // Accent: white text on #6C4DF6 is 5.2:1.
    static let primary = Color(light: 0x6C4DF6, dark: 0x8B73FF)
    static let primaryShade = Color(light: 0x4E31D6, dark: 0x6A52E8)
    static let success = Color(light: 0x1DB989, dark: 0x2ED3A0)
    static let successShade = Color(light: 0x14936C, dark: 0x1FA87D)
    static let warning = Color(light: 0xFF9F1C, dark: 0xFFB347)
    static let warningShade = Color(light: 0xD97F06, dark: 0xD9922E)
    static let noise = Color(light: 0xFF5A5F, dark: 0xFF7377)

    static let background = Color(light: 0xF6F4FF, dark: 0x120F24)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1E1A38)
    static let border = Color(light: 0xE4DEFF, dark: 0x332D5C)
    static let borderShade = Color(light: 0xCFC6F5, dark: 0x262147)
    // Secondary text is ink at 70%: about 6:1 on the background.
    static let text = Color(light: 0x1C1838, dark: 0xF3F0FF)
    static let secondaryText = text.opacity(0.7)

    static let cornerRadius: CGFloat = 16
    /// Height of the "lip" under chunky buttons and cards.
    static let lip: CGFloat = 4
}

/// Four sizes, two weights, one family (SF Rounded). All follow Dynamic Type.
extension Font {
    static let hushTitle = Font.system(.title, design: .rounded, weight: .bold)
    static let hushHeadline = Font.system(.title3, design: .rounded, weight: .bold)
    static let hushBody = Font.system(.body, design: .rounded, weight: .medium)
    static let hushBodyBold = Font.system(.body, design: .rounded, weight: .bold)
    static let hushCaption = Font.system(.footnote, design: .rounded, weight: .medium)
}

extension Int {
    /// "1 rule", "43,917 rules".
    func counted(_ singular: String, _ plural: String? = nil) -> String {
        "\(formatted()) \(self == 1 ? singular : plural ?? singular + "s")"
    }
}

enum Haptics {
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func pop() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

extension Color {
    init(hex: UInt32) {
        self.init(UIColor(hex: hex))
    }

    /// A colour that switches with the light/dark appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension View {
    /// Themed background for the system-styled list screens.
    func hushListBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
    }
}
