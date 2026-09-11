import SwiftUI
import SwiftData

struct MoneyView: View {
    @Query(sort: \Expense.spentAt, order: .reverse) private var expenses: [Expense]
    @Query(sort: \Person.name) private var people: [Person]

    @State private var query = ExpenseQuery()
    @State private var editing: Expense?
    @FocusState private var searchFocused: Bool

    private var results: [Expense] { ExpenseFinder.run(expenses, query) }
    private var total: Int { ExpenseFinder.totalPaise(results) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, 24).padding(.top, 8)
            search.padding(.horizontal, 24).padding(.top, 18)
            chipRow(ExpenseQuery.Period.allCases, selected: query.period) { query.period = $0 }
                .padding(.top, 16)
            chipRow(ExpenseQuery.Kind.allCases, selected: query.kind) { query.kind = $0 }
                .padding(.top, 8)
            if !people.isEmpty { personRow.padding(.top, 8) }

            summary.padding(.horizontal, 24).padding(.top, 22)

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
            .scrollDismissesKeyboard(.immediately)
        }
        .background(Theme.ground)
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
            Menu {
                Picker("Sort", selection: $query.sort) {
                    ForEach(ExpenseQuery.Sort.allCases) { Text($0.label).tag($0) }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 12, weight: .semibold))
                    Label9(sortShort, color: Theme.ink, size: 12)
                }
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Sort order")
        }
        .frame(height: 44)
    }

    private var sortShort: String {
        switch query.sort {
        case .newest:   return "NEWEST"
        case .oldest:   return "OLDEST"
        case .largest:  return "LARGEST"
        case .smallest: return "SMALLEST"
        }
    }

    private var search: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.dim)
            TextField("search notes", text: $query.search)
                .font(Theme.F.display(18, .medium))
                .foregroundStyle(Theme.body)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !query.search.isEmpty {
                Button { query.search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.outline)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .frame(height: 46)
        .padding(.horizontal, 14)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    /// One scrolling row of glass chips per filter dimension.
    private func chipRow<T: LabelledOption>(
        _ options: [T],
        selected: T,
        choose: @escaping (T) -> Void
    ) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(options) { option in
                    Chip(title: option.label, isOn: option == selected) { choose(option) }
                }
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var personRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Chip(title: "ANYONE", isOn: query.person == nil) { query.person = nil }
                ForEach(people) { person in
                    Chip(
                        title: person.name.uppercased(),
                        isOn: query.person == person.persistentModelID
                    ) {
                        query.person = query.person == person.persistentModelID ? nil : person.persistentModelID
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline) {
            Label9(results.count == 1 ? "1 EXPENSE" : "\(results.count) EXPENSES", size: 13)
            Spacer()
            Text(Money.rupees(total))
                .font(.system(size: 21, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
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
                    if expense.isSplit {
                        Text("my share of \(Money.rupees(expense.amountPaise)), split \(expense.shares.count)")
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

/// Lets the chip rows render any of the filter enums.
protocol LabelledOption: Hashable, Identifiable {
    var label: String { get }
}
extension ExpenseQuery.Period: LabelledOption {}
extension ExpenseQuery.Kind: LabelledOption {}
