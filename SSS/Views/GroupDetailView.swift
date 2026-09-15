import SwiftUI
import SwiftData

struct GroupDetailView: View {
    let group: ExpenseGroup

    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var editingExpense: Expense?

    private var expenses: [Expense] {
        group.expenses.sorted { $0.spentAt > $1.spentAt }
    }
    private var transfers: [Transfer] { Groups.settleUp(in: group) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, 24).padding(.top, 22)
            totals.padding(.horizontal, 24).padding(.top, 26)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !expenses.isEmpty {
                        Label9("SETTLE UP", size: 11).padding(.top, 26).padding(.bottom, 4)
                        if transfers.isEmpty {
                            Text("Everyone's square.")
                                .font(Theme.F.display(19, .medium))
                                .foregroundStyle(Theme.dim)
                                .frame(height: 52, alignment: .leading)
                        }
                        ForEach(transfers) { transferRow($0) }
                    }

                    Label9(expenses.isEmpty ? "NOTHING YET" : "EXPENSES", size: 11)
                        .padding(.top, 26).padding(.bottom, 4)
                    if expenses.isEmpty {
                        Text("Add an expense and pick this group to put it here.")
                            .font(Theme.F.display(18, .medium))
                            .foregroundStyle(Theme.dim)
                            .padding(.top, 12)
                    }
                    ForEach(expenses) { expenseRow($0) }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Theme.sheet)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.sheet)
        .sheet(isPresented: $editing) { GroupEditorView(group: group) }
        .sheet(item: $editingExpense) { expense in
            AddExpenseView(editing: expense)
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.sheet)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(Theme.F.display(26, .bold))
                    .foregroundStyle(Theme.ink)
                Label9(
                    group.isOpen ? "\(group.members.count) PEOPLE" : "CLOSED · \(group.members.count) PEOPLE",
                    size: 11
                )
            }
            Spacer()
            exportMenu
            Button { editing = true } label: {
                Label9("EDIT", color: Theme.ink, size: 13)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 18)
        }
    }

    /// Two shapes because they go to different places: the summary into the
    /// group chat, the CSV to whoever keeps the accounts.
    private var exportMenu: some View {
        Menu {
            if let document = GroupPDF.render(group) {
                ShareLink(
                    item: document,
                    preview: SharePreview("\(group.name) expenses", image: Image(systemName: "doc.richtext"))
                ) {
                    Label("Share PDF", systemImage: "doc.richtext")
                }
            }
            ShareLink(
                item: GroupExport.csv(group),
                preview: SharePreview("\(group.name) expenses", image: Image(systemName: "tablecells"))
            ) {
                Label("Share spreadsheet", systemImage: "tablecells")
            }
        } label: {
            Label9("EXPORT", color: Theme.ink, size: 13)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .disabled(group.expenses.isEmpty)
    }

    private var totals: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Money.rupees(Groups.totalPaise(group)))
                    .font(.system(size: 34, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Label9("SPENT IN TOTAL", size: 11)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.rupees(Groups.mySharePaise(group)))
                    .font(.system(size: 22, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondary)
                Label9("YOUR SHARE", size: 11)
            }
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }

    /// One payment per row, in the order it would be made. Rows with me on
    /// either end are the ones the reader can do something about, so they carry
    /// the full ink and everyone else's arrangement sits back a shade.
    private func transferRow(_ transfer: Transfer) -> some View {
        HStack(spacing: 10) {
            Text(transfer.fromName)
                .font(Theme.F.display(19, .medium))
                .foregroundStyle(transfer.isMine ? Theme.body : Theme.secondary)
                .lineLimit(1)
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.outline)
            Text(transfer.toName)
                .font(Theme.F.display(19, .medium))
                .foregroundStyle(transfer.isMine ? Theme.body : Theme.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(Money.rupees(transfer.paise))
                .font(.system(size: 15, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(transfer.isMine ? Theme.ink : Theme.secondary)
        }
        .frame(height: 52)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rowRule).frame(height: 1) }
    }

    private func expenseRow(_ expense: Expense) -> some View {
        Button { editingExpense = expense } label: {
            HStack(spacing: 12) {
                Label9(dayLabel(expense.spentAt), size: 11)
                    .frame(width: 52, alignment: .leading)
                Text(expense.note.isEmpty ? "—" : expense.note)
                    .font(Theme.F.display(19, .medium))
                    .foregroundStyle(expense.note.isEmpty ? Theme.dim : Theme.body)
                Spacer()
                Text(Money.rupees(expense.amountPaise))
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondary)
            }
            .frame(height: 54)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rowRule).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Ledger.calendar
        f.dateFormat = "d MMM"
        return f.string(from: date).uppercased()
    }
}
