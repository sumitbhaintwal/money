import Foundation

/// One cell of the month grid. The grid *is* the app: a lit dot is a clean day,
/// a grey dot grows with what you spent, so a glance shows the fat days.
struct DayCell: Identifiable {
    enum State: Equatable {
        case blank                 // padding before the 1st / after the last
        case clean                 // nothing discretionary
        case spent(paise: Int)
        case future
    }
    let id: Int
    let date: Date?
    let dayNumber: Int?
    let state: State
}

enum Ledger {

    /// Weeks start Monday, which is how the design reads M T W T F S S.
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }

    /// A day is clean when nothing discretionary was logged.
    /// An empty day is clean, and so is a day of nothing but essentials.
    static func isClean(_ expenses: [Expense]) -> Bool {
        expenses.allSatisfy(\.isEssential)
    }

    static func byDay(_ expenses: [Expense], calendar cal: Calendar = calendar) -> [Date: [Expense]] {
        Dictionary(grouping: expenses) { cal.startOfDay(for: $0.spentAt) }
    }

    /// The run of clean days ending today. Breaks on the first day with
    /// discretionary spending; days before the first expense don't count.
    static func currentStreak(
        expenses: [Expense],
        asOf today: Date = .now,
        calendar cal: Calendar = calendar
    ) -> Int {
        let days = byDay(expenses, calendar: cal)
        guard let earliest = expenses.map({ cal.startOfDay(for: $0.spentAt) }).min() else { return 0 }

        var streak = 0
        var cursor = cal.startOfDay(for: today)
        while cursor >= earliest {
            guard isClean(days[cursor] ?? []) else { break }
            streak += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    static func monthGrid(
        containing month: Date,
        expenses: [Expense],
        today: Date = .now,
        calendar cal: Calendar = calendar
    ) -> [DayCell] {
        let startOfToday = cal.startOfDay(for: today)
        let days = byDay(expenses, calendar: cal)

        guard
            let interval = cal.dateInterval(of: .month, for: month),
            let dayCount = cal.range(of: .day, in: .month, for: month)?.count
        else { return [] }

        // How many blanks before the 1st, with Monday as column 0.
        let weekday = cal.component(.weekday, from: interval.start)
        let leading = (weekday - cal.firstWeekday + 7) % 7

        var cells: [DayCell] = (0..<leading).map {
            DayCell(id: $0, date: nil, dayNumber: nil, state: .blank)
        }

        // Nothing was recorded before the first expense, so those days are unknown
        // rather than clean — they get the same faint dot as days that haven't happened.
        let firstRecorded = expenses.map { cal.startOfDay(for: $0.spentAt) }.min()

        for day in 1...dayCount {
            guard let date = cal.date(byAdding: .day, value: day - 1, to: interval.start) else { continue }
            let state: DayCell.State
            if date > startOfToday {
                state = .future
            } else if let first = firstRecorded, date < first {
                state = .future
            } else if firstRecorded == nil {
                state = .future
            } else {
                let onDay = days[cal.startOfDay(for: date)] ?? []
                state = isClean(onDay)
                    ? .clean
                    : .spent(paise: onDay.reduce(0) { $0 + $1.mySharePaise })
            }
            cells.append(DayCell(id: cells.count, date: date, dayNumber: day, state: state))
        }

        // Pad the last row so the grid keeps its shape.
        while cells.count % 7 != 0 {
            cells.append(DayCell(id: cells.count, date: nil, dayNumber: nil, state: .blank))
        }
        return cells
    }

    /// The longest run of clean days on record.
    static func longestStreak(
        expenses: [Expense],
        asOf today: Date = .now,
        calendar cal: Calendar = calendar
    ) -> Int {
        let days = byDay(expenses, calendar: cal)
        guard let earliest = expenses.map({ cal.startOfDay(for: $0.spentAt) }).min() else { return 0 }

        var best = 0
        var run = 0
        var cursor = earliest
        let end = cal.startOfDay(for: today)
        while cursor <= end {
            if isClean(days[cursor] ?? []) {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return best
    }

    /// What I have actually spent this month — my share of every split, not the bills I fronted.
    static func monthSpendPaise(
        containing month: Date,
        expenses: [Expense],
        calendar cal: Calendar = calendar
    ) -> Int {
        guard let interval = cal.dateInterval(of: .month, for: month) else { return 0 }
        return expenses
            .filter { interval.contains($0.spentAt) }
            .reduce(0) { $0 + $1.mySharePaise }
    }

    /// Positive means people owe me on balance.
    static func netBalancePaise(_ expenses: [Expense]) -> Int {
        expenses.reduce(0) { running, expense in
            if expense.payer == nil {
                return running + expense.shares
                    .filter(\.isOutstanding)
                    .reduce(0) { $0 + $1.amountPaise }
            }
            guard let mine = expense.shares.first(where: { $0.person == nil }),
                  mine.settledAt == nil
            else { return running }
            return running - mine.amountPaise
        }
    }
}
