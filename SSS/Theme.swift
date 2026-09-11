import SwiftUI

/// One greyscale ramp, no hue. Black is the only "lit" value and it is
/// deliberately scarce: streak, clean days, primary actions, selected state.
enum Theme {
    static let ground      = Color(hex: 0xFFFFFF)   // root screens
    static let sheet       = Color(hex: 0xF4F4F4)   // modals, lifted off the root
    static let key         = Color(hex: 0xEAEAEA)   // keypad keys
    static let futureDot   = Color(hex: 0xE6E6E6)
    static let rowRule     = Color(hex: 0xE8E8E8)
    static let rule        = Color(hex: 0xD8D8D8)   // section rules
    static let outline     = Color(hex: 0xCFCFCF)   // box borders
    static let placeholder = Color(hex: 0xBDBDBD)   // dimmed amount
    static let spendDot    = Color(hex: 0x949494)   // held at 3:1 — it encodes amount
    static let dim         = Color(hex: 0x9E9E9E)
    static let muted       = Color(hex: 0x787878)   // small-caps labels
    static let secondary   = Color(hex: 0x5F5F5F)
    static let body        = Color(hex: 0x232323)
    static let ink         = Color(hex: 0x121212)   // primary text
    static let lit         = Color(hex: 0x000000)   // the accent
    static let onLit       = Color(hex: 0xFFFFFF)   // ink that sits on it

    /// Stand-ins for Barlow Condensed / IBM Plex Mono until the real faces are
    /// licensed and bundled. Roles are what matter: scores are condensed, money is mono.
    enum F {
        static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight).width(.condensed)
        }
        static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Uppercase tracked label used for every small-caps run in the app.
struct Label9: View {
    let text: String
    var color: Color = Theme.muted
    var size: CGFloat = 13

    init(_ text: String, color: Color = Theme.muted, size: CGFloat = 13) {
        self.text = text
        self.color = color
        self.size = size
    }
    var body: some View {
        Text(text)
            .font(Theme.F.display(size, .semibold))
            .tracking(size * 0.16)
            .foregroundStyle(color)
    }
}
