import SwiftUI

enum SettingsRoute: Hashable {
    case profile, appearance, privacy, notifications, storage, about
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(CallCenter.self) private var callCenter

    @State private var path: [SettingsRoute] = []
    @State private var isConfirmingSignOut = false
    @State private var isConfirmingReset = false

    var body: some View {
        @Bindable var store = store

        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 18) {
                    profileCard

                    Card {
                        navRow(.profile, icon: "person.fill", title: "Profile", subtitle: "Name, photo, about")
                        CardDivider()
                        navRow(.privacy, icon: "lock.fill", iconTint: Palette.success, title: "Privacy", subtitle: "Last seen, read receipts")
                        CardDivider()
                        navRow(.notifications, icon: "bell.fill", iconTint: Palette.warning, title: "Notifications", subtitle: "Messages, calls, sounds")
                        CardDivider()
                        navRow(.appearance, icon: "paintbrush.fill", iconTint: Palette.accent, title: "Appearance", subtitle: store.preferences.appearance.label)
                        CardDivider()
                        navRow(.storage, icon: "internaldrive.fill", iconTint: Palette.textSecondary, title: "Storage and data", subtitle: "\(store.storageEstimate.messages) messages")
                    }

                    Card {
                        navRow(.about, icon: "info.circle.fill", iconTint: Palette.textSecondary, title: "About", subtitle: "Version \(Self.appVersion)")
                        CardDivider()
                        CardRow(icon: "questionmark.circle.fill", iconTint: Palette.accent, title: "Help", subtitle: "FAQ, contact us", showsChevron: true)
                        CardDivider()
                        CardRow(icon: "heart.fill", iconTint: Palette.danger, title: "Invite a friend", showsChevron: true)
                    }

                    demoCard

                    Button {
                        isConfirmingSignOut = true
                    } label: {
                        Text("Log out")
                            .font(.sakBody)
                            .foregroundStyle(Palette.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Palette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerLarge, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Text("Sakdrion Chat · \(Self.appVersion)")
                        .font(.sakCaption)
                        .foregroundStyle(Palette.textTertiary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, Metrics.hPadding)
                .padding(.bottom, 30)
            }
            .background(Palette.background)
            .navigationTitle("Settings")
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .profile: ProfileEditView()
                case .appearance: AppearanceSettingsView()
                case .privacy: PrivacySettingsView()
                case .notifications: NotificationSettingsView()
                case .storage: StorageSettingsView()
                case .about: AboutView()
                }
            }
            .confirmationDialog("Log out of Sakdrion Chat?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
                Button("Log out", role: .destructive) { store.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Chats on this device will be removed.")
            }
            .confirmationDialog("Reset demo data?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { store.resetDemoData() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Pieces

    private var profileCard: some View {
        Button {
            path.append(.profile)
        } label: {
            HStack(spacing: 14) {
                AvatarView(contact: store.me, size: 62)

                VStack(alignment: .leading, spacing: 3) {
                    Text(store.me.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(store.me.about)
                        .font(.sakSubhead)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                    Text(store.me.phoneNumber)
                        .font(.sakCaption)
                        .foregroundStyle(Palette.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
            }
            .padding(Metrics.hPadding)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var demoCard: some View {
        @Bindable var store = store

        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Demo")
            Card {
                CardRow(icon: "phone.arrow.down.left.fill", iconTint: Palette.success, title: "Simulate incoming call") {
                    EmptyView()
                }
                .onTapGesture { simulateIncomingCall() }

                CardDivider()

                CardRow(icon: "arrowshape.turn.up.left.fill", iconTint: Palette.accent, title: "Auto-reply", subtitle: "Contacts answer your messages") {
                    Toggle("", isOn: $store.preferences.autoReplyDemo)
                        .labelsHidden()
                }

                CardDivider()

                CardRow(icon: "arrow.counterclockwise", iconTint: Palette.warning, title: "Reset demo data") {
                    EmptyView()
                }
                .onTapGesture { isConfirmingReset = true }
            }
        }
    }

    private func navRow(
        _ route: SettingsRoute,
        icon: String,
        iconTint: Color = Palette.accent,
        title: String,
        subtitle: String? = nil
    ) -> some View {
        Button {
            path.append(route)
        } label: {
            CardRow(icon: icon, iconTint: iconTint, title: title, subtitle: subtitle, showsChevron: true)
        }
        .buttonStyle(.plain)
    }

    private func simulateIncomingCall() {
        guard let peer = store.randomPeer() else { return }
        let chat = store.chat(with: peer.id)
        callCenter.receiveCall(from: peer, chatID: chat.id, kind: Bool.random() ? .audio : .video)
    }

    static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Profile

struct ProfileEditView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var about = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                AvatarView(contact: store.me, size: Metrics.avatarLarge)
                    .padding(.top, 20)
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .fill(Palette.accent)
                            .frame(width: 30, height: 30)
                            .overlay {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .offset(x: 2, y: 2)
                    }

                Card {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.sakMicro)
                            .foregroundStyle(Palette.textTertiary)
                        TextField("Your name", text: $name)
                            .font(.sakBody)
                    }
                    .padding(.horizontal, Metrics.hPadding)
                    .padding(.vertical, 12)

                    CardDivider(leadingInset: Metrics.hPadding)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("About")
                            .font(.sakMicro)
                            .foregroundStyle(Palette.textTertiary)
                        TextField("About", text: $about)
                            .font(.sakBody)
                    }
                    .padding(.horizontal, Metrics.hPadding)
                    .padding(.vertical, 12)

                    CardDivider(leadingInset: Metrics.hPadding)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Phone")
                                .font(.sakMicro)
                                .foregroundStyle(Palette.textTertiary)
                            Text(store.me.phoneNumber)
                                .font(.sakBody)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Metrics.hPadding)
                    .padding(.vertical, 12)
                }

                Text("This name and photo are visible to your contacts.")
                    .font(.sakCaption)
                    .foregroundStyle(Palette.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Metrics.hPadding)
        }
        .background(Palette.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    store.updateProfile(name: name, about: about)
                    Haptics.success()
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            name = store.me.name
            about = store.me.about
        }
    }
}

