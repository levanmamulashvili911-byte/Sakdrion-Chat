import SwiftUI

struct ChatRow: View {
    @Environment(AppStore.self) private var store

    let chat: Chat

    private var unread: Int { chat.unreadCount(for: store.meID) }
    private var isTyping: Bool { store.typingChatIDs.contains(chat.id) }

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(store.title(for: chat))
                        .font(.system(size: 16.5, weight: unread > 0 ? .semibold : .medium))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)

                    if chat.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textTertiary)
                    }

                    Spacer(minLength: 4)

                    if let last = chat.lastMessage {
                        Text(Format.listStamp(last.date))
                            .font(.system(size: 12.5, weight: unread > 0 ? .semibold : .regular))
                            .foregroundStyle(unread > 0 ? Palette.accent : Palette.textTertiary)
                    }
                }

                HStack(spacing: 6) {
                    secondLine

                    Spacer(minLength: 4)

                    if chat.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textTertiary)
                            .rotationEffect(.degrees(45))
                    }

                    if unread > 0 {
                        CountBadge(count: unread, isMuted: chat.isMuted)
                    }
                }
                .frame(minHeight: 18)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var avatar: some View {
        Group {
            if chat.isGroup {
                AvatarView.group(seed: chat.colorSeed)
            } else if let peer = store.peer(for: chat) {
                AvatarView(contact: peer, showPresence: true)
            } else {
                AvatarView(initials: "?", colorSeed: chat.colorSeed)
            }
        }
    }

    @ViewBuilder
    private var secondLine: some View {
        if isTyping {
            HStack(spacing: 6) {
                TypingDots()
                Text("typing…")
                    .font(.sakSubhead)
                    .foregroundStyle(Palette.accent)
            }
        } else if !chat.draft.isEmpty {
            HStack(spacing: 4) {
                Text("Draft:")
                    .font(.sakSubhead)
                    .foregroundStyle(Palette.danger)
                Text(chat.draft)
                    .font(.sakSubhead)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
        } else if let last = chat.lastMessage {
            HStack(spacing: 5) {
                if last.senderID == store.meID, !last.isSystem, !last.isDeleted {
                    MessageStatusIcon(status: last.status, tint: last.status == .read ? Palette.accent : Palette.textTertiary)
                }

                if chat.isGroup, !last.isSystem, last.senderID != store.meID {
                    Text("\(store.contact(last.senderID)?.firstName ?? "Someone"):")
                        .font(.sakSubhead)
                        .foregroundStyle(Palette.textSecondary)
                }

                if let attachment = last.attachment, !last.isDeleted {
                    Image(systemName: attachment.symbolName)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textTertiary)
                }

                Text(last.preview)
                    .font(.sakSubhead)
                    .foregroundStyle(last.isDeleted ? Palette.textTertiary : Palette.textSecondary)
                    .italic(last.isDeleted)
                    .lineLimit(1)
            }
        } else {
            Text("No messages yet")
                .font(.sakSubhead)
                .foregroundStyle(Palette.textTertiary)
        }
    }
}

/// Delivery ticks. Read receipts turn the accent colour, matching the bubbles.
struct MessageStatusIcon: View {
    let status: MessageStatus
    var tint: Color = Palette.textTertiary

    var body: some View {
        Group {
            switch status {
            case .sending:
                Image(systemName: "clock")
            case .sent:
                Image(systemName: "checkmark")
            case .delivered, .read:
                doubleCheck
            }
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(tint)
    }

    private var doubleCheck: some View {
        HStack(spacing: -3.5) {
            Image(systemName: "checkmark")
            Image(systemName: "checkmark")
        }
    }
}

#Preview {
    let store = AppStore.preview()
    return VStack(spacing: 0) {
        ForEach(store.activeChats) { chat in
            ChatRow(chat: chat)
                .padding(.horizontal, Metrics.hPadding)
        }
    }
    .background(Palette.background)
    .environment(store)
}
