import SwiftUI

struct SignInView: View {
    @Environment(SessionStore.self) private var session

    private enum Stage { case details, code }
    private enum Field { case phone, email, code }

    @State private var stage: Stage = .details
    @State private var phone = ""
    @State private var email = ""
    @State private var code = ""
    @State private var challenge: Challenge?
    @State private var busy = false
    @State private var failure: String?
    @State private var resendIn = 0
    @FocusState private var focus: Field?

    private let auth: AuthService = HTTPAuthService()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.top, 12)

            switch stage {
            case .details: details
            case .code:    codeEntry
            }

            Spacer(minLength: 0)

            if let failure {
                Text(failure)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)
            }

            primaryButton.padding(.bottom, 28)
        }
        .padding(.horizontal, 28)
        .background(Theme.ground)
        .onReceive(timer) { _ in if resendIn > 0 { resendIn -= 1 } }
    }

    // MARK: - Head

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if stage == .code {
                    Button { back() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, -12)
                    .accessibilityLabel("Back")
                }
                Spacer()
            }
            Text(stage == .details ? "Sign in" : "Enter the code")
                .font(Theme.F.display(38, .bold))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(Theme.F.display(18, .medium))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var subtitle: String {
        switch stage {
        case .details:
            return "We send one code to your phone and your inbox. Both are needed."
        case .code:
            guard let challenge else { return "" }
            let shown = Account(id: "", phone: challenge.phone, email: challenge.email).displayPhone
            return "Sent to \(shown), and the code is in \(challenge.email)."
        }
    }

    // MARK: - Stages

    private var details: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 6) {
                Label9("PHONE", size: 11)
                HStack(spacing: 10) {
                    Text("+91")
                        .font(Theme.F.display(24, .medium))
                        .foregroundStyle(Theme.dim)
                    TextField("", text: $phone, prompt: Text(verbatim: "98765 43210"))
                        .font(Theme.F.display(24, .medium))
                        .foregroundStyle(Theme.body)
                        .keyboardType(.numberPad)
                        .textContentType(.telephoneNumber)
                        .focused($focus, equals: .phone)
                        .onChange(of: phone) { _, new in
                            phone = Validate.digitsOnly(new, max: 10)
                        }
                }
                .frame(height: 46)
                .overlay(alignment: .bottom) { Rectangle().fill(underline(phone.isEmpty || phoneOK)).frame(height: 1) }
            }

            VStack(alignment: .leading, spacing: 6) {
                Label9("EMAIL", size: 11)
                TextField("", text: $email, prompt: Text(verbatim: "you@example.com"))
                    .font(Theme.F.display(24, .medium))
                    .foregroundStyle(Theme.body)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .frame(height: 46)
                    .overlay(alignment: .bottom) { Rectangle().fill(underline(email.isEmpty || emailOK)).frame(height: 1) }
            }
        }
        .padding(.top, 40)
    }

    private var codeEntry: some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack {
                // One field drives six boxes, so iOS can autofill the code
                // straight out of the SMS.
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focus, equals: .code)
                    .opacity(0.01)
                    .onChange(of: code) { _, new in
                        code = Validate.digitsOnly(new, max: 6)
                        failure = nil
                    }

                HStack(spacing: 9) {
                    ForEach(0..<6, id: \.self) { index in
                        Text(digit(at: index))
                            .font(.system(size: 26, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 62)
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    }
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { focus = .code }

            Button { Task { await send(resend: true) } } label: {
                Label9(resendIn > 0 ? "RESEND IN \(resendIn)s" : "RESEND CODE",
                       color: resendIn > 0 ? Theme.dim : Theme.ink, size: 12)
            }
            .buttonStyle(.plain)
            .disabled(resendIn > 0 || busy)

            #if DEBUG
            Text(AppConfig.apiBaseURL.absoluteString)
                .font(.system(size: 11))
                .foregroundStyle(Theme.outline)
            #endif
        }
        .padding(.top, 40)
    }

    private var primaryButton: some View {
        Button { Task { await advance() } } label: {
            Group {
                if busy {
                    ProgressView().tint(Theme.onLit)
                } else {
                    Text(stage == .details ? "SEND CODE" : "VERIFY")
                        .font(Theme.F.display(19, .bold)).tracking(3)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(.glassProminent)
        .tint(Theme.lit)
        .disabled(!canAdvance || busy)
    }

    // MARK: - Derived

    private var phoneOK: Bool { Validate.phone(phone) }
    private var emailOK: Bool { Validate.email(email) }

    /// Both are mandatory, so neither alone unlocks the button.
    private var canAdvance: Bool {
        stage == .details ? (phoneOK && emailOK) : code.count == 6
    }

    private func underline(_ ok: Bool) -> Color { ok ? Theme.rule : Theme.body }

    private func digit(at index: Int) -> String {
        index < code.count ? String(Array(code)[index]) : ""
    }

    // MARK: - Actions

    private func advance() async {
        switch stage {
        case .details: await send(resend: false)
        case .code:    await verify()
        }
    }

    private func send(resend: Bool) async {
        guard phoneOK, emailOK, !busy else { return }
        busy = true
        failure = nil
        defer { busy = false }
        do {
            challenge = try await auth.sendCode(phone: phone, email: email)
            stage = .code
            resendIn = 30
            if !resend { code = "" }
            focus = .code
        } catch {
            failure = (error as? AuthError)?.message ?? AuthError.unexpected.message
        }
    }

    private func verify() async {
        guard let challenge, code.count == 6, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let result = try await auth.verify(challenge, code: code)
            session.signIn(token: result.token, account: result.account)
        } catch {
            failure = (error as? AuthError)?.message ?? AuthError.unexpected.message
            code = ""
        }
    }

    private func back() {
        stage = .details
        code = ""
        failure = nil
        focus = .phone
    }
}
