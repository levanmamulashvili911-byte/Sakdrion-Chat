import SwiftUI

struct ChatInfoView: View {
    @Environment(AppStore.self) private var store
    @Environment(CallCenter.self) private var callCenter

    let chatID: UUID
    @Binding var path: [ChatRoute]

    @State private var isConfirmingClear = false
    @State private var isConfirmingDelete = false

    private var chat: Chat? { store.chat(chatID) }

    var body: some View {
        ScrollView {
            if let chat {
                VStack(spacing: 18) {
                    header(chat)
                    actionRow(chat)
                    detailsCard(chat)
                    if chat.isGroup { membersCard(chat) }
                    settingsCard(chat)
                    dangerCard(chat)
                }
                .padding(.horizontal, Metrics.hPadding)
                .padding(.bottom, 32)
            }
        }
        .background(Palette.background)
        .navigationTitle(chat?.isGroup == true ? "Group info" : "Contact info")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Clear all messages?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear messages", role: .destructive) {
                store.clearMessages(in: chatID)
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this chat?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete chat", role: .destructive) {
                store.deleteChat(chatID)
                path.removeAll()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Sections

    private func header(_ chat: Chat) -> some View {
        VStack(spacing: 10) {
            if chat.isGroup {
                AvatarView.group(seed: chat.colorSeed, size: Metrics.avatarLarge)
            } else if let peer = store.peer(for: chat) {
                AvatarView(contact: peer, size: Metrics.avatarLarge, showPresence: true)
            }

            Text(store.title(for: chat))
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)

            Text(chat.isGroup ? "\(chat.memberIDs.count) members" : (store.peer(for: chat)?.phoneNumber ?? ""))
                .font(.sakSubhead)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.top, 16)
    }

    private func actionRow(_ chat: Chat) -> some View {
        HStack(spacing: 10) {
            if !chat.isGroup, let peer = store.peer(for: chat) {
                infoAction(icon: "phone.fill", label: "Audio") {
                    callCenter.startCall(with: peer, chatID: chat.id, kind: .audio)
                }
                infoAction(icon: "video.fill", label: "Video") {
                    callCenter.startCall(with: peer, chatID: chat.id, kind: .video)
                }
            }
            infoAction(icon: chat.isMuted ? "bell.fill" : "bell.slash.fill", label: chat.isMuted ? "Unmute" : "Mute") {
                store.toggleMute(chat.id)
            }
            infoAction(icon: chat.isPinned ? "pin.slash.fill" : "pin.fill", label: chat.isPinned ? "Unpin" : "Pin") {
                store.togglePin(chat.id)
            }
        }
    }

    private func infoAction(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
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

    private func detailsCard(_ chat: Chat) -> some View {
        Card {
            if let peer = store.peer(for: chat) {
                CardRow(icon: "quote.bubble.fill", title: peer.about, subtitle: "About")
                CardDivider()
                CardRow(icon: "phone.fill", title: peer.phoneNumber, subtitle: "Mobile")
                CardDivider()
            }
            CardRow(
                icon: "photo.on.rectangle.angled",
                iconTint: Palette.success,
                title: "Media, links and docs",
                subtitle: "\(mediaCount(chat)) items",
                showsChevron: true
            )
            CardDivider()
            CardRow(
                icon: "lock.fill",
                iconTint: Palette.textSecondary,
                title: "Encryption",
                subtitle: "Messages are end-to-end encrypted"
            )
        }
    }

    private func membersCard(_ chat: Chat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "\(chat.memberIDs.count) members")
            Card {
                ForEach(Array(chat.memberIDs.enumerated()), id: \.element) { index, memberID in
                    if let member = store.contact(memberID) {
                        HStack(spacing: 12) {
                            AvatarView(contact: member, size: 40, showPresence: true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(memberID == store.meID ? "You" : member.name)
                                    .font(.sakBody)
                                    .foregroundStyle(Palette.textPrimary)
                                Text(member.about)
                                    .font(.sakCaption)
                                    .foregroundStyle(Palette.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, Metrics.hPadding)
                        .padding(.vertical, 9)

                        if index < chat.memberIDs.count - 1 {
                            CardDivider(leadingInset: Metrics.hPadding + 52)
                        }
                    }
                }
            }
        }
    }

    private func settingsCard(_ chat: Chat) -> some View {
        Card {
            CardRow(icon: "archivebox.fill", iconTint: Palette.textSecondary, title: chat.isArchived ? "Unarchive chat" : "Archive chat") {
                EmptyView()
            }
            .onTapGesture { store.toggleArchive(chat.id) }

            CardDivider()

            CardRow(icon: "magnifyingglass", iconTint: Palette.accent, title: "Search in chat", showsChevron: true)
        }
    }

    private func dangerCard(_ chat: Chat) -> some View {
        Card {
            destructiveRow(icon: "trash", title: "Clear messages") {
                isConfirmingClear = true
            }
            CardDivider()
            destructiveRow(icon: "hand.raised.fill", title: chat.isGroup ? "Exit group" : "Block contact") {
                Haptics.warning()
            }
            CardDivider()
            destructiveRow(icon: "xmark.bin.fill", title: "Delete chat") {
                isConfirmingDelete = true
            }
        }
    }

    private func destructiveRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Palette.danger.opacity(0.13))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.danger)
                    }
                Text(title)
                    .font(.sakBody)
                    .foregroundStyle(Palette.danger)
                Spacer()
            }
            .padding(.horizontal, Metrics.hPadding)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func mediaCount(_ chat: Chat) -> Int {
        chat.messages.filter { $0.attachment != nil }.count
    }
}

#Preview {
    let store = AppStore.preview()
    return NavigationStack {
        ChatInfoView(chatID: store.activeChats[0].id, path: .constant([]))
    }
    .environment(store)
    .environment(CallCenter())
}
