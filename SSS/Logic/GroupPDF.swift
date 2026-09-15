import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

/// A trip's accounts as a document someone can file, print or forward.
///
/// Paginated rather than rendered as one very tall page: ImageRenderer will
/// happily produce a 3,000pt page, which looks fine on a phone and comes out of
/// a printer as a postage stamp.
enum GroupPDF {

    /// A4 at 72dpi, which is what every PDF reader and printer expects.
    private static let page = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 44

    @MainActor
    static func render(_ group: ExpenseGroup) -> GroupDocument? {
        let sheets = paginate(group)
        guard !sheets.isEmpty else { return nil }

        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: page)
        guard
            let consumer = CGDataConsumer(data: data as CFMutableData),
            let context = CGContext(consumer: consumer, mediaBox: &box, nil)
        else { return nil }

        for (index, sheet) in sheets.enumerated() {
            let view = Page(group: group, content: sheet, number: index + 1, of: sheets.count)
            let renderer = ImageRenderer(content: view)
            renderer.proposedSize = ProposedViewSize(page)

            renderer.render { _, draw in
                context.beginPDFPage(nil)
                draw(context)
                context.endPDFPage()
            }
        }

        context.closePDF()
        return GroupDocument(name: GroupExport.fileName(group), data: data as Data)
    }

    // MARK: - Pagination

    /// What goes on one page. The first carries the settlement table, which is
    /// the part anyone actually needs, so it is never pushed behind a long list
    /// of expenses.
    struct Sheet {
        var transfers: [Transfer] = []
        var expenses: [Expense] = []
        var isFirst = false
    }

    private static func paginate(_ group: ExpenseGroup) -> [Sheet] {
        let transfers = Groups.settleUp(in: group)
        let expenses = group.expenses.sorted { $0.spentAt < $1.spentAt }

        // Derived from the row heights below, and deliberately conservative: the
        // page is a fixed frame, so an over-estimate does not scroll, it clips.
        // 842pt less margins and footer leaves ~724; the header, totals and
        // settlement table take ~188 plus 26 per transfer, and an expense row
        // with its split line is ~41.
        let firstPageRows = max(3, 11 - transfers.count)
        let laterPageRows = 15

        var sheets: [Sheet] = []
        var remaining = expenses[...]

        let firstCount = min(remaining.count, firstPageRows)
        sheets.append(Sheet(
            transfers: transfers,
            expenses: Array(remaining.prefix(firstCount)),
            isFirst: true
        ))
        remaining = remaining.dropFirst(firstCount)

        while !remaining.isEmpty {
            let count = min(remaining.count, laterPageRows)
            sheets.append(Sheet(expenses: Array(remaining.prefix(count))))
            remaining = remaining.dropFirst(count)
        }

        return sheets
    }

    // MARK: - The page

    private struct Page: View {
        let group: ExpenseGroup
        let content: Sheet
        let number: Int
        let of: Int

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                if content.isFirst {
                    header
                    totals.padding(.top, 22)
                    if !content.transfers.isEmpty { settlement.padding(.top, 28) }
                }

                if !content.expenses.isEmpty {
                    expenses.padding(.top, content.isFirst ? 28 : 0)
                }

                Spacer(minLength: 0)
                footer
            }
            .padding(GroupPDF.margin)
            .frame(width: GroupPDF.page.width, height: GroupPDF.page.height, alignment: .topLeading)
            // White, not the app's off-white: this one gets printed.
            .background(Color.white)
        }

        private var header: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(Theme.F.display(30, .bold))
                    .foregroundStyle(Theme.ink)
                Label9(subtitle, size: 10)
            }
        }

        private var subtitle: String {
            var parts = ["\(group.members.count) \(group.members.count == 1 ? "PERSON" : "PEOPLE")"]
            if !group.isOpen { parts.append("CLOSED") }
            parts.append(GroupPDF.range(of: group))
            return parts.joined(separator: " · ")
        }

        private var totals: some View {
            HStack(alignment: .firstTextBaseline) {
                amount(Money.rupees(Groups.totalPaise(group)), "SPENT IN TOTAL", size: 28)
                Spacer()
                amount(Money.rupees(Groups.mySharePaise(group)), "YOUR SHARE", size: 20, trailing: true)
            }
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
        }

        private func amount(_ value: String, _ label: String, size: CGFloat, trailing: Bool = false) -> some View {
            VStack(alignment: trailing ? .trailing : .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: size, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Label9(label, size: 9)
            }
        }

        private var settlement: some View {
            VStack(alignment: .leading, spacing: 0) {
                Label9("SETTLE UP", size: 10).padding(.bottom, 6)
                ForEach(content.transfers) { transfer in
                    HStack(spacing: 8) {
                        Text(transfer.fromName)
                            .font(Theme.F.display(15, .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.outline)
                        Text(transfer.toName)
                            .font(Theme.F.display(15, .medium))
                        Spacer(minLength: 8)
                        Text(Money.rupees(transfer.paise))
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Theme.ink)
                    .frame(height: 26)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.rowRule).frame(height: 1) }
                }
            }
        }

        private var expenses: some View {
            VStack(alignment: .leading, spacing: 0) {
                Label9(content.isFirst ? "EXPENSES" : "EXPENSES CONTINUED", size: 10).padding(.bottom, 6)
                ForEach(content.expenses) { expense in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 10) {
                            Label9(GroupPDF.day(expense.spentAt), size: 9)
                                .frame(width: 46, alignment: .leading)
                            Text(expense.note.isEmpty ? "—" : expense.note)
                                .font(Theme.F.display(15, .medium))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(GroupPDF.payerLabel(expense))
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.muted)
                            Text(Money.rupees(expense.amountPaise))
                                .font(.system(size: 13, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(Theme.ink)
                                .frame(width: 66, alignment: .trailing)
                        }
                        if let split = GroupPDF.splitLine(expense) {
                            Text(split)
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.secondary)
                                .lineLimit(1)
                                .padding(.leading, 56)
                        }
                    }
                    .padding(.vertical, 5)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.rowRule).frame(height: 1) }
                }
            }
        }

        private var footer: some View {
            HStack {
                Label9("MONEY", size: 9)
                Spacer()
                Label9(of > 1 ? "PAGE \(number) OF \(of)" : "", size: 9)
            }
            .padding(.top, 14)
            .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
        }
    }

    // MARK: - Text

    private static func day(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Ledger.calendar
        f.dateFormat = "d MMM"
        return f.string(from: date).uppercased()
    }

    /// "15 SEP" for a one-day outing, "12–15 SEP 2026" for a trip.
    private static func range(of group: ExpenseGroup) -> String {
        let dates = group.expenses.map(\.spentAt).sorted()
        guard let first = dates.first, let last = dates.last else { return day(group.createdAt) }

        let f = DateFormatter()
        f.calendar = Ledger.calendar
        f.dateFormat = "d MMM yyyy"
        let start = f.string(from: first).uppercased()
        let end = f.string(from: last).uppercased()
        return start == end ? start : "\(day(first))–\(end)"
    }

    private static func payerLabel(_ expense: Expense) -> String {
        expense.payer.map { "\($0.name) paid" } ?? "you paid"
    }

    private static func splitLine(_ expense: Expense) -> String? {
        guard !expense.shares.isEmpty else { return nil }
        return expense.shares
            .sorted { a, b in
                switch (a.person, b.person) {
                case (nil, nil):       return false
                case (nil, _):         return true
                case (_, nil):         return false
                case let (lhs?, rhs?): return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
            }
            .map { share in
                let who = share.person?.name ?? "You"
                let settled = share.settledAt == nil ? "" : " (paid)"
                return "\(who) \(Money.rupees(share.amountPaise))\(settled)"
            }
            .joined(separator: "  ·  ")
    }
}

/// Carries the rendered PDF to the share sheet as a real file.
struct GroupDocument: Transferable {
    let name: String
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { $0.data }
            .suggestedFileName { "\($0.name).pdf" }
    }
}
