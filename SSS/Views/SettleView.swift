import SwiftUI
import SwiftData

struct SettleView: View {
    let balance: PersonBalance

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query(filter: #Predicate<Expense> { $0.deletedAt == nil }) private var expenses: [Expense]

    private enum Step { case pick, confirm, done }
    @State private var step: Step = .pick
    @State private var askingVPA = false
    @State private var vpaDraft = ""

    private var owed: Int { abs(balance.paise) }
    private var iOwe: Bool { balance.paise < 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headline.padding(.top, 44)

            Group {
                switch step {
                case .pick:    pickStep
                case .confirm: confirmStep
                case .done:    doneStep
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 44)

            Spacer(minLength: 0)
            footnote.padding(.horizontal, 24).padding(.bottom, 32)
        }
        .background(Theme.sheet)
        .alert("\(balance.person.name)'s UPI ID", isPresented: $askingVPA) {
            TextField("name@bank", text: $vpaDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { vpaDraft = "" }
            Button("Save") { saveVPA() }
        } message: {
            Text("Needed to pre-fill the amount in your UPI app.")
        }
    }

    // MARK: - Head

    private var headline: some View {
        VStack(spacing: 10) {
            Label9(eyebrow, size: 14)
            Text(Money.rupees(owed))
                .font(.system(size: 62, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(step == .done ? Theme.dim : Theme.ink)
                .strikethrough(step == .done, color: Theme.dim)
            Text(subline)
                .font(Theme.F.display(20, .medium))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var eyebrow: String {
        switch step {
        case .pick:    return iOwe ? "PAY \(balance.person.name.uppercased())" : "\(balance.person.name.uppercased()) OWES YOU"
        case .confirm: return "DID IT GO THROUGH?"
        case .done:    return "SETTLED"
        }
    }

    private var subline: String {
        switch step {
        case .pick:    return balance.reason
        case .confirm: return "we cannot see UPI, so you tell us"
        case .done:    return "recorded in your account"
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var pickStep: some View {
        if iOwe {
            VStack(alignment: .leading, spacing: 0) {
                Label9("OPEN WITH", size: 13).padding(.bottom, 8)
                ForEach(UPI.installed()) { app in
                    upiRow(title: app.name) { open(scheme: app.scheme) }
                }
                upiRow(title: "Any UPI app") { open(scheme: "upi") }
            }
        } else {
            VStack(spacing: 12) {
                ShareLink(item: UPI.reminderText(name: balance.person.name, paise: owed, reason: balance.reason)) {
                    Text("REMIND")
                        .font(Theme.F.display(19, .bold)).tracking(3)
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.lit)
                Button { markSettled() } label: {
                    Text("MARK PAID")
                        .font(Theme.F.display(19, .bold)).tracking(3)
                        .foregroundStyle(Theme.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var confirmStep: some View {
        VStack(spacing: 14) {
            Button { markSettled() } label: {
                HStack(spacing: 11) {
                    Image(systemName: "checkmark").font(.system(size: 17, weight: .bold))
                    Text("YES, IT WENT").font(Theme.F.display(19, .bold)).tracking(3)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.lit)

            Button { step = .pick } label: {
                Text("NOT YET")
                    .font(Theme.F.display(19, .bold)).tracking(3)
                    .foregroundStyle(Theme.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
            .buttonStyle(.glass)
        }
    }

    private var doneStep: some View {
        VStack(spacing: 20) {
            ZStack {
                Rectangle().fill(Theme.lit).frame(width: 64, height: 64)
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.onLit)
            }
            Text("Settled with \(balance.person.name).")
                .font(Theme.F.display(22, .medium))
                .foregroundStyle(Theme.body)
            Button { dismiss() } label: {
                Text("DONE")
                    .font(Theme.F.display(17, .bold)).tracking(3)
                    .foregroundStyle(Theme.secondary)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.glass)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
    }

    private func upiRow(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(title)
                    .font(Theme.F.display(21, .medium))
                    .foregroundStyle(Theme.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.dim)
            }
            .frame(height: 68)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rowRule).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }

    private var footnote: some View {
        Text(footnoteText)
            .font(.system(size: 11))
            .foregroundStyle(Theme.dim)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footnoteText: String {
        switch step {
        case .pick where iOwe:
            return "Opens your UPI app with the amount filled in. It cannot tell us whether you paid — so we will ask."
        case .pick:
            return "Remind sends a plain message. Nobody needs this app to receive it."
        case .confirm:
            return "Nothing is marked paid until you say so. A ledger that guesses is worse than one that asks."
        case .done:
            return "Recorded in your account. Nothing was sent to them."
        }
    }

    // MARK: - Actions

    private func open(scheme: String) {
        guard let vpa = balance.person.upiID, !vpa.isEmpty else {
            vpaDraft = ""
            askingVPA = true
            return
        }
        guard let url = UPI.payURL(
            scheme: scheme,
            vpa: vpa,
            payeeName: balance.person.name,
            paise: owed,
            note: "SSS settle-up",
            reference: UUID().uuidString
        ) else { return }

        // Whether or not a UPI app actually opened, the money is out of our
        // hands and the next question is identical. We never mark it paid.
        openURL(url) { _ in step = .confirm }
    }

    private func saveVPA() {
        let cleaned = vpaDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        vpaDraft = ""
        guard !cleaned.isEmpty else { return }
        balance.person.upiID = cleaned
        try? context.save()
    }

    private func markSettled() {
        Balances.settle(with: balance.person, in: expenses)
        try? context.save()
        step = .done
    }
}
