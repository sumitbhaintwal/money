import SwiftUI

struct MonthGrid: View {
    let cells: [DayCell]
    let selected: Date?
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(Theme.F.display(12, .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.dim)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(cells) { cell in
                    cellView(cell)
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: DayCell) -> some View {
        let isSelected = cell.date.map { Ledger.calendar.isDate($0, inSameDayAs: selected ?? .distantPast) } ?? false
        let isToday = cell.date.map { Ledger.calendar.isDateInToday($0) } ?? false

        VStack(spacing: 2) {
            // Clean days are the streak, so they stay black and bold even when
            // essentials were bought — the amount and the streak are separate
            // facts about a day, and only one of them is the number.
            Text(amountText(cell.state))
                .font(.system(size: 12, weight: isCleanDay(cell.state) ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(amountColour(cell.state))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: 18)

            Text(cell.dayNumber.map(String.init) ?? "")
                .font(.system(size: 10, weight: isToday ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(numberColour(cell, isToday: isToday))
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Theme.selection)
                    .padding(.horizontal, 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let date = cell.date { onSelect(date) }
        }
        .accessibilityLabel(accessibilityLabel(for: cell))
    }

    // MARK: - Styling

    private func amountText(_ state: DayCell.State) -> String {
        switch state {
        case .blank, .future:                       return ""
        case let .clean(paise), let .spent(paise):  return Money.compact(paise)
        }
    }

    private func isCleanDay(_ state: DayCell.State) -> Bool {
        if case .clean = state { return true }
        return false
    }

    private func amountColour(_ state: DayCell.State) -> Color {
        switch state {
        case .blank, .future: return .clear
        case .clean:          return Theme.ink
        case .spent:          return Theme.muted
        }
    }

    private func numberColour(_ cell: DayCell, isToday: Bool) -> Color {
        if isToday { return Theme.body }
        switch cell.state {
        case .blank:            return .clear
        case .future:           return Theme.outline
        case .clean, .spent:    return Theme.dim
        }
    }

    private func accessibilityLabel(for cell: DayCell) -> String {
        guard let day = cell.dayNumber else { return "" }
        switch cell.state {
        case let .clean(paise):
            return paise == 0
                ? "Day \(day), clean, nothing spent"
                : "Day \(day), clean, \(Money.rupees(paise)) on essentials"
        case let .spent(paise): return "Day \(day), spent \(Money.rupees(paise))"
        case .future:           return "Day \(day), not yet"
        case .blank:            return ""
        }
    }
}