// MARK: - Appearance

struct AppearanceSettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(spacing: 18) {
                Card {
                    ForEach(Array(Preferences.Appearance.allCases.enumerated()), id: \.element) { index, option in
                        Button {
                            store.preferences.appearance = option
                            Haptics.tap()
                        } label: {
                            HStack {
                                Text(option.label)
                                    .font(.sakBody)
                                    .foregroundStyle(Palette.textPrimary)
                                Spacer()
                                if store.preferences.appearance == option {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Palette.accent)
                                }
                            }
                            .padding(.horizontal, Metrics.hPadding)
                            .padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < Preferences.Appearance.allCases.count - 1 {
                            CardDivider(leadingInset: Metrics.hPadding)
                        }
                    }
                }

                Text("Sakdrion Chat is designed light-first. Dark mode keeps the same layout with a dimmed palette.")
                    .font(.sakCaption)
                    .foregroundStyle(Palette.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.horizontal, Metrics.hPadding)
            .padding(.top, 12)
        }
        .background(Palette.background)
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy

struct PrivacySettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(spacing: 18) {
                Card {
                    toggleRow(icon: "eye.fill", title: "Last seen and online", subtitle: "Show when you were last active", isOn: $store.preferences.lastSeenVisible)
                    CardDivider()
                    toggleRow(icon: "checkmark.circle.fill", title: "Read receipts", subtitle: "Blue ticks when messages are read", isOn: $store.preferences.readReceipts)
                    CardDivider()
                    toggleRow(icon: "ellipsis.bubble.fill", title: "Typing indicators", subtitle: "Let others see when you type", isOn: $store.preferences.typingIndicators)
                }

