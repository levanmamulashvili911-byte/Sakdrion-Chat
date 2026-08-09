import SwiftUI
import UIKit

// MARK: - Color helpers

extension Color {
    /// Creates a dynamic color from two hex values, one per interface style.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
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

// MARK: - Palette

/// The app's colour tokens. Light-first: soft neutrals, one calm accent,
/// and only as much contrast as a value actually needs.
enum Palette {
    static let background = Color(light: 0xF5F7FA, dark: 0x0F1216)
    static let surface = Color(light: 0xFFFFFF, dark: 0x171B21)
    static let surfaceSunken = Color(light: 0xEFF2F6, dark: 0x1E232A)
    static let separator = Color(light: 0xE6EAF0, dark: 0x262C34)

    static let textPrimary = Color(light: 0x11161D, dark: 0xF2F5F9)
    static let textSecondary = Color(light: 0x6B7480, dark: 0x99A2AE)
    static let textTertiary = Color(light: 0x9AA2AD, dark: 0x6D7783)

    static let accent = Color(light: 0x2F6BF0, dark: 0x5B8CFF)
    static let accentSoft = Color(light: 0xE8EFFE, dark: 0x1C2740)
    static let accentPressed = Color(light: 0x2557C7, dark: 0x7BA2FF)

    static let bubbleIncoming = Color(light: 0xFFFFFF, dark: 0x1E242C)
    static let bubbleOutgoing = Color(light: 0x2F6BF0, dark: 0x3F72E8)
    static let bubbleIncomingText = Color(light: 0x11161D, dark: 0xF2F5F9)
    static let bubbleOutgoingText = Color(light: 0xFFFFFF, dark: 0xFFFFFF)

    static let success = Color(light: 0x1FAF6A, dark: 0x35C98A)
    static let danger = Color(light: 0xE0453C, dark: 0xFF6B63)
    static let warning = Color(light: 0xE9A23B, dark: 0xFFBC5C)

    /// Deterministic, soft avatar tints. Index with `Palette.avatarTints[seed % count]`.
    static let avatarTints: [Color] = [
        Color(light: 0xDCE8FF, dark: 0x27354F),
        Color(light: 0xDCF5EC, dark: 0x1F3F36),
        Color(light: 0xFBE7E4, dark: 0x462C2A),
        Color(light: 0xF1E7FB, dark: 0x372B4A),
        Color(light: 0xFDF0D9, dark: 0x43371F),
        Color(light: 0xDFF1F7, dark: 0x1F3A44)
    ]

    static let avatarInk: [Color] = [
        Color(light: 0x2F5FCB, dark: 0xA9C3FF),
        Color(light: 0x1B8262, dark: 0x86E0C0),
        Color(light: 0xBE5348, dark: 0xFFAFA6),
        Color(light: 0x7B52B8, dark: 0xD3B9FF),
        Color(light: 0xB0801F, dark: 0xFFD68F),
        Color(light: 0x2A7791, dark: 0x9BD9EC)
    ]

    /// Maps any integer (including `Int.min`, which `abs` can't handle) into the
    /// tint range.
    static func tintIndex(_ seed: Int) -> Int {
        let count = avatarTints.count
        return ((seed % count) + count) % count
    }

    static func tintIndex(for text: String) -> Int {
        tintIndex(text.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 100_003 })
    }
}

// MARK: - Metrics

enum Metrics {
    static let cornerSmall: CGFloat = 10
    static let cornerMedium: CGFloat = 16
    static let cornerLarge: CGFloat = 22
    static let bubbleCorner: CGFloat = 20

    static let rowHeight: CGFloat = 72
    static let avatarSmall: CGFloat = 34
    static let avatarMedium: CGFloat = 52
    static let avatarLarge: CGFloat = 96

    static let hPadding: CGFloat = 16
}

// MARK: - Typography

extension Font {
    static let sakTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let sakHeadline = Font.system(size: 17, weight: .semibold)
    static let sakBody = Font.system(size: 16, weight: .regular)
    static let sakMessage = Font.system(size: 16.5, weight: .regular)
    static let sakSubhead = Font.system(size: 15, weight: .regular)
    static let sakCaption = Font.system(size: 13, weight: .regular)
    static let sakMicro = Font.system(size: 11, weight: .medium)
}

// MARK: - Haptics

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
