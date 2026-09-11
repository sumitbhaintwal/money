import SwiftUI
import SwiftData

struct TodayView: View {
    let showPeople: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.spentAt, order: .reverse) private var expenses: [Expense]
    @State private var selectedDay: Date = Ledger.calendar.startOfDay(for: .now)
    @State private var visibleMonth: Date = Ledger.calendar.startOfDay(for: .now)
    @State private var editingExpense: Expense?

    private let cal = Ledger.calendar
    private var today: Date { cal.startOfDay(for: .now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 8)

            monthRow
                .padding(.horizontal, 24)
                .padding(.top, 40)

            DotGrid(cells: cells, selected: selectedDay) { selectedDay = $0 }
                .padding(.horizontal, 24)
                .padding(.top, 22)

            selectedHeader
                .padding(.horizontal, 24)
                .padding(.top, 30)

            ScrollView {
                entries
                    .padding(.horizontal, 24)
                    // so the last row can clear the floating accessory
                    .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(Theme.ground)
        .sheet(item: $editingExpense) { expense in
            AddExpenseView(editing: expense)
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.sheet)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Ledger.currentStreak(expenses: expenses))")
                    .font(Theme.F.display(68, .bold))
                    .foregroundStyle(Theme.lit)
                Label9("DAY STREAK · BEST \(Ledger.longestStreak(expenses: expenses))", size: 14)
            }
            Spacer()
            balancePill
        }
    }

    private var balancePill: some View {
        Button { showPeople() } label: {
        HStack(spacing: 9) {
            Text(Money.signedRupees(Ledger.netBalancePaise(expenses)))
                .font(.system(size: 15, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.dim)
        }
        .frame(height: 44)
        .padding(.horizontal, 15)
        .glassEffect(.regular.interactive(), in: .capsule)
        .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("People and balances")
    }

    private var monthRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            stepper(-1, "chevron.left", enabled: true)
            Label9(monthName.uppercased(), color: Theme.ink, size: 19)
            stepper(1, "chevron.right", enabled: canGoForward)
            Spacer()
            Text(monthSpendLabel)
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
        }
    }

    private func stepper(_ delta: Int, _ symbol: String, enabled: Bool) -> some View {
        Button { step(delta) } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(enabled ? Theme.muted : Theme.outline)
                .frame(width: 30, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(delta < 0 ? "Previous month" : "Next month")
    }

    /// Nothing has happened in the future, so there is nothing to page to.
    private var canGoForward: Bool {
        guard let next = cal.date(byAdding: .month, value: 1, to: visibleMonth) else { return false }
        return next <= today
    }

    private func step(_ delta: Int) {
        guard let moved = cal.date(byAdding: .month, value: delta, to: visibleMonth) else { return }
        visibleMonth = moved
        // Land on today when paging back into this month, otherwise the 1st.
        if cal.isDate(moved, equalTo: today, toGranularity: .month) {
            selectedDay = today
        } else if let interval = cal.dateInterval(of: .month, for: moved) {
            selectedDay = cal.startOfDay(for: interval.start)
        }
    }

    private var selectedHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Label9(selectedLabel, size: 14)
            Spacer()
            Text(selectedTotalText)
                .font(.system(size: 21, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(selectedIsClean ? Theme.lit : Theme.ink)
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.rule).frame(height: 1)
        }
    }

    @ViewBuilder
    private var entries: some View {
        if selectedExpenses.isEmpty {
            Text(emptyDayText)
                .font(Theme.F.display(18, .medium))
                .foregroundStyle(Theme.dim)
                .frame(height: 50, alignment: .leading)
        } else {
            ForEach(selectedExpenses) { expense in
                HStack(spacing: 9) {
                    Text(expense.note.isEmpty ? "—" : expense.note)
                        .font(Theme.F.display(18, .medium))
                        .foregroundStyle(expense.note.isEmpty ? Theme.dim : Theme.body)
                    if let tag = tag(for: expense) {
                        Text(tag)
                            .font(Theme.F.display(11, .semibold))
                            .tracking(1.1)
                            .foregroundStyle(Theme.muted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .overlay(Rectangle().stroke(Theme.outline, lineWidth: 1))
                    }
                    Spacer()
                    Text(Money.rupees(expense.mySharePaise))
                        .font(.system(size: 14))
                        .monospacedDigit()
                        .foregroundStyle(Theme.secondary)
                }
                .frame(height: 50)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.rowRule).frame(height: 1)
                }
                .contentShape(Rectangle())
                .onTapGesture { editingExpense = expense }
                .contextMenu {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        delete(expense)
                    }
                }
            }
        }
    }

    // MARK: - Derived

    private var cells: [DayCell] {
        Ledger.monthGrid(containing: visibleMonth, expenses: expenses)
    }

    private var selectedExpenses: [Expense] {
        expenses.filter { cal.isDate($0.spentAt, inSameDayAs: selectedDay) }
    }

    /// Days before the first expense are unknown, not virtuous — the grid
    /// already draws them faint, so the panel must not call them clean.
    private var selectedIsUnrecorded: Bool {
        guard let first = expenses.map({ cal.startOfDay(for: $0.spentAt) }).min() else { return true }
        return selectedDay < first
    }

    private var selectedIsClean: Bool {
        selectedDay <= today && !selectedIsUnrecorded && Ledger.isClean(selectedExpenses)
    }

    private var selectedTotalText: String {
        if selectedDay > today || selectedIsUnrecorded { return "—" }
        return Money.rupees(selectedExpenses.reduce(0) { $0 + $1.mySharePaise })
    }

    private var emptyDayText: String {
        if selectedDay > today { return "not yet" }
        return selectedIsUnrecorded ? "nothing recorded" : "clean day"
    }

    private var monthName: String {
        let f = DateFormatter()
        f.calendar = cal
        // Only spell out the year once you have paged out of this one.
        f.dateFormat = cal.isDate(visibleMonth, equalTo: today, toGranularity: .year) ? "LLLL" : "LLLL yyyy"
        return f.string(from: visibleMonth)
    }

    private var monthSpendLabel: String {
        let total = Money.rupees(Ledger.monthSpendPaise(containing: visibleMonth, expenses: expenses))
        let isThisMonth = cal.isDate(visibleMonth, equalTo: today, toGranularity: .month)
        return isThisMonth ? "\(total) so far" : "\(total) in total"
    }

    private var selectedLabel: String {
        let f = DateFormatter()
        f.calendar = cal
        f.dateFormat = "MMM d"
        let base = f.string(from: selectedDay).uppercased()
        return cal.isDateInToday(selectedDay) ? "\(base) · TODAY" : base
    }

    private func delete(_ expense: Expense) {
        context.delete(expense)
        try? context.save()
    }

    private func tag(for expense: Expense) -> String? {
        if expense.isSplit { return "SPLIT \(expense.shares.count)" }
        if expense.isEssential { return "ESSENTIAL" }
        return nil
    }
}