                Card {
                    CardRow(icon: "hand.raised.fill", iconTint: Palette.danger, title: "Blocked contacts", subtitle: "None", showsChevron: true)
                    CardDivider()
                    CardRow(icon: "key.fill", iconTint: Palette.success, title: "Security codes", subtitle: "Verify end-to-end encryption", showsChevron: true)
                }

                Text("Messages and calls are end-to-end encrypted. Sakdrion cannot read or listen to them.")
                    .font(.sakCaption)
                    .foregroundStyle(Palette.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.horizontal, Metrics.hPadding)
            .padding(.top, 12)
        }
        .background(Palette.background)
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        CardRow(icon: icon, iconTint: Palette.accent, title: title, subtitle: subtitle) {
            Toggle("", isOn: isOn).labelsHidden()
        }
    }
}

// MARK: - Notifications

struct NotificationSettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(spacing: 18) {
                Card {
                    CardRow(icon: "text.bubble.fill", iconTint: Palette.accent, title: "Message previews", subtitle: "Show text in notifications") {
                        Toggle("", isOn: $store.preferences.messagePreviews).labelsHidden()
                    }
                    CardDivider()
                    CardRow(icon: "phone.fill", iconTint: Palette.success, title: "Call notifications", subtitle: "Ring for incoming calls") {
                        Toggle("", isOn: $store.preferences.callNotifications).labelsHidden()
                    }
                    CardDivider()
                    CardRow(icon: "speaker.wave.2.fill", iconTint: Palette.warning, title: "In-app sounds") {
                        Toggle("", isOn: $store.preferences.soundEnabled).labelsHidden()
                    }
                }
            }
            .padding(.horizontal, Metrics.hPadding)
            .padding(.top, 12)
        }
        .background(Palette.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Storage

struct StorageSettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let estimate = store.storageEstimate

        ScrollView {
            VStack(spacing: 18) {
                Card {
                    CardRow(icon: "text.bubble", iconTint: Palette.accent, title: "Messages", subtitle: "\(estimate.messages) stored on this device")
                    CardDivider()
                    CardRow(icon: "photo.stack", iconTint: Palette.success, title: "Media", subtitle: "\(estimate.media) items")
                    CardDivider()
                    CardRow(icon: "internaldrive", iconTint: Palette.textSecondary, title: "Approximate size", subtitle: Format.fileSize(estimate.bytes))
                }

                Card {
                    CardRow(icon: "arrow.down.circle.fill", iconTint: Palette.accent, title: "Auto-download media", subtitle: "Wi-Fi only", showsChevron: true)
                    CardDivider()
                    CardRow(icon: "chart.bar.fill", iconTint: Palette.warning, title: "Network usage", showsChevron: true)
                }
            }
            .padding(.horizontal, Metrics.hPadding)
            .padding(.top, 12)
        }
        .background(Palette.background)
        .navigationTitle("Storage and data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Palette.accentSoft)
                        .frame(width: 82, height: 82)
                        .overlay {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(Palette.accent)
                        }
                    Text("Sakdrion Chat")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text("Version \(SettingsView.appVersion)")
                        .font(.sakCaption)
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.top, 20)

                Card {
                    CardRow(icon: "doc.text.fill", iconTint: Palette.textSecondary, title: "Terms of Service", showsChevron: true)
                    CardDivider()
                    CardRow(icon: "hand.raised.fill", iconTint: Palette.textSecondary, title: "Privacy Policy", showsChevron: true)
                    CardDivider()
                    CardRow(icon: "chevron.left.forwardslash.chevron.right", iconTint: Palette.textSecondary, title: "Licences", showsChevron: true)
                }

                Text("Simple, private messaging and calling.\nMade with SwiftUI.")
                    .font(.sakCaption)
                    .foregroundStyle(Palette.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Metrics.hPadding)
            .padding(.bottom, 30)
        }
        .background(Palette.background)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .environment(AppStore.preview())
        .environment(CallCenter())
}
