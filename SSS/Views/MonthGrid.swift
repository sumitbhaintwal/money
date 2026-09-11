import SwiftUI

struct MonthGrid: View {
    let cells: [DayCell]
    let selected: Date?
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    /// Colour intensity is scaled against the month's own biggest day, with a
    /// ₹1,000 floor so a quiet month does not paint a small expense as severe.
    private var referencePaise: Int {
        let biggest = cells.compactMap { cell -> Int? in
            if case let .spent(paise) = cell.state { return paise }
            return nil
        }.max() ?? 0
        return max(biggest, 100_000)
    }

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
                // 14, not 16: "0.38k" is five glyphs and at 16pt it filled the whole
                // 46pt column, so neighbouring days ran together.
                .font(.system(size: 14, weight: isCleanDay(cell.state) ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(amountColour(cell.state))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(height: 20)

            Text(cell.dayNumber.map(String.init) ?? "")
                .font(.system(size: 9, weight: isToday ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(numberColour(cell, isToday: isToday))
        }
        .frame(maxWidth: .infinity, minHeight: 46)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Theme.selection)
                    .padding(.horizontal, 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if canOpen(cell), let date = cell.date { onSelect(date) }
        }
        .accessibilityLabel(accessibilityLabel(for: cell))
        .accessibilityAddTraits(canOpen(cell) ? .isButton : [])
    }

    /// A day that has not happened has nothing to show. Gated on the date
    /// rather than the cell state, because `.future` also covers past days
    /// from before the first expense — those are empty, but they are real and
    /// still open.
    private func canOpen(_ cell: DayCell) -> Bool {
        guard let date = cell.date else { return false }
        return date <= Ledger.calendar.startOfDay(for: .now)
    }

    // MARK: - Styling

    private func amountText(_ state: DayCell.State) -> String {
        switch state {
        case .blank, .future:  return ""
        case let .clean(paise):
            // Nothing went out at all — a dash is quieter than 0.00k, and four
            // of those in a row was a lot of ink for an empty day.
            return paise == 0 ? "–" : Money.compact(paise)
        case let .spent(paise): return Money.compact(paise)
        }
    }

    private func isCleanDay(_ state: DayCell.State) -> Bool {
        if case .clean = state { return true }
        return false
    }

    private func amountColour(_ state: DayCell.State) -> Color {
        switch state {
        case .blank, .future:   return .clear
        case .clean:            return Theme.clean
        case let .spent(paise): return spendColour(paise)
        }
    }

    /// Low to high across the month, so a heavy day is visible before it is read
    /// — the job dot size used to do.
    private func spendColour(_ paise: Int) -> Color {
        let t = min(1, Double(paise) / Double(referencePaise))
        func mix(_ from: Double, _ to: Double) -> Double { from + (to - from) * t }
        return Color(
            .sRGB,
            red:   mix(0xB5 / 255, 0xA3 / 255),
            green: mix(0x78 / 255, 0x3A / 255),
            blue:  mix(0x3A / 255, 0x1E / 255),
            opacity: 1
        )
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
