import SwiftUI
import SwiftData

struct PeopleManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Person> { $0.removedAt == nil }, sort: \Person.name)
    private var people: [Person]
    @Query private var expenses: [Expense]

    @State private var editingPerson: Person?
    @State private var addingPerson = false

    private var balances: [PersistentIdentifier: Int] {
        Dictionary(uniqueKeysWithValues: Balances.all(in: expenses).map { ($0.id, $0.paise) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, 24).padding(.top, 22)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if people.isEmpty {
                        Text("Nobody yet. Add someone to split with.")
                            .font(Theme.F.display(19, .medium))
                            .foregroundStyle(Theme.dim)
                            .padding(.top, 36)
                    }
                    ForEach(people) { person in
                        row(person)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            Button { addingPerson = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus").font(.system(size: 15, weight: .bold))
                    Text("ADD PERSON").font(Theme.F.display(18, .bold)).tracking(3)
                }
                .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.lit)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(Theme.sheet)
        .sheet(item: $editingPerson) { PersonEditorView(person: $0) }
        .sheet(isPresented: $addingPerson) { PersonEditorView(person: nil) }
    }

    private var header: some View {
        HStack {
            Label9("MANAGE PEOPLE", size: 14)
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

    private func row(_ person: Person) -> some View {
        Button { editingPerson = person } label: {
            HStack(spacing: 14) {
                ZStack {
                    Rectangle().stroke(Theme.outline, lineWidth: 1).frame(width: 34, height: 34)
                    Text(person.initial)
                        .font(Theme.F.display(16, .semibold))
                        .foregroundStyle(Theme.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(Theme.F.display(21, .medium))
                        .foregroundStyle(Theme.body)
                    Text(person.upiID?.isEmpty == false ? person.upiID! : "no UPI ID")
                        .font(.system(size: 11))
                        .foregroundStyle(person.upiID?.isEmpty == false ? Theme.dim : Theme.outline)
                }
                Spacer()
                if let paise = balances[person.persistentModelID], paise != 0 {
                    Text(Money.signedRupees(paise))
                        .font(.system(size: 15, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.outline)
            }
            .frame(height: 64)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rowRule).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }
}

/// Add or edit one person. A person who has appeared in a split cannot be
/// deleted: their shares are what make past expenses add up, and removing them
/// would leave those bills short.
struct PersonEditorView: View {
    let person: Person?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var expenses: [Expense]

    @State private var name: String
    @State private var upi: String
    @State private var confirmingRemoval = false

    init(person: Person?) {
        self.person = person
        _name = State(initialValue: person?.name ?? "")
        _upi = State(initialValue: person?.upiID ?? "")
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isUsed: Bool {
        guard let person else { return false }
        return Balances.appearsAnywhere(person, in: expenses)
    }

    /// What removing them would write off, if anything.
    private var openBalancePaise: Int {
        guard let person else { return 0 }
        return Balances.all(in: expenses)
            .first { $0.person.persistentModelID == person.persistentModelID }?.paise ?? 0
    }

    private var removalWarning: String {
        let owed = openBalancePaise
        if owed > 0 {
            return "\(person?.name ?? "They") owe you \(Money.rupees(owed)). Removing them writes that off."
        }
        if owed < 0 {
            return "You owe \(person?.name ?? "them") \(Money.rupees(-owed)). Removing them writes that off."
        }
        return isUsed
            ? "Past expenses keep their amounts and totals do not change — their name just stops appearing."
            : "They have never been in a split, so nothing is left behind."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label9(person == nil ? "ADD PERSON" : "EDIT PERSON", size: 14)
                .padding(.top, 28)

            field("NAME", text: $name, placeholder: "Ravi", capitalised: true)
                .padding(.top, 30)
            field("UPI ID", text: $upi, placeholder: "ravi@upi", capitalised: false)
                .padding(.top, 22)

            Text("The UPI ID pre-fills the amount when you pay them. You can leave it blank and add it later.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)

            Spacer(minLength: 0)

            if person != nil {
                Button(role: .destructive) { confirmingRemoval = true } label: {
                    Text("REMOVE").font(Theme.F.display(17, .bold)).tracking(3)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.glass)
                .padding(.bottom, 12)
            }

            Button { save() } label: {
                Text(person == nil ? "ADD" : "SAVE")
                    .font(Theme.F.display(19, .bold)).tracking(3)
                    .frame(maxWidth: .infinity, minHeight: 58)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.lit)
            .disabled(trimmedName.isEmpty)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
        .background(Theme.sheet)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.sheet)
        .confirmationDialog(
            "Remove \(person?.name ?? "this person")?",
            isPresented: $confirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { remove() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(removalWarning)
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, capitalised: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label9(label, size: 11)
            TextField(placeholder, text: text)
                .font(Theme.F.display(22, .medium))
                .foregroundStyle(Theme.body)
                .autocorrectionDisabled()
                .textInputAutocapitalization(capitalised ? .words : .never)
                .frame(height: 44)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let cleanedUPI = upi.trimmingCharacters(in: .whitespacesAndNewlines)
        if let person {
            person.name = trimmedName
            person.upiID = cleanedUPI.isEmpty ? nil : cleanedUPI
        } else {
            context.insert(Person(name: trimmedName, upiID: cleanedUPI.isEmpty ? nil : cleanedUPI))
        }
        try? context.save()
        dismiss()
    }

    private func remove() {
        guard let person else { return }
        Balances.remove(person, in: expenses, context: context)
        try? context.save()
        dismiss()
    }
}
