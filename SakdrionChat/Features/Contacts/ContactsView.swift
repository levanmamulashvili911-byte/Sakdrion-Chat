import SwiftUI

struct ContactsView: View {
    @Environment(AppStore.self) private var store

    @State private var searchText = ""
    @State private var selected: Contact?

    private var grouped: [(letter: String, contacts: [Contact])] {
        let matches = store.searchContacts(searchText)
        let buckets = Dictionary(grouping: matches) { contact in
            String(contact.name.prefix(1)).uppercased()
        }
        return buckets
            .map { (letter: $0.key, contacts: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.letter < $1.letter }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        AvatarView(contact: store.me, size: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(store.me.name) (You)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Palette.textPrimary)
                            Text(store.me.phoneNumber)
                                .font(.sakCaption)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Palette.surface)

                ForEach(grouped, id: \.letter) { group in
                    Section(group.letter) {
                        ForEach(group.contacts) { contact in
                            Button {
                                selected = contact
                            } label: {
                                ContactRow(contact: contact)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Palette.surface)
                }

                Section {
                    Button {
                        Haptics.tap()
                    } label: {
                        Label("Invite friends to Sakdrion", systemImage: "square.and.arrow.up")
                            .font(.sakBody)
                            .foregroundStyle(Palette.accent)
                    }
                }
                .listRowBackground(Palette.surface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .searchable(text: $searchText, prompt: "Search contacts")
            .navigationTitle("Contacts")
            .overlay {
                if grouped.isEmpty {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.questionmark",
                        title: "No contacts found",
                        message: "Nobody matches “\(searchText)”."
                    )
                    .background(Palette.background)
                }
            }
        }
        .sheet(item: $selected) { contact in
            ContactDetailView(contact: contact)
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Detail

struct ContactDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(CallCenter.self) private var callCenter
    @Environment(Navigator.self) private var navigator
    @Environment(\.dismiss) private var dismiss

    let contact: Contact

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 10) {
                        AvatarView(contact: contact, size: Metrics.avatarLarge, showPresence: true)
                        Text(contact.name)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                        Text(Format.lastSeen(contact.lastSeen, isOnline: contact.isOnline))
                            .font(.sakSubhead)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .padding(.top, 20)

                    HStack(spacing: 10) {
                        action(icon: "bubble.left.fill", label: "Message") {
                            let chat = store.chat(with: contact.id)
                            dismiss()
                            navigator.openChat(chat.id)
                        }
                        action(icon: "phone.fill", label: "Audio") {
                            let chat = store.chat(with: contact.id)
                            dismiss()
                            callCenter.startCall(with: contact, chatID: chat.id, kind: .audio)
                        }
                        action(icon: "video.fill", label: "Video") {
                            let chat = store.chat(with: contact.id)
                            dismiss()
                            callCenter.startCall(with: contact, chatID: chat.id, kind: .video)
                        }
                    }

                    Card {
                        CardRow(icon: "quote.bubble.fill", title: contact.about, subtitle: "About")
                        CardDivider()
                        CardRow(icon: "phone.fill", title: contact.phoneNumber, subtitle: "Mobile")
                        CardDivider()
                        CardRow(
                            icon: "lock.fill",
                            iconTint: Palette.textSecondary,
                            title: "Encryption",
                            subtitle: "Tap to verify the security code"
                        )
                    }
                }
                .padding(.horizontal, Metrics.hPadding)
                .padding(.bottom, 30)
            }
            .background(Palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func action(icon: String, label: String, perform: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            perform()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Palette.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerMedium, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContactsView()
        .environment(AppStore.preview())
        .environment(CallCenter())
        .environment(Navigator())
}
