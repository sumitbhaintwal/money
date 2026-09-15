import SwiftUI

struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(SyncEngine.self) private var sync
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingSignOut = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.top, 22)

            if let account = session.account {
                Label9("ACCOUNT", size: 11).padding(.top, 34)
                VStack(alignment: .leading, spacing: 0) {
                    row("Phone", account.displayPhone)
                    row("Email", account.email)
                }
                .padding(.top, 8)
            }

            Label9("SYNC", size: 11).padding(.top, 30)
            VStack(alignment: .leading, spacing: 0) {
                row("Status", syncStatus)
            }
            .padding(.top, 8)

            Spacer(minLength: 0)

            Button { confirmingSignOut = true } label: {
                Text("SIGN OUT")
                    .font(Theme.F.display(19, .bold)).tracking(3)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.glass)

            Text("Everything is saved to your account. Signing out sends anything still waiting, then clears this phone.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Text(versionLine)
                .font(.system(size: 11))
                .foregroundStyle(Theme.outline)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
        .background(Theme.sheet)
        .confirmationDialog("Sign out?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task {
                    await sync.signOutAndWipe()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your ledger stays in your account — signing back in brings it all down again. You'll need a new code to get in.")
        }
    }

    private var header: some View {
        HStack {
            Label9("SETTINGS", size: 14)
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

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.F.display(19, .medium))
                .foregroundStyle(Theme.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(Theme.body)
        }
        .frame(height: 56)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rowRule).frame(height: 1) }
    }

    private var syncStatus: String {
        switch sync.status {
        case .syncing:            return "Syncing…"
        case .failed(let reason): return reason
        case .idle:
            guard let at = sync.lastSyncedAt else { return "Not yet" }
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .full
            return f.localizedString(for: at, relativeTo: .now).capitalizedFirst
        }
    }

    private var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "Version \(version) (\(build))"
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
