import Foundation
import SwiftData

/// Everything the Money screen filters on. Kept as plain data so the matching
/// below stays a pure function over expenses.
struct ExpenseQuery: Equatable {

    enum Period: String, CaseIterable, Identifiable {
        case thisMonth, lastMonth, threeMonths, all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .thisMonth:   return "THIS MONTH"
            case .lastMonth:   return "LAST MONTH"
            case .threeMonths: return "3 MONTHS"
            case .all:         return "ALL TIME"
            }
        }
    }

    enum Kind: String, CaseIterable, Identifiable {
        case all, essential, discretionary, split, unsettled
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all:           return "EVERYTHING"
            case .essential:     return "ESSENTIAL"
            case .discretionary: return "DISCRETIONARY"
            case .split:         return "SPLIT"
            case .unsettled:     return "UNSETTLED"
            }
        }
    }

    enum Sort: String, CaseIterable, Identifiable {
        case newest, oldest, largest, smallest
        var id: String { rawValue }
        var label: String {
            switch self {
            case .newest:   return "NEWEST"
            case .oldest:   return "OLDEST"
            case .largest:  return "LARGEST"
            case .smallest: return "SMALLEST"
            }
        }
    }

    var search = ""
    var period: Period = .thisMonth
    var kind: Kind = .all
    var person: PersistentIdentifier?
    var sort: Sort = .newest

    /// How many filters are narrowing the list, for the badge on the Filter
    /// button. Period and sort are always set, so neither counts.
    var narrowingCount: Int {
        var n = 0
        if !search.trimmingCharacters(in: .whitespaces).isEmpty { n += 1 }
        if kind != .all { n += 1 }
        if person != nil { n += 1 }
        return n
    }
}

enum ExpenseFinder {

    static func run(
        _ expenses: [Expense],
        _ query: ExpenseQuery,
        now: Date = .now,
        calendar cal: Calendar = Ledger.calendar
    ) -> [Expense] {
        var results = expenses

        if let window = window(for: query.period, now: now, calendar: cal) {
            // Half-open, so an expense at midnight on the 1st lands in one month only.
            results = results.filter { $0.spentAt >= window.lowerBound && $0.spentAt < window.upperBound }
        }

        let needle = query.search.trimmingCharacters(in: .whitespaces).lowercased()
        if !needle.isEmpty {
            results = results.filter { $0.note.lowercased().contains(needle) }
        }

        switch query.kind {
        case .all:           break
        case .essential:     results = results.filter(\.isEssential)
        case .discretionary: results = results.filter { !$0.isEssential }
        case .split:         results = results.filter(\.isSplit)
        case .unsettled:     results = results.filter(hasOpenMoney)
        }

        if let person = query.person {
            results = results.filter { expense in
                expense.payer?.persistentModelID == person
                    || expense.shares.contains { $0.person?.persistentModelID == person }
            }
        }

        switch query.sort {
        case .newest:   return results.sorted { $0.spentAt > $1.spentAt }
        case .oldest:   return results.sorted { $0.spentAt < $1.spentAt }
        case .largest:  return results.sorted { $0.amountPaise > $1.amountPaise }
        case .smallest: return results.sorted { $0.amountPaise < $1.amountPaise }
        }
    }

    /// Money still moving in either direction on this expense.
    static func hasOpenMoney(_ expense: Expense) -> Bool {
        if expense.payer == nil {
            return expense.shares.contains(where: \.isOutstanding)
        }
        return expense.shares.contains { $0.person == nil && $0.settledAt == nil }
    }

    /// What these expenses cost *me* — my share, not the bills I fronted.
    static func totalPaise(_ expenses: [Expense]) -> Int {
        expenses.reduce(0) { $0 + $1.mySharePaise }
    }

    private static func window(
        for period: ExpenseQuery.Period,
        now: Date,
        calendar cal: Calendar
    ) -> Range<Date>? {
        guard let thisMonth = cal.dateInterval(of: .month, for: now) else { return nil }
        switch period {
        case .all:
            return nil
        case .thisMonth:
            return thisMonth.start..<thisMonth.end
        case .lastMonth:
            guard let back = cal.date(byAdding: .month, value: -1, to: thisMonth.start),
                  let last = cal.dateInterval(of: .month, for: back) else { return nil }
            return last.start..<last.end
        case .threeMonths:
            guard let back = cal.date(byAdding: .month, value: -2, to: thisMonth.start),
                  let first = cal.dateInterval(of: .month, for: back) else { return nil }
            return first.start..<thisMonth.end
        }
    }
}

/// Lets one chip builder render any of the filter enums.
protocol LabelledOption: Hashable, Identifiable {
    var label: String { get }
}

extension ExpenseQuery.Period: LabelledOption {}
extension ExpenseQuery.Kind: LabelledOption {}
extension ExpenseQuery.Sort: LabelledOption {}
