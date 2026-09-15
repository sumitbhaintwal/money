import SwiftUI
import SwiftData

struct MoneyView: View {
    @Query(filter: #Predicate<Expense> { $0.deletedAt == nil }, sort: \Expense.spentAt, order: .reverse)
    private var expenses: [Expense]
    @Query(filter: #Predicate<Person> { $0.removedAt == nil && $0.deletedAt == nil }, sort: \Person.name)
    private var people: [Person]
    @Query(filter: #Predicate<ExpenseGroup> { $0.deletedAt == nil }) private var allGroups: [ExpenseGroup]

    @State private var query = ExpenseQuery()
    @State private var editing: Expense?
    @State private var showingFilters = false
    // Opens tall so every group is reachable; drag down to medium to watch the
    // list update behind it, since the filters apply live.
    @State private var filterDetent: PresentationDetent = .large

    private var results: [Expense] { ExpenseFinder.run(expenses, query) }
    private var total: Int { ExpenseFinder.totalPaise(results) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, 24).padding(.top, 8)
            summary.padding(.horizontal, 24).padding(.top, 20)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if results.isEmpty { empty }
                    ForEach(results) { row($0) }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
        }
        .background(Theme.ground)
        .sheet(isPresented: $showingFilters) {
            FilterDrawer(query: $query, people: people, groups: Groups.sorted(allGroups))
                .presentationDetents([.medium, .large], selection: $filterDetent)
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.sheet)
        }
        .sheet(item: $editing) { expense in
            AddExpenseView(editing: expense)
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.sheet)
        }
    }

    // MARK: - Head

    private var header: some View {
        HStack {
            Label9("MONEY", size: 14)
            Spacer()
            Button { showingFilters = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Label9("FILTER", color: Theme.ink, size: 13)
                    if query.narrowingCount > 0 {
                        Text("\(query.narrowingCount)")
                            .font(.system(size: 11, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.onLit)
                            .frame(width: 18, height: 18)
                            .background(Theme.lit, in: .circle)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filters")
        }
        .frame(height: 44)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Label9(results.count == 1 ? "1 EXPENSE" : "\(results.count) EXPENSES", size: 13)
                Spacer()
                Text(Money.rupees(total))
                    .font(.system(size: 21, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            }
            // A filtered list that looks like the whole list is a trap, so the
            // active filters stay on screen even though the controls do not.
            Text(activeSummary)
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }

    private var activeSummary: String {
        var parts = [query.period.label]
        if query.kind != .all { parts.append(query.kind.label) }
        if let id = query.person, let person = people.first(where: { $0.persistentModelID == id }) {
            parts.append(person.name.uppercased())
        }
        if let id = query.group, let item = allGroups.first(where: { $0.persistentModelID == id }) {
            parts.append(item.name.uppercased())
        }
        let needle = query.search.trimmingCharacters(in: .whitespaces)
        if !needle.isEmpty { parts.append("“\(needle)”") }
        if query.sort != .newest { parts.append(query.sort.label) }
        return parts.joined(separator: " · ")
    }

    // MARK: - List

    private var empty: some View {
        Text(query.narrowingCount > 0 ? "Nothing matches those filters." : "Nothing recorded in this period.")
            .font(Theme.F.display(19, .medium))
            .foregroundStyle(Theme.dim)
            .padding(.top, 34)
    }

    private func row(_ expense: Expense) -> some View {
        Button { editing = expense } label: {
            HStack(alignment: .top, spacing: 14) {
                Label9(dayLabel(expense.spentAt), size: 11)
                    .frame(width: 52, alignment: .leading)
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(expense.note.isEmpty ? "—" : expense.note)
                            .font(Theme.F.display(19, .medium))
                            .foregroundStyle(expense.note.isEmpty ? Theme.dim : Theme.body)
                        if expense.isEssential { tag("ESSENTIAL") }
                        if ExpenseFinder.hasOpenMoney(expense) { tag("OPEN") }
                    }
                    if let detail = splitDetail(expense) {
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.dim)
                    }
                }
                Spacer(minLength: 8)
                Text(Money.rupees(expense.mySharePaise))
                    .font(.system(size: 16, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 2)
            }
            .frame(minHeight: 58)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rowRule).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }

    /// Why the number on the right is smaller than the bill that was paid.
    private func splitDetail(_ expense: Expense) -> String? {
        guard expense.isSplit else { return nil }
        if expense.excludesMe {
            return "\(Money.rupees(expense.amountPaise)) covered for \(expense.splitWays), none of it mine"
        }
        return "my share of \(Money.rupees(expense.amountPaise)), split \(expense.splitWays)"
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(Theme.F.display(10, .semibold))
            .tracking(1)
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(Rectangle().stroke(Theme.outline, lineWidth: 1))
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Ledger.calendar
        f.dateFormat = "d MMM"
        return f.string(from: date).uppercased()
    }
}
