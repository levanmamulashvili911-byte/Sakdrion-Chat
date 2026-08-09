import SwiftUI

struct OnboardingView: View {
    private enum Step {
        case phone, code, profile
    }

    @Environment(AppStore.self) private var store

    @State private var step: Step = .phone
    @State private var country = Country.all[0]
    @State private var phone = ""
    @State private var code = ""
    @State private var name = ""
    @State private var about = "Available"
    @State private var isWorking = false

    @FocusState private var focus: Field?

    private enum Field: Hashable { case phone, code, name }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Group {
                    switch step {
                    case .phone: phoneStep
                    case .code: codeStep
                    case .profile: profileStep
                    }
                }
                .padding(.horizontal, 24)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer(minLength: 0)
            }
            .animation(.easeInOut(duration: 0.28), value: step)
        }
        .safeAreaInset(edge: .bottom) {
            footer
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.accentSoft)
                .frame(width: 76, height: 76)
                .overlay {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                }

            Text("Sakdrion Chat")
                .font(.sakTitle)
                .foregroundStyle(Palette.textPrimary)

            Text(subtitle)
                .font(.sakSubhead)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 56)
        .padding(.bottom, 36)
    }

    private var subtitle: String {
        switch step {
        case .phone: "Simple, private messaging and calling. Enter your phone number to get started."
        case .code: "We sent a 6-digit code to \(country.dialCode) \(phone)."
        case .profile: "Tell your contacts who they're talking to."
        }
    }

    private var phoneStep: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(Country.all) { item in
                        Button {
                            country = item
                        } label: {
                            Text("\(item.flag)  \(item.name)  \(item.dialCode)")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(country.flag)
                        Text(country.dialCode)
                            .font(.sakBody)
                            .foregroundStyle(Palette.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.textTertiary)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerMedium, style: .continuous))
                }

                TextField("Phone number", text: $phone)
                    .font(.sakBody)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($focus, equals: .phone)
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerMedium, style: .continuous))
            }

            Text("By continuing you agree to the Terms of Service and Privacy Policy.")
                .font(.sakCaption)
                .foregroundStyle(Palette.textTertiary)
                .multilineTextAlignment(.center)
        }
        .onAppear { focus = .phone }
    }

    private var codeStep: some View {
        VStack(spacing: 20) {
            ZStack {
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focus, equals: .code)
                    .opacity(0.001)
                    .onChange(of: code) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        code = String(digits.prefix(6))
                        if code.count == 6 { verify() }
                    }

                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { index in
                        digitBox(at: index)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { focus = .code }
            }

            Button("Use any 6 digits to continue") {
                code = "204815"
            }
            .font(.sakCaption)
            .foregroundStyle(Palette.accent)
        }
        .onAppear { focus = .code }
    }

    private func digitBox(at index: Int) -> some View {
        let characters = Array(code)
        let value = index < characters.count ? String(characters[index]) : ""
        let isActive = index == characters.count && focus == .code
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Palette.surface)
            .frame(width: 46, height: 56)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isActive ? Palette.accent : Palette.separator, lineWidth: isActive ? 1.8 : 1)
            }
            .overlay {
                Text(value)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
            }
    }

    private var profileStep: some View {
        VStack(spacing: 16) {
            AvatarView(
                initials: initials(from: name),
                colorSeed: 0,
                size: Metrics.avatarLarge,
                systemImage: name.isEmpty ? "person.fill" : nil
            )
            .padding(.bottom, 4)

            TextField("Your name", text: $name)
                .font(.sakBody)
                .textContentType(.name)
                .focused($focus, equals: .name)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerMedium, style: .continuous))

            TextField("About", text: $about)
                .font(.sakBody)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerMedium, style: .continuous))
        }
        .onAppear { focus = .name }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: primaryTitle, isEnabled: isPrimaryEnabled, isLoading: isWorking) {
                advance()
            }

            if step != .phone {
                Button("Back") {
                    focus = nil
                    withAnimation { step = step == .code ? .phone : .code }
                }
                .font(.sakSubhead)
                .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Palette.background)
    }

    // MARK: - Flow

    private var primaryTitle: String {
        switch step {
        case .phone: "Continue"
        case .code: "Verify"
        case .profile: "Start messaging"
        }
    }

    private var isPrimaryEnabled: Bool {
        switch step {
        case .phone: phone.filter(\.isNumber).count >= 6
        case .code: code.count == 6
        case .profile: !name.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func advance() {
        switch step {
        case .phone:
            focus = nil
            withAnimation { step = .code }
        case .code:
            verify()
        case .profile:
            focus = nil
            store.completeSignIn(
                name: name,
                phoneNumber: "\(country.dialCode) \(phone)",
                about: about
            )
            Haptics.success()
        }
    }

    private func verify() {
        guard code.count == 6, !isWorking else { return }
        isWorking = true
        focus = nil
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            isWorking = false
            withAnimation { step = .profile }
        }
    }

    private func initials(from value: String) -> String {
        value.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

// MARK: - Countries

struct Country: Identifiable, Hashable {
    var id: String { dialCode + name }
    let flag: String
    let name: String
    let dialCode: String

    static let all: [Country] = [
        Country(flag: "🇬🇪", name: "Georgia", dialCode: "+995"),
        Country(flag: "🇺🇸", name: "United States", dialCode: "+1"),
        Country(flag: "🇬🇧", name: "United Kingdom", dialCode: "+44"),
        Country(flag: "🇩🇪", name: "Germany", dialCode: "+49"),
        Country(flag: "🇫🇷", name: "France", dialCode: "+33"),
        Country(flag: "🇮🇹", name: "Italy", dialCode: "+39"),
        Country(flag: "🇹🇷", name: "Türkiye", dialCode: "+90"),
        Country(flag: "🇦🇪", name: "United Arab Emirates", dialCode: "+971")
    ]
}

#Preview {
    OnboardingView()
        .environment(AppStore(storage: SnapshotStorage(fileName: "preview-onboarding.json"), snapshot: AppSnapshot()))
}
