import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// A trip's books as a spreadsheet, for whoever keeps the accounts. The other
/// half of exporting is GroupPDF, which is the shape people actually send each
/// other. Nobody else runs this app, so the export *is* the sharing.
enum GroupExport {

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
        for transfer in Groups.settleUp(in: group) {
            rows.append([
                "",
                "\(transfer.fromName) pays \(transfer.toName)",
                String(transfer.paise / 100),
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
