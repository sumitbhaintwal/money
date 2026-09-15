import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// A trip's books, in two shapes: a plain-text summary you paste into the group
/// chat, and a CSV for anyone who wants it in a spreadsheet. Nobody else runs
/// this app, so the export *is* the sharing — it has to read correctly to
/// someone who has never seen the screen it came from.
enum GroupExport {

    // MARK: - Text

    static func summary(_ group: ExpenseGroup) -> String {
        var lines: [String] = []

        lines.append(group.name)
        lines.append(subtitle(group))
        lines.append("")

        let balances = Groups.settlement(in: group)
        if balances.isEmpty {
            lines.append("Everyone is settled up.")
        } else {
            lines.append("WHO OWES WHAT")
            for balance in balances {
                lines.append(standing(balance))
            }
        }

        let expenses = ordered(group)
        if !expenses.isEmpty {
            lines.append("")
            lines.append("EXPENSES")
            for expense in expenses {
                lines.append(headline(expense))
                if let split = splitLine(expense) { lines.append("   \(split)") }
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Written for whoever is reading it in the group chat, so it names both
    /// sides rather than assuming the reader is me.
    private static func standing(_ balance: GroupBalance) -> String {
        let amount = Money.rupees(abs(balance.paise))
        if balance.isMine {
            return balance.isOwed ? "You are owed \(amount)" : "You owe \(amount)"
        }
        return balance.isOwed ? "\(balance.name) is owed \(amount)" : "\(balance.name) owes \(amount)"
    }

    private static func subtitle(_ group: ExpenseGroup) -> String {
        var parts = ["\(group.members.count) \(group.members.count == 1 ? "person" : "people")"]
        parts.append("\(Money.rupees(Groups.totalPaise(group))) total")
        parts.append("your share \(Money.rupees(Groups.mySharePaise(group)))")
        if !group.isOpen { parts.append("closed") }
        return parts.joined(separator: " · ")
    }

    private static func headline(_ expense: Expense) -> String {
        let note = expense.note.isEmpty ? "unlabelled" : expense.note
        let payer = expense.payer.map { "\($0.name) paid" } ?? "you paid"
        return "\(dayLabel(expense.spentAt)) — \(note) — \(Money.rupees(expense.amountPaise)) (\(payer))"
    }

    /// "You ₹500 · Ravi ₹500 (paid) · Meera ₹500". Nil when nothing was split,
    /// so a solo expense on the trip does not get a pointless second line.
    private static func splitLine(_ expense: Expense) -> String? {
        guard !expense.shares.isEmpty else { return nil }
        return shares(of: expense).map { share in
            let who = share.person?.name ?? "You"
            let settled = share.settledAt == nil ? "" : " (paid)"
            return "\(who) \(Money.rupees(share.amountPaise))\(settled)"
        }
        .joined(separator: " · ")
    }

    // MARK: - CSV

    /// One row per person per expense, which is the shape that pivots and sums
    /// in a spreadsheet. Whole rupees, because that is what the app ever stores.
    static func csv(_ group: ExpenseGroup) -> GroupCSV {
        var rows = [["Date", "Expense", "Total", "Paid by", "Person", "Share", "Status"]]

        for expense in ordered(group) {
            let date = isoLabel(expense.spentAt)
            let note = expense.note.isEmpty ? "unlabelled" : expense.note
            let total = String(expense.amountPaise / 100)
            let payer = expense.payer?.name ?? "You"

            guard !expense.shares.isEmpty else {
                rows.append([date, note, total, payer, "You", total, "yours"])
                continue
            }

            for share in shares(of: expense) {
                rows.append([
                    date,
                    note,
                    total,
                    payer,
                    share.person?.name ?? "You",
                    String(share.amountPaise / 100),
                    status(of: share, payer: expense.payer),
                ])
            }
        }

        rows.append([])
        rows.append(["", "Total", String(Groups.totalPaise(group) / 100), "", "", "", ""])
        rows.append(["", "Your share", String(Groups.mySharePaise(group) / 100), "", "", "", ""])
        for balance in Groups.settlement(in: group) {
            rows.append([
                "",
                balance.isOwed ? "\(balance.name) is owed" : "\(balance.name) owes",
                String(abs(balance.paise) / 100),
                "", "", "", "",
            ])
        }

        return GroupCSV(
            name: fileName(group),
            text: rows.map { $0.map(escaped).joined(separator: ",") }.joined(separator: "\n")
        )
    }

    /// Whose money is still in the air. A share belonging to whoever fronted the
    /// bill was never owed to anyone, so it is neither open nor settled.
    private static func status(of share: Share, payer: Person?) -> String {
        let isPayersOwnShare = share.person?.persistentModelID == payer?.persistentModelID
        if isPayersOwnShare { return "yours" }
        return share.settledAt == nil ? "open" : "settled"
    }

    private static func escaped(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func fileName(_ group: ExpenseGroup) -> String {
        let cleaned = group.name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return cleaned.isEmpty ? "trip-expenses" : "\(cleaned)-expenses"
    }

    // MARK: - Shared

    private static func ordered(_ group: ExpenseGroup) -> [Expense] {
        group.expenses.sorted { $0.spentAt < $1.spentAt }
    }

    /// A SwiftData to-many is a set, so the stored order is whatever the store
    /// hands back — the first export read "Meera · Ravi · You". Mine leads, the
    /// rest by name, so the same trip exports the same way twice running.
    private static func shares(of expense: Expense) -> [Share] {
        expense.shares.sorted { a, b in
            switch (a.person, b.person) {
            case (nil, nil):            return false
            case (nil, _):              return true
            case (_, nil):              return false
            case let (lhs?, rhs?):      return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private static func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Ledger.calendar
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    private static func isoLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Ledger.calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

/// Carries the CSV to the share sheet as a real .csv file rather than a wall of
/// text, so Files, Mail and WhatsApp all treat it as an attachment.
struct GroupCSV: Transferable {
    let name: String
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { csv in
            Data(csv.text.utf8)
        }
        .suggestedFileName { "\($0.name).csv" }
    }
}
