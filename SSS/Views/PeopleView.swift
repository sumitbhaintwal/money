import SwiftUI
import SwiftData

struct PeopleView: View {
    @Query(filter: #Predicate<Expense> { $0.deletedAt == nil }, sort: \Expense.spentAt, order: .reverse)
    private var expenses: [Expense]
    @Query(filter: #Predicate<ExpenseGroup> { $0.deletedAt == nil }) private var allGroups: [ExpenseGroup]
    @State private var settling: PersonBalance?
    @State private var managing = false
    @State private var creatingGroup = false
    @State private var openGroup: ExpenseGroup?

    private var groups: [ExpenseGroup] { Groups.sorted(allGroups) }

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
                    if balances.isEmpty && groups.isEmpty {
                        Text("Nobody owes anybody.")
                            .font(Theme.F.display(20, .medium))
                            .foregroundStyle(Theme.dim)
                            .padding(.top, 44)
                    }
                    groupsSection
                    section("OWED TO YOU", owedToMe, tint: Theme.ink)
                    section("YOU OWE", iOwe, tint: Theme.secondary)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .padding(.top, 34)

            Text("Balances live in your account, on every phone you sign into. Nobody else needs the app — remind sends a message, pay opens UPI.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
        }
        .background(Theme.ground)
        .sheet(isPresented: $creatingGroup) { GroupEditorView(group: nil) }
        .sheet(item: $openGroup) { GroupDetailView(group: $0) }
        .sheet(isPresented: $managing) {
            PeopleManagerView()
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.sheet)
        }
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
            Button { managing = true } label: {
                Label9("MANAGE", color: Theme.ink, size: 13)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
    private var groupsSection: some View {
        HStack {
            Label9("GROUPS", size: 13)
            Spacer()
            Button { creatingGroup = true } label: {
                Label9("+ NEW", color: Theme.ink, size: 13)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)

        if groups.isEmpty {
            Text("A group keeps a trip or a flat together, and pre-picks who splits it.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
        }

        ForEach(groups) { group in
            Button { openGroup = group } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(Theme.F.display(21, .medium))
                            .foregroundStyle(group.isOpen ? Theme.body : Theme.dim)
                        Text(groupSubtitle(group))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.dim)
                    }
                    Spacer()
                    Text(Money.rupees(Groups.totalPaise(group)))
                        .font(.system(size: 17, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(group.isOpen ? Theme.ink : Theme.dim)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.outline)
                }
                .frame(height: 62)
                .contentShape(Rectangle())
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.rowRule).frame(height: 1) }
            }
            .buttonStyle(.plain)
        }
    }

    private func groupSubtitle(_ group: ExpenseGroup) -> String {
        let people = group.members.count == 1 ? "1 person" : "\(group.members.count) people"
        let net = Groups.netPaise(in: group)
        let closed = group.isOpen ? "" : "closed · "
        if net == 0 { return "\(closed)\(people) · settled up" }
        return net > 0
            ? "\(closed)\(people) · you're owed \(Money.rupees(net))"
            : "\(closed)\(people) · you owe \(Money.rupees(-net))"
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
