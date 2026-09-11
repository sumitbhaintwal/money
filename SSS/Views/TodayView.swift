import SwiftUI
import SwiftData

struct TodayView: View {
    let showPeople: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.spentAt, order: .reverse) private var expenses: [Expense]
    @State private var selectedDay: Date = Ledger.calendar.startOfDay(for: .now)
    @State private var visibleMonth: Date = Ledger.calendar.startOfDay(for: .now)
    @State private var showingDay = false
    @State private var showingSettings = false

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

            MonthGrid(cells: cells, selected: selectedDay) { day in
                selectedDay = day
                showingDay = true
            }
                .padding(.horizontal, 24)
                .padding(.top, 22)

            Spacer(minLength: 0)
        }
        .background(Theme.ground)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.sheet)
        }
        .sheet(isPresented: $showingDay) {
            DayDrawerView(date: selectedDay)
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
            HStack(spacing: 10) {
                settingsButton
                balancePill
            }
        }
    }

    private var settingsButton: some View {
        Button { showingSettings = true } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.secondary)
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
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

    // MARK: - Derived

    private var cells: [DayCell] {
        Ledger.monthGrid(containing: visibleMonth, expenses: expenses)
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

}
