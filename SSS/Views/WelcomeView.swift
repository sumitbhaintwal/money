import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            motif.padding(.bottom, 44)

            Text("Spending is\na habit.")
                .font(Theme.F.display(46, .bold))
                .foregroundStyle(Theme.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("Log what you spend, split what you share, and see where the month actually went.")
                .font(Theme.F.display(19, .medium))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)

            Spacer(minLength: 0)

            Button(action: onStart) {
                Text("GET STARTED")
                    .font(Theme.F.display(19, .bold)).tracking(3)
                    .frame(maxWidth: .infinity, minHeight: 58)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.lit)

            Text("Your ledger stays on this phone.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .padding(.bottom, 28)
        }
        .padding(.horizontal, 28)
        .background(Theme.ground)
    }

    /// The month grid, stripped to nine days — the same mark as the app icon.
    private var motif: some View {
        let dots: [[(Color, CGFloat)]] = [
            [(Theme.spendDot, 13), (Theme.lit, 17), (Theme.spendDot, 24)],
            [(Theme.lit, 17), (Theme.lit, 17), (Theme.spendDot, 15)],
            [(Theme.lit, 17), (Theme.lit, 17), (Theme.lit, 17)],
        ]
        return VStack(alignment: .leading, spacing: 18) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 18) {
                    ForEach(0..<3, id: \.self) { col in
                        let (colour, size) = dots[row][col]
                        Circle().fill(colour).frame(width: size, height: size)
                    }
                }
            }
        }
    }
}
