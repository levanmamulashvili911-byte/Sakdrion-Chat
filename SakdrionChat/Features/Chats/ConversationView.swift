import SwiftUI
import UIKit

struct ConversationView: View {
    @Environment(AppStore.self) private var store
    @Environment(CallCenter.self) private var callCenter

    let chatID: UUID
    @Binding var path: [ChatRoute]

    @State private var draft = ""
    @State private var replyingTo: Message?
    @State private var editingMessage: Message?
    @State private var isPresentingAttachments = false
    @State private var deleteTarget: Message?

    private static let bottomAnchor = "conversation-bottom"
    private static let quickReactions = ["👍", "❤️", "😂", "😮", "🙏", "🔥"]

    private var chat: Chat? { store.chat(chatID) }
    private var isTyping: Bool { store.typingChatIDs.contains(chatID) }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            if chat != nil {
                messageScroll
            } else {
                EmptyStateView(
                    icon: "questionmark.bubble",
                    title: "Chat unavailable",
                    message: "This conversation is no longer on this device."
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Palette.surface, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if chat != nil { composer }
        }
        .sheet(isPresented: $isPresentingAttachments) {
            AttachmentSheet { kind in
                sendAttachment(kind)
            }
        }
        .confirmationDialog(
            "Delete message?",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            titleVisibility: .visible
        ) {
            if let target = deleteTarget, target.senderID == store.meID {
                Button("Delete for everyone", role: .destructive) {
                    store.deleteMessage(target.id, in: chatID, forEveryone: true)
                    deleteTarget = nil
                }
            }
            Button("Delete for me", role: .destructive) {
                if let target = deleteTarget {
                    store.deleteMessage(target.id, in: chatID, forEveryone: false)
                }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        }
        .onAppear {
            draft = chat?.draft ?? ""
            store.markRead(chatID)
        }
        .onDisappear {
            store.setDraft(draft, in: chatID)
        }
    }

    // MARK: - Messages

    private var messageScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    encryptionNotice

                    ForEach(rows) { row in
                        rowView(row)
                            .id(row.id)
                    }

                    if isTyping {
                        typingRow
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchor)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear { scroll(proxy, animated: false) }
            .onChange(of: chat?.messages.count ?? 0) { _, _ in
                store.markRead(chatID)
                scroll(proxy, animated: true)
            }
            .onChange(of: isTyping) { _, _ in
                scroll(proxy, animated: true)
            }
        }
    }

    private var encryptionNotice: some View {
        Text("Messages are end-to-end encrypted. Only people in this chat can read them.")
            .font(.system(size: 12))
            .foregroundStyle(Palette.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Palette.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
    }

    @ViewBuilder
    private func rowView(_ row: ConversationRow) -> some View {
        switch row {
        case .day(_, let label):
            DaySeparator(label: label)
        case .system(let message):
            SystemNotice(text: message.text)
        case .message(let data):
            MessageBubble(
                message: data.message,
                isMine: data.isMine,
                senderName: data.senderName,
                replyContext: data.replyContext,
                isTailEnd: data.isTailEnd
            )
            .padding(.top, data.isRunStart ? 6 : 0)
            .contextMenu { messageMenu(for: data.message) }
        }
    }

    private var typingRow: some View {
        HStack {
            HStack(spacing: 6) {
                TypingDots()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Palette.bubbleIncoming)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Palette.separator, lineWidth: 1)
            }
            Spacer(minLength: 48)
        }
        .padding(.top, 4)
        .transition(.opacity)
    }

    @ViewBuilder
    private func messageMenu(for message: Message) -> some View {
        if !message.isDeleted {
            ControlGroup {
                ForEach(Self.quickReactions, id: \.self) { emoji in
                    Button(emoji) {
                        store.toggleReaction(emoji, on: message.id, in: chatID)
                        Haptics.tap()
                    }
                }
            }
            .controlGroupStyle(.compactMenu)

            Button {
                replyingTo = message
                editingMessage = nil
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }

            if !message.text.isEmpty {
                Button {
                    UIPasteboard.general.string = message.text
                    Haptics.tap()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }

            if message.senderID == store.meID, !message.text.isEmpty {
                Button {
                    editingMessage = message
                    replyingTo = nil
                    draft = message.text
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }

        Button(role: .destructive) {
            deleteTarget = message
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Composer

    private var composer: some View {
        Composer(
            text: $draft,
            replyBanner: banner,
            isEditing: editingMessage != nil,
            onCancelBanner: {
                if editingMessage != nil { draft = "" }
                replyingTo = nil
                editingMessage = nil
            },
            onSend: send,
            onAttach: { isPresentingAttachments = true },
            onVoiceNote: { duration, levels in
                let attachment = Attachment(
                    kind: .voice,
                    duration: duration,
                    colorSeed: Int(duration),
                    waveform: levels
                )
                store.send(text: "", attachment: attachment, to: chatID, replyTo: replyingTo?.id)
                replyingTo = nil
            }
        )
    }

    private var banner: ReplyContext? {
        if let editingMessage {
            return ReplyContext(author: "Editing message", preview: editingMessage.text)
        }
        if let replyingTo {
            return ReplyContext(
                author: store.senderName(replyingTo.senderID),
                preview: replyingTo.preview
            )
        }
        return nil
    }

    private func send() {
        if let editingMessage {
            store.edit(messageID: editingMessage.id, in: chatID, newText: draft)
            self.editingMessage = nil
            draft = ""
            return
        }
        store.send(text: draft, to: chatID, replyTo: replyingTo?.id)
        draft = ""
        replyingTo = nil
    }

    private func sendAttachment(_ kind: Attachment.Kind) {
        let seed = Int.random(in: 0...5)
        let attachment: Attachment
        switch kind {
        case .photo:
            attachment = Attachment(kind: .photo, name: "", colorSeed: seed)
        case .document:
            attachment = Attachment(kind: .document, name: "Notes.pdf", byteSize: 184_320, colorSeed: seed)
        case .location:
            attachment = Attachment(kind: .location, name: "Current location", colorSeed: seed)
        case .voice:
            attachment = Attachment(kind: .voice, duration: 8, colorSeed: seed, waveform: MockData.waveform(seed: seed))
        }
        store.send(text: draft, attachment: attachment, to: chatID, replyTo: replyingTo?.id)
        draft = ""
        replyingTo = nil
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Button {
                path.append(.info(chatID))
            } label: {
                header
            }
            .buttonStyle(.plain)
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                startCall(kind: .video)
            } label: {
                Image(systemName: "video")
                    .font(.system(size: 16, weight: .semibold))
            }
            .disabled(chat?.isGroup == true)

            Button {
                startCall(kind: .audio)
            } label: {
                Image(systemName: "phone")
                    .font(.system(size: 16, weight: .semibold))
            }
            .disabled(chat?.isGroup == true)
        }
    }

    @ViewBuilder
    private var header: some View {
        if let chat {
            HStack(spacing: 9) {
                if chat.isGroup {
                    AvatarView.group(seed: chat.colorSeed, size: 32)
                } else if let peer = store.peer(for: chat) {
                    AvatarView(contact: peer, size: 32, showPresence: true)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(store.title(for: chat))
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)

                    if isTyping {
                        Text("typing…")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.accent)
                    } else {
                        Text(store.presenceLine(for: chat))
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func startCall(kind: CallRecord.Kind) {
        guard let chat, let peer = store.peer(for: chat) else { return }
        callCenter.startCall(with: peer, chatID: chat.id, kind: kind)
    }

    // MARK: - Rows

    private var rows: [ConversationRow] {
        guard let chat else { return [] }
        var result: [ConversationRow] = []
        let calendar = Calendar.current
        var previousDay: Date?

        for (index, message) in chat.messages.enumerated() {
            let day = calendar.startOfDay(for: message.date)
            if previousDay != day {
                result.append(.day(id: "\(Int(day.timeIntervalSince1970))", label: Format.daySeparator(message.date)))
                previousDay = day
            }

            if message.isSystem {
                result.append(.system(message))
                continue
            }

            let previous = index > 0 ? chat.messages[index - 1] : nil
            let next = index + 1 < chat.messages.count ? chat.messages[index + 1] : nil
            let isMine = message.senderID == store.meID
            let isRunStart = previous == nil
                || previous?.senderID != message.senderID
                || previous?.isSystem == true
                || !calendar.isDate(previous?.date ?? .distantPast, inSameDayAs: message.date)
            let isTailEnd = next == nil || next?.senderID != message.senderID || next?.isSystem == true

            var replyContext: ReplyContext?
            if let replyID = message.replyToID, let original = chat.messages.first(where: { $0.id == replyID }) {
                replyContext = ReplyContext(
                    author: store.senderName(original.senderID),
                    preview: original.preview
                )
            }

            result.append(.message(MessageRowData(
                message: message,
                isMine: isMine,
                senderName: (chat.isGroup && !isMine && isRunStart) ? store.contact(message.senderID)?.name : nil,
                replyContext: replyContext,
                isRunStart: isRunStart,
                isTailEnd: isTailEnd
            )))
        }
        return result
    }

    private func scroll(_ proxy: ScrollViewProxy, animated: Bool) {
        let action = { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
        if animated {
            withAnimation(.easeOut(duration: 0.25)) { action() }
        } else {
            action()
        }
    }
}

// MARK: - Row model

struct MessageRowData {
    let message: Message
    let isMine: Bool
    let senderName: String?
    let replyContext: ReplyContext?
    let isRunStart: Bool
    let isTailEnd: Bool
}

enum ConversationRow: Identifiable {
    case day(id: String, label: String)
    case system(Message)
    case message(MessageRowData)

    var id: String {
        switch self {
        case .day(let id, _): "day-\(id)"
        case .system(let message): "system-\(message.id.uuidString)"
        case .message(let data): data.message.id.uuidString
        }
    }
}

// MARK: - Small pieces

struct DaySeparator: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Palette.surface, in: Capsule())
            .overlay { Capsule().strokeBorder(Palette.separator, lineWidth: 1) }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }
}

struct SystemNotice: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Palette.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Palette.surfaceSunken, in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }
}

#Preview {
    let store = AppStore.preview()
    return NavigationStack {
        ConversationView(chatID: store.activeChats[0].id, path: .constant([]))
    }
    .environment(store)
    .environment(CallCenter())
}
