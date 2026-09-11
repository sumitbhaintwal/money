import SwiftUI

struct Keypad: View {
    let onDigit: (String) -> Void
    let onBackspace: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        // One container so the keys share a glass sampling pass and read as a
        // single slab of material rather than twelve unrelated panes.
        GlassEffectContainer(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "00", "0"], id: \.self) { key in
                    keyCap {
                        Text(key)
                            .font(.system(size: 26))
                            .monospacedDigit()
                            .foregroundStyle(Theme.body)
                    } action: {
                        onDigit(key)
                    }
                }
                keyCap {
                    Image(systemName: "delete.left")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.secondary)
                } action: {
                    onBackspace()
                }
                .accessibilityLabel("Delete")
            }
        }
    }

    private func keyCap<Content: View>(
        @ViewBuilder content: () -> Content,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            content().frame(maxWidth: .infinity, minHeight: 62)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
}

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
