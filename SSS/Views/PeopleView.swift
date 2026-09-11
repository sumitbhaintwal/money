import SwiftUI
import SwiftData

struct PeopleView: View {
    @Query(sort: \Expense.spentAt, order: .reverse) private var expenses: [Expense]
    @State private var settling: PersonBalance?

    private var balances: [PersonBalance] { Balances.all(in: expenses) }
    private var owedToMe: [PersonBalance] { balances.filter(\.theyOweMe) }
    private var iOwe: [PersonBalance] { balances.filter { !$0.theyOweMe } }
    private var net: Int { balances.reduce(0) { $0 + $1.paise } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, 24).padding(.top, 8)
            headline.padding(.horizontal, 24).padding(.top, 34)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if balances.isEmpty {
                        Text("Nobody owes anybody.")
                            .font(Theme.F.display(20, .medium))
                            .foregroundStyle(Theme.dim)
                            .padding(.top, 44)
                    }
                    section("OWED TO YOU", owedToMe, tint: Theme.ink)
                    section("YOU OWE", iOwe, tint: Theme.secondary)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .padding(.top, 34)

            Text("Balances live on this phone. Nobody else needs the app — remind sends a message, pay opens UPI.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
        }
        .background(Theme.ground)
        .sheet(item: $settling) { balance in
            SettleView(balance: balance)
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.sheet)
        }
    }

    private var header: some View {
        HStack {
            Label9("PEOPLE", size: 14)
            Spacer()
        }
        .frame(height: 44)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Money.signedRupees(net))
                .font(.system(size: 52, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Label9(balances.isEmpty ? "ALL SQUARE" : "NET, ACROSS \(balances.count) PEOPLE", size: 14)
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ rows: [PersonBalance], tint: Color) -> some View {
        if !rows.isEmpty {
            Label9(title, size: 13).padding(.top, 26).padding(.bottom, 6)
            ForEach(rows) { balance in
                Button { settling = balance } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Rectangle().stroke(Theme.outline, lineWidth: 1).frame(width: 34, height: 34)
                            Text(balance.person.initial)
                                .font(Theme.F.display(16, .semibold))
                                .foregroundStyle(Theme.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(balance.person.name)
                                .font(Theme.F.display(21, .medium))
                                .foregroundStyle(Theme.body)
                            Text(balance.reason)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.dim)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(Money.rupees(abs(balance.paise)))
                            .font(.system(size: 19, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(tint)
                    }
                    .frame(height: 64)
                    .contentShape(Rectangle())
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.rowRule).frame(height: 1) }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
