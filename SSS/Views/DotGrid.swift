import SwiftUI

struct DotGrid: View {
    let cells: [DayCell]
    let selected: Date?
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    /// Spend dots scale with the amount, against the month's own biggest day.
    /// The ₹1,000 floor stops a quiet month inflating a small expense into a blob.
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

        // Layered, not stacked — but offset rather than concentric. Dead centre
        // put the dot in the gap between two digits, so 12 read as "1·2", and
        // it swallowed single digits whole. Overlapping the numeral's top edge
        // keeps both legible.
        ZStack {
            Text(cell.dayNumber.map(String.init) ?? "")
                .font(.system(size: 26, weight: isToday ? .medium : .regular))
                .monospacedDigit()
                .foregroundStyle(numberColour(cell, isToday: isToday))
                .offset(y: 9)
            dot(for: cell.state)
                .offset(y: -7)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .contentShape(Rectangle())
        .overlay {
            if isSelected {
                Rectangle().strokeBorder(Theme.lit, lineWidth: 1)
            }
        }
        .onTapGesture {
            if let date = cell.date { onSelect(date) }
        }
        .accessibilityLabel(accessibilityLabel(for: cell))
    }

    /// Light enough to sit under a dot without fighting it. Today steps
    /// forward slightly, since nothing else marks it once the selection moves.
    private func numberColour(_ cell: DayCell, isToday: Bool) -> Color {
        if isToday { return Theme.dim }
        switch cell.state {
        case .blank:            return .clear
        case .future:           return Theme.futureDot
        case .clean, .spent:    return Theme.outline
        }
    }

    @ViewBuilder
    private func dot(for state: DayCell.State) -> some View {
        switch state {
        case .blank:
            Color.clear.frame(width: 0, height: 0)
        case .clean:
            Circle().fill(Theme.lit).frame(width: 13, height: 13)
        case .future:
            Circle().fill(Theme.futureDot).frame(width: 4, height: 4)
        case let .spent(paise):
            let ratio = min(1, Double(paise) / Double(referencePaise))
            let size = 8 + 22 * ratio
            Circle().fill(Theme.spendDot).frame(width: size, height: size)
        }
    }

    private func accessibilityLabel(for cell: DayCell) -> String {
        guard let day = cell.dayNumber else { return "" }
        switch cell.state {
        case .clean:               return "Day \(day), clean"
        case let .spent(paise):    return "Day \(day), spent \(Money.rupees(paise))"
        case .future:              return "Day \(day), not yet"
        case .blank:               return ""
        }
    }
}
