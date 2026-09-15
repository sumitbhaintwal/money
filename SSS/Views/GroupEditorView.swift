import SwiftUI
import SwiftData

struct GroupEditorView: View {
    let group: ExpenseGroup?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Person> { $0.removedAt == nil }, sort: \Person.name)
    private var people: [Person]

    @State private var name: String
    @State private var chosen: Set<PersistentIdentifier>
    @State private var confirmingDelete = false

    init(group: ExpenseGroup?) {
        self.group = group
        _name = State(initialValue: group?.name ?? "")
        _chosen = State(initialValue: Set((group?.members ?? []).map(\.persistentModelID)))
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.top, 24)

            VStack(alignment: .leading, spacing: 5) {
                Label9("NAME", size: 11)
                TextField("", text: $name, prompt: Text(verbatim: "Goa trip"))
                    .font(Theme.F.display(24, .medium))
                    .foregroundStyle(Theme.body)
                    .autocorrectionDisabled()
                    .frame(height: 46)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
            }
            .padding(.top, 26)

            Label9("WHO'S IN", size: 11).padding(.top, 26)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if people.isEmpty {
                        Text("Add people first, then group them.")
                            .font(Theme.F.display(18, .medium))
                            .foregroundStyle(Theme.dim)
                            .padding(.top, 20)
                    }
                    ForEach(people) { person in
                        memberRow(person)
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            if let group {
                HStack(spacing: 10) {
                    Button { toggleClosed(group) } label: {
                        Text(group.isOpen ? "CLOSE TRIP" : "REOPEN")
                            .font(Theme.F.display(16, .bold)).tracking(2)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.glass)

                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Text("DELETE").font(Theme.F.display(16, .bold)).tracking(2)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.glass)
                }
                .padding(.bottom, 10)
            }

            Button { save() } label: {
                Text(group == nil ? "CREATE" : "SAVE")
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.sheet)
        .confirmationDialog(
            "Delete \(group?.name ?? "this group")?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteGroup() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The expenses in it are kept — they just stop belonging to a trip.")
        }
    }

    private var header: some View {
        HStack {
            Label9(group == nil ? "NEW GROUP" : "EDIT GROUP", size: 14)
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
        .frame(height: 44)
    }

    private func memberRow(_ person: Person) -> some View {
        let isOn = chosen.contains(person.persistentModelID)
        return Button {
            if isOn { chosen.remove(person.persistentModelID) }
            else { chosen.insert(person.persistentModelID) }
        } label: {
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
                Text(person.name)
                    .font(Theme.F.display(21, .medium))
                    .foregroundStyle(isOn ? Theme.body : Theme.dim)
                Spacer()
            }
            .frame(height: 56)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rowRule).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let members = people.filter { chosen.contains($0.persistentModelID) }
        if let group {
            group.name = trimmedName
            group.members = members
        } else {
            context.insert(ExpenseGroup(name: trimmedName, members: members))
        }
        try? context.save()
        dismiss()
    }

    private func toggleClosed(_ group: ExpenseGroup) {
        group.closedAt = group.isOpen ? .now : nil
        try? context.save()
        dismiss()
    }

    /// The relationship nullifies, so the expenses survive without a group.
    private func deleteGroup() {
        guard let group else { return }
        context.delete(group)
        try? context.save()
        dismiss()
    }
}
