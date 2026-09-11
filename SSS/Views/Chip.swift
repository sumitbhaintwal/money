import SwiftUI

/// A toggle chip. On is a black-tinted glass rather than a flat fill, so the
/// pressed state still reads as the same material.
struct Chip: View {
    let title: String
    let isOn: Bool
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(Theme.F.display(15, .semibold))
                    .tracking(2.1)
            }
            .foregroundStyle(isOn ? Theme.onLit : Theme.secondary)
            .frame(height: 44)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isOn ? .regular.tint(Theme.lit).interactive() : .regular.interactive(),
            in: .rect(cornerRadius: 12)
        )
    }
}
