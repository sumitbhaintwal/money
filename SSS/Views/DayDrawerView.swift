import SwiftUI
import SwiftData

/// One day's expenses. Opens by tapping a day in the month grid, so the grid
/// itself can have the whole screen.
struct DayDrawerView: View {
    let date: Date

    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.spentAt, order: .reverse) private var expenses: [Expense]
    @State private var editing: Expense?

    private let cal = Ledger.calendar
    private var today: Date { cal.startOfDay(for: .now) }

    private var dayExpenses: [Expense] {
        expenses.filter { cal.isDate($0.spentAt, inSameDayAs: date) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            dayHeader.padding(.top, 24)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if dayExpenses.isEmpty {
                        Text(emptyText)
                            .font(Theme.F.display(19, .medium))
                            .foregroundStyle(Theme.dim)
                            .padding(.top, 28)
                    }
                    ForEach(dayExpenses) { row($0) }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            if !dayExpenses.isEmpty {
                Text("Tap to change one. Press and hold to delete it.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.dim)
                    .padding(.bottom, 26)
            }
        }
        .padding(.horizontal, 24)
        .background(Theme.sheet)
        // Hug the day's contents. A fixed medium detent left a quiet day
        // sitting in half a screen of nothing.
        .presentationDetents([.height(fittedHeight), .large])
        .sheet(item: $editing) { expense in
            AddExpenseView(editing: expense)
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.sheet)
        }
    }

    private var dayHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Label9(dayLabel, size: 14)
            Spacer()
            Text(totalText)
                .font(.system(size: 26, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(isClean ? Theme.lit : Theme.ink)
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }

    private func row(_ expense: Expense) -> some View {
        HStack(spacing: 9) {
            Text(expense.note.isEmpty ? "—" : expense.note)
                .font(Theme.F.display(19, .medium))
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
                .font(.system(size: 15))
                .monospacedDigit()
                .foregroundStyle(Theme.secondary)
        }
        .frame(height: 54)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rowRule).frame(height: 1) }
        .onTapGesture { editing = expense }
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive) {
                context.delete(expense)
                try? context.save()
            }
        }
    }

    // MARK: - Derived

    /// Chrome plus one row per expense, floored so an empty day still reads as
    /// a drawer and capped so a heavy one does not fill the screen.
    private var fittedHeight: CGFloat {
        let rows = CGFloat(max(dayExpenses.count, 1))
        return min(max(134 + rows * 54, 210), 620)
    }

    /// Days before the first expense are unknown, not virtuous.
    private var isUnrecorded: Bool {
        guard let first = expenses.map({ cal.startOfDay(for: $0.spentAt) }).min() else { return true }
        return cal.startOfDay(for: date) < first
    }

    private var isClean: Bool {
        date <= today && !isUnrecorded && Ledger.isClean(dayExpenses)
    }

    private var totalText: String {
        if date > today || isUnrecorded { return "—" }
        return Money.rupees(dayExpenses.reduce(0) { $0 + $1.mySharePaise })
    }

    private var emptyText: String {
        if date > today { return "not yet" }
        return isUnrecorded ? "nothing recorded" : "clean day"
    }

    private var dayLabel: String {
        let f = DateFormatter()
        f.calendar = cal
        f.dateFormat = "MMM d"
        let base = f.string(from: date).uppercased()
        return cal.isDateInToday(date) ? "\(base) · TODAY" : base
    }

    private func tag(for expense: Expense) -> String? {
        if expense.isSplit { return "SPLIT \(expense.shares.count)" }
        if expense.isEssential { return "ESSENTIAL" }
        return nil
    }
}
