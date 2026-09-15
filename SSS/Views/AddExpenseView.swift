import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Person> { $0.removedAt == nil }, sort: \Person.createdAt)
    private var people: [Person]
    @Query private var allGroups: [ExpenseGroup]

    private enum Field { case amount, note }

    @State private var digits = ""
    @State private var note = ""
    @State private var isEssential = false
    @State private var isSplit = false
    /// Off when I paid but took none of it — covering someone else's bill.
    @State private var includesMe = true
    @State private var chosen: Set<PersistentIdentifier> = []
    @State private var groupID: PersistentIdentifier?
    @State private var addingPerson = false
    @State private var newPersonName = ""
    @FocusState private var focus: Field?

    /// nil creates a new expense; otherwise the sheet edits this one in place.
    private let editing: Expense?

    init(editing: Expense? = nil) {
        self.editing = editing
        let shares = editing?.shares ?? []
        _digits = State(initialValue: editing.map { String($0.amountPaise / 100) } ?? "")
        _note = State(initialValue: editing?.note ?? "")
        _isEssential = State(initialValue: editing?.isEssential ?? false)
        _isSplit = State(initialValue: !shares.isEmpty)
        _includesMe = State(initialValue: shares.isEmpty || shares.contains { $0.person == nil })
        _chosen = State(initialValue: Set((editing?.shares ?? []).compactMap { $0.person?.persistentModelID }))
        _groupID = State(initialValue: editing?.group?.persistentModelID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow.padding(.horizontal, 24).padding(.top, 22)
            amountRow.padding(.top, 34)
            noteField.padding(.horizontal, 24).padding(.top, 32)
            chips.padding(.horizontal, 24).padding(.top, 18)
            if !selectableGroups.isEmpty { groupChips.padding(.top, 10) }

            // Scrolls rather than grows: six people plus the covering note
            // overflowed the sheet, clipping the header and pushing the save
            // button off the bottom edge.
            if isSplit {
                ScrollView {
                    peoplePane
                        .padding(.horizontal, 24)
                        .padding(.top, 26)
                        .padding(.bottom, 4)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }

            Spacer(minLength: 0)
            saveButton.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 12)
        }
        .background(Theme.sheet)
        // Straight to the number on a new expense — the whole claim is that
        // logging takes seconds, and a tap to raise the keyboard is one too many.
        .onAppear { if editing == nil { focus = .amount } }
        .alert("Who are you splitting with?", isPresented: $addingPerson) {
            TextField("Name", text: $newPersonName)
            Button("Cancel", role: .cancel) { newPersonName = "" }
            Button("Add") { addPerson() }
        }
    }

    // MARK: - Header and amount

    private var headerRow: some View {
        HStack {
            Label9(headerTitle, size: 14)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .padding(.trailing, -12)
        }
    }

    private var amountRow: some View {
        // A hidden field takes the keystrokes and a plain Text does the drawing.
        // Binding a TextField to a formatted string does not work while editing:
        // UIKit holds its own copy of the text, so the grouping never lands and
        // the field showed 2448 while the button showed ₹2,448.
        ZStack {
            TextField("", text: $digits)
                .keyboardType(.numberPad)
                .focused($focus, equals: .amount)
                // Clear ink and caret rather than opacity — at 0.01 the raw
                // digits were still faintly legible down the left edge.
                .foregroundStyle(.clear)
                .tint(.clear)
                .onChange(of: digits) { _, new in
                    digits = Validate.digitsOnly(new, max: 7)
                }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("₹")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.placeholder)
                Text(hasAmount ? Money.grouped(amountPaise / 100) : "0")
                    .font(.system(size: 76, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(hasAmount ? Theme.ink : Theme.placeholder)
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { focus = .amount }
        .accessibilityLabel("Amount in rupees")
    }

    private var noteField: some View {
        TextField("what for?", text: $note)
            .font(Theme.F.display(20, .medium))
            .foregroundStyle(Theme.body)
            .focused($focus, equals: .note)
            .submitLabel(.done)
            // Merchant names are not dictionary words — autocorrect turned
            // "Toit" into "Tout" on the first try.
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .frame(height: 52)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.rule).frame(height: 1)
            }
    }

    private var chips: some View {
        HStack(spacing: 10) {
            Chip(title: "SPLIT", isOn: isSplit, systemImage: "divide") {
                isSplit.toggle()
                // Drop the keyboard when the people list appears, or it covers it.
                if isSplit { focus = nil } else { focus = .amount; includesMe = true }
            }
            Chip(title: "ESSENTIAL", isOn: isEssential) {
                isEssential.toggle()
            }
            Spacer()
        }
    }

    /// Open trips, plus whatever this expense is already filed under.
    private var selectableGroups: [ExpenseGroup] {
        Groups.sorted(allGroups.filter { $0.isOpen || $0.persistentModelID == groupID })
    }

    private var groupChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Chip(title: "NO GROUP", isOn: groupID == nil) { groupID = nil }
                ForEach(selectableGroups) { group in
                    Chip(title: group.name.uppercased(), isOn: groupID == group.persistentModelID) {
                        pick(group)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
    }

    /// Choosing a trip pre-selects the people on it — splitting the same bill
    /// between the same five people is most of the tedium.
    private func pick(_ group: ExpenseGroup) {
        if groupID == group.persistentModelID {
            groupID = nil
            return
        }
        groupID = group.persistentModelID
        let members = Set(group.members.map(\.persistentModelID))
        if !members.isEmpty {
            chosen = members
            isSplit = true
            focus = nil
        }
    }

    // MARK: - Panes

    private var peoplePane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label9("SPLIT BETWEEN — \(participantCount)", size: 13)
                Spacer()
                Button { focus = nil; addingPerson = true } label: {
                    Label9("+ ADD PERSON", color: Theme.ink, size: 13)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)

            if people.isEmpty {
                Text("Nobody to split with yet.")
                    .font(Theme.F.display(18, .medium))
                    .foregroundStyle(Theme.dim)
                    .frame(height: 58, alignment: .leading)
            } else {
                // Tickable like anyone else — untick it and you paid a bill that
                // was entirely someone else's. Picking nobody at all just leaves
                // the button saying PICK SOMEONE, same as before.
                personRow(
                    name: "You",
                    isOn: includesMe,
                    amount: includesMe ? shareText(at: 0) : "—",
                    toggle: { includesMe.toggle() }
                )
                ForEach(Array(people.enumerated()), id: \.element.persistentModelID) { index, person in
                    personRow(
                        name: person.name,
                        isOn: chosen.contains(person.persistentModelID),
                        amount: shareText(forPersonAt: index),
                        toggle: { toggle(person) }
                    )
                }
            }

            if !includesMe && !chosen.isEmpty {
                Text("You're covering this — none of it counts as your spending.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 14)
            }

            if let remainder = Split.remainderNote(totalPaise: amountPaise, among: participantCount), hasAmount {
                Text(remainder)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 14)
            }
        }
    }

    @ViewBuilder
    private func personRow(name: String, isOn: Bool, amount: String, toggle: (() -> Void)?) -> some View {
        if let toggle {
            Button(action: toggle) { personRowBody(name: name, isOn: isOn, amount: amount) }
                .buttonStyle(.plain)
        } else {
            personRowBody(name: name, isOn: isOn, amount: amount)
        }
    }

    private func personRowBody(name: String, isOn: Bool, amount: String) -> some View {
        HStack(spacing: 14) {
                ZStack {
                    Rectangle()
                        .fill(isOn ? Theme.lit : Color.clear)
                        .overlay(Rectangle().stroke(isOn ? Theme.lit : Theme.outline, lineWidth: 1))
                        .frame(width: 24, height: 24)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.onLit)
                    }
                }
                Text(name)
                    .font(Theme.F.display(21, .medium))
                    .foregroundStyle(isOn ? Theme.body : Theme.dim)
                Spacer()
                Text(amount)
                    .font(.system(size: 15))
                    .monospacedDigit()
                    .foregroundStyle(isOn ? Theme.secondary : Theme.outline)
            }
        .frame(height: 58)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.rowRule).frame(height: 1)
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text(ctaTitle)
                .font(Theme.F.display(19, .bold))
                .tracking(3)
                .frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(.glassProminent)
        .tint(Theme.lit)
        .disabled(!canSave)
    }

    /// Split with nobody picked is not a saveable state, and the button should say so.
    private var canSave: Bool {
        hasAmount && !(isSplit && participantCount == 0)
    }

    // MARK: - Derived

    private var selectedGroup: ExpenseGroup? {
        guard let groupID else { return nil }
        return allGroups.first { $0.persistentModelID == groupID }
    }

    private var amountPaise: Int { (Int(digits) ?? 0) * 100 }
    private var hasAmount: Bool { amountPaise > 0 }

    /// Everyone ticked, plus me unless I've taken myself off the bill.
    private var participantCount: Int { chosen.count + (includesMe ? 1 : 0) }

    private var shares: [Int] {
        Split.evenly(totalPaise: amountPaise, among: participantCount)
    }

    private func shareText(at index: Int) -> String {
        guard hasAmount, index < shares.count else { return "—" }
        return Money.rupees(shares[index])
    }

    private func shareText(forPersonAt index: Int) -> String {
        let person = people[index]
        guard chosen.contains(person.persistentModelID) else { return "—" }
        // 1-based position among the ticked people; my own share sits at 0 when
        // I'm on the bill, so everyone slides down one place.
        let rank = people
            .prefix(index + 1)
            .filter { chosen.contains($0.persistentModelID) }
            .count
        return shareText(at: includesMe ? rank : rank - 1)
    }

    private var ctaTitle: String {
        guard hasAmount else { return "ENTER AN AMOUNT" }
        if isSplit && participantCount == 0 { return "PICK SOMEONE" }
        if editing != nil { return "SAVE CHANGES" }
        if isSplit && !includesMe { return "COVER \(Money.rupees(amountPaise))" }
        if isSplit { return "SPLIT \(Money.rupees(amountPaise))" }
        return "SAVE \(Money.rupees(amountPaise))"
    }

    private var headerTitle: String {
        let f = DateFormatter()
        f.calendar = Ledger.calendar
        f.dateFormat = "MMM d"
        let day = f.string(from: editing?.spentAt ?? .now).uppercased()
        return "\(editing == nil ? "NEW EXPENSE" : "EDIT EXPENSE") · \(day)"
    }

    // MARK: - Actions

    private func toggle(_ person: Person) {
        let id = person.persistentModelID
        if chosen.contains(id) { chosen.remove(id) } else { chosen.insert(id) }
    }

    private func addPerson() {
        let name = newPersonName.trimmingCharacters(in: .whitespacesAndNewlines)
        newPersonName = ""
        guard !name.isEmpty else { return }
        let person = Person(name: name)
        context.insert(person)
        chosen.insert(person.persistentModelID)
    }

    private func save() {
        guard canSave else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let expense: Expense
        // Editing rebuilds the shares wholesale, so remember who had already
        // squared up — an edit must not silently un-settle a paid debt.
        var alreadySettled: [PersistentIdentifier: Date] = [:]

        if let editing {
            expense = editing
            for share in editing.shares {
                if let person = share.person, let settled = share.settledAt {
                    alreadySettled[person.persistentModelID] = settled
                }
            }
            editing.shares.forEach(context.delete)
            editing.shares = []
            expense.amountPaise = amountPaise
            expense.note = trimmed
            expense.isEssential = isEssential
            expense.group = selectedGroup
        } else {
            expense = Expense(
                amountPaise: amountPaise,
                note: trimmed,
                spentAt: .now,
                isEssential: isEssential,
                group: selectedGroup
            )
            context.insert(expense)
        }

        if isSplit && !chosen.isEmpty {
            let participants = people.filter { chosen.contains($0.persistentModelID) }
            let amounts = Split.evenly(totalPaise: amountPaise, among: participantCount)
            // My portion leads the list when there is one; leaving it out is what
            // makes the expense cost me nothing, since mySharePaise reads exactly
            // the share with no person on it.
            var rows = includesMe ? [Share(amountPaise: amounts[0])] : []
            for (index, person) in participants.enumerated() {
                rows.append(Share(
                    amountPaise: amounts[index + (includesMe ? 1 : 0)],
                    person: person,
                    settledAt: alreadySettled[person.persistentModelID]
                ))
            }
            rows.forEach(context.insert)
            expense.shares = rows
        }

        try? context.save()
        dismiss()
    }
}
