import Foundation
import Observation
import SwiftUI

/// Single source of truth for people, chats, calls and preferences.
///
/// The view layer never mutates models directly — it calls intents here, which
/// keeps persistence and the delivery/reply simulation in one place.
@MainActor
@Observable
final class AppStore {
    private(set) var currentUser: Contact?
    private(set) var contacts: [Contact] = []
    private(set) var chats: [Chat] = []
    private(set) var calls: [CallRecord] = []
    var preferences = Preferences() {
        didSet { scheduleSave() }
    }

    /// Chats where the other side is currently "typing". Transient, never persisted.
    private(set) var typingChatIDs: Set<UUID> = []

    private let storage: SnapshotStorage
    private var pendingSave: Task<Void, Never>?

    init(storage: SnapshotStorage = .shared, snapshot: AppSnapshot? = nil) {
        self.storage = storage
        let loaded = snapshot ?? storage.load()
        if let loaded {
            currentUser = loaded.currentUser
            contacts = loaded.contacts
            chats = loaded.chats
            calls = loaded.calls
            preferences = loaded.preferences
        }
    }

    // MARK: - Identity

    var isSignedIn: Bool { currentUser != nil }

    var meID: UUID { currentUser?.id ?? UUID() }

    var me: Contact {
        currentUser ?? Contact(name: "You", phoneNumber: "", colorSeed: 0)
    }

    /// Creates the account and seeds the demo history.
    func completeSignIn(name: String, phoneNumber: String, about: String) {
        let user = Contact(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber,
            about: about.isEmpty ? "Available" : about,
            colorSeed: 0,
            isOnline: true
        )
        currentUser = user
        let seededContacts = MockData.contacts()
        let seeded = MockData.conversations(me: user, contacts: seededContacts)
        contacts = seededContacts
        chats = seeded.chats
        calls = seeded.calls
        save()
    }

    func signOut() {
        pendingSave?.cancel()
        currentUser = nil
        contacts = []
        chats = []
        calls = []
        typingChatIDs = []
        preferences = Preferences()
        storage.clear()
    }

    func updateProfile(name: String, about: String) {
        guard var user = currentUser else { return }
        user.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        user.about = about
        currentUser = user
        scheduleSave()
    }

    // MARK: - Lookup

    func contact(_ id: UUID) -> Contact? {
        if id == currentUser?.id { return currentUser }
        return contacts.first { $0.id == id }
    }

    func chat(_ id: UUID) -> Chat? {
        chats.first { $0.id == id }
    }

    func title(for chat: Chat) -> String {
        if chat.isGroup { return chat.groupName ?? "Group" }
        guard let otherID = chat.otherMemberID(besides: meID) else { return "You" }
        return contact(otherID)?.name ?? "Unknown"
    }

    func peer(for chat: Chat) -> Contact? {
        guard !chat.isGroup, let otherID = chat.otherMemberID(besides: meID) else { return nil }
        return contact(otherID)
    }

    /// Header subtitle: presence for one-to-one chats, member list for groups.
    func presenceLine(for chat: Chat) -> String {
        if chat.isGroup {
            let names = chat.memberIDs.compactMap { id -> String? in
                id == meID ? "You" : contact(id)?.firstName
            }
            return names.joined(separator: ", ")
        }
        guard let peer = peer(for: chat) else { return "" }
        guard preferences.lastSeenVisible else { return peer.about }
        return Format.lastSeen(peer.lastSeen, isOnline: peer.isOnline)
    }

    func senderName(_ id: UUID) -> String {
        id == meID ? "You" : (contact(id)?.name ?? "Unknown")
    }

    // MARK: - Chat lists

    var activeChats: [Chat] {
        chats
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.sortDate > rhs.sortDate
            }
    }

    var archivedChats: [Chat] {
        chats.filter(\.isArchived).sorted { $0.sortDate > $1.sortDate }
    }

    var totalUnread: Int {
        chats.filter { !$0.isArchived && !$0.isMuted }.reduce(0) { $0 + $1.unreadCount(for: meID) }
    }

    var missedCallCount: Int {
        calls.filter(\.isMissed).count
    }

    func searchChats(_ query: String) -> [Chat] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return activeChats }
        return chats.filter { chat in
            if title(for: chat).localizedCaseInsensitiveContains(trimmed) { return true }
            return chat.messages.contains { $0.text.localizedCaseInsensitiveContains(trimmed) }
        }
        .sorted { $0.sortDate > $1.sortDate }
    }

    func searchContacts(_ query: String) -> [Contact] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = contacts.sorted { $0.name < $1.name }
        guard !trimmed.isEmpty else { return sorted }
        return sorted.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.phoneNumber.localizedCaseInsensitiveContains(trimmed)
        }
    }

    // MARK: - Chat lifecycle

    /// Returns the existing one-to-one chat with a contact, creating it if needed.
    @discardableResult
    func chat(with contactID: UUID) -> Chat {
        if let existing = chats.first(where: { !$0.isGroup && $0.memberIDs.contains(contactID) && $0.memberIDs.contains(meID) }) {
            return existing
        }
        let seed = contact(contactID)?.colorSeed ?? 0
        var chat = Chat(isGroup: false, memberIDs: [meID, contactID], colorSeed: seed)
        chat.lastReadDate = .now
        chats.append(chat)
        scheduleSave()
        return chat
    }

    @discardableResult
    func createGroup(name: String, memberIDs: [UUID]) -> Chat {
        var members = memberIDs
        if !members.contains(meID) { members.insert(meID, at: 0) }
        var chat = Chat(isGroup: true, groupName: name, memberIDs: members, colorSeed: Palette.tintIndex(for: name))
        chat.lastReadDate = .now
        chat.messages = [
            Message(senderID: meID, text: "You created the group “\(name)”", date: .now, isSystem: true)
        ]
        chats.append(chat)
        scheduleSave()
        return chat
    }

    func togglePin(_ chatID: UUID) {
        guard let index = chats.firstIndex(where: { $0.id == chatID }) else { return }
        chats[index].isPinned.toggle()
        scheduleSave()
    }

    func toggleMute(_ chatID: UUID) {
        guard let index = chats.firstIndex(where: { $0.id == chatID }) else { return }
        chats[index].isMuted.toggle()
        scheduleSave()
    }

    func toggleArchive(_ chatID: UUID) {
        guard let index = chats.firstIndex(where: { $0.id == chatID }) else { return }
        chats[index].isArchived.toggle()
        if chats[index].isArchived { chats[index].isPinned = false }
        scheduleSave()
    }

    func deleteChat(_ chatID: UUID) {
        chats.removeAll { $0.id == chatID }
        typingChatIDs.remove(chatID)
        scheduleSave()
    }

    func clearMessages(in chatID: UUID) {
        guard let index = chats.firstIndex(where: { $0.id == chatID }) else { return }
        chats[index].messages.removeAll()
        scheduleSave()
    }

    func setDraft(_ text: String, in chatID: UUID) {
        guard let index = chats.firstIndex(where: { $0.id == chatID }), chats[index].draft != text else { return }
        chats[index].draft = text
        scheduleSave()
    }

    func markRead(_ chatID: UUID) {
        guard let index = chats.firstIndex(where: { $0.id == chatID }) else { return }
        guard chats[index].lastReadDate < (chats[index].messages.last?.date ?? .distantPast) else { return }
        chats[index].lastReadDate = .now
        scheduleSave()
    }

    // MARK: - Messages

    @discardableResult
    func send(text: String, attachment: Attachment? = nil, to chatID: UUID, replyTo: UUID? = nil) -> Message? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || attachment != nil else { return nil }
        guard let index = chats.firstIndex(where: { $0.id == chatID }) else { return nil }

        let message = Message(
            senderID: meID,
            text: trimmed,
            attachment: attachment,
            date: .now,
            status: .sending,
            replyToID: replyTo
        )
        chats[index].messages.append(message)
        chats[index].draft = ""
        chats[index].lastReadDate = .now
        scheduleSave()

        simulateDelivery(of: message.id, in: chatID)
        return message
    }

    func edit(messageID: UUID, in chatID: UUID, newText: String) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let chatIndex = chats.firstIndex(where: { $0.id == chatID }),
              let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.id == messageID })
        else { return }
        chats[chatIndex].messages[messageIndex].text = trimmed
        chats[chatIndex].messages[messageIndex].isEdited = true
        scheduleSave()
    }

    /// Tombstones a message the way the real clients do, so replies still resolve.
    func deleteMessage(_ messageID: UUID, in chatID: UUID, forEveryone: Bool) {
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatID }),
              let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.id == messageID })
        else { return }
        if forEveryone {
            chats[chatIndex].messages[messageIndex].isDeleted = true
            chats[chatIndex].messages[messageIndex].text = ""
            chats[chatIndex].messages[messageIndex].attachment = nil
            chats[chatIndex].messages[messageIndex].reactions = []
        } else {
            chats[chatIndex].messages.remove(at: messageIndex)
        }
        scheduleSave()
    }

    func toggleReaction(_ emoji: String, on messageID: UUID, in chatID: UUID) {
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatID }),
              let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.id == messageID })
        else { return }
        let mine = chats[chatIndex].messages[messageIndex].reactions
            .firstIndex { $0.authorID == meID && $0.emoji == emoji }
        if let mine {
            chats[chatIndex].messages[messageIndex].reactions.remove(at: mine)
        } else {
            chats[chatIndex].messages[messageIndex].reactions.removeAll { $0.authorID == meID }
            chats[chatIndex].messages[messageIndex].reactions.append(Reaction(emoji: emoji, authorID: meID))
        }
        scheduleSave()
    }

    func message(_ id: UUID, in chatID: UUID) -> Message? {
        chat(chatID)?.messages.first { $0.id == id }
    }

    // MARK: - Calls

    func logCall(peerID: UUID, chatID: UUID?, kind: CallRecord.Kind, outcome: CallRecord.Outcome, duration: TimeInterval) {
        let record = CallRecord(peerID: peerID, chatID: chatID, kind: kind, outcome: outcome, date: .now, duration: duration)
        calls.insert(record, at: 0)

        if let chatID, let index = chats.firstIndex(where: { $0.id == chatID }) {
            let label: String
            switch outcome {
            case .missed: label = kind == .audio ? "Missed voice call" : "Missed video call"
            case .declined: label = "Call declined"
            case .incoming: label = "Incoming \(kind.rawValue) call · \(Format.duration(duration))"
            case .outgoing: label = "Outgoing \(kind.rawValue) call · \(Format.duration(duration))"
            }
            chats[index].messages.append(Message(senderID: meID, text: label, date: .now, isSystem: true))
        }
        scheduleSave()
    }

    func clearCallHistory() {
        calls.removeAll()
        scheduleSave()
    }

    func deleteCall(_ id: UUID) {
        calls.removeAll { $0.id == id }
        scheduleSave()
    }

    var recentCallPeers: [Contact] {
        var seen: Set<UUID> = []
        return calls.compactMap { record -> Contact? in
            guard seen.insert(record.peerID).inserted else { return nil }
            return contact(record.peerID)
        }
    }

    // MARK: - Simulation
    //
    // Stands in for a transport layer: status transitions, typing indicators and
    // a canned reply so the UI can be exercised end to end without a server.

    private func simulateDelivery(of messageID: UUID, in chatID: UUID) {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(420))
            self?.setStatus(.sent, messageID: messageID, chatID: chatID)
            try? await Task.sleep(for: .milliseconds(700))
            self?.setStatus(.delivered, messageID: messageID, chatID: chatID)

            guard let self, self.preferences.autoReplyDemo else { return }
            guard let chat = self.chat(chatID), !chat.memberIDs.isEmpty else { return }
            await self.simulateReply(in: chatID)
        }
    }

    private func setStatus(_ status: MessageStatus, messageID: UUID, chatID: UUID) {
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatID }),
              let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.id == messageID })
        else { return }
        chats[chatIndex].messages[messageIndex].status = status
        scheduleSave()
    }

    private func simulateReply(in chatID: UUID) async {
        guard let chat = chat(chatID),
              let responderID = chat.memberIDs.filter({ $0 != meID }).randomElement()
        else { return }

        if preferences.typingIndicators {
            typingChatIDs.insert(chatID)
        }
        try? await Task.sleep(for: .milliseconds(Int.random(in: 1_400...2_600)))
        typingChatIDs.remove(chatID)

        guard let index = chats.firstIndex(where: { $0.id == chatID }) else { return }

        // The peer reading the thread marks everything we sent as read.
        if preferences.readReceipts {
            for messageIndex in chats[index].messages.indices where chats[index].messages[messageIndex].senderID == meID {
                if chats[index].messages[messageIndex].status != .read {
                    chats[index].messages[messageIndex].status = .read
                }
            }
        }

        let reply = Message(
            senderID: responderID,
            text: MockData.replyPool.randomElement() ?? "👍",
            date: .now,
            status: .delivered
        )
        chats[index].messages.append(reply)
        scheduleSave()
    }

    /// Used by Settings to demo the incoming-call screen.
    func randomPeer() -> Contact? {
        contacts.randomElement()
    }

    /// Restores the seeded chats and call history without signing out.
    func resetDemoData() {
        guard let user = currentUser else { return }
        let seededContacts = MockData.contacts()
        let seeded = MockData.conversations(me: user, contacts: seededContacts)
        contacts = seededContacts
        chats = seeded.chats
        calls = seeded.calls
        typingChatIDs = []
        save()
    }

    var storageEstimate: (messages: Int, media: Int, bytes: Int) {
        let messages = chats.reduce(0) { $0 + $1.messages.count }
        let media = chats.reduce(0) { $0 + $1.messages.filter { $0.attachment != nil }.count }
        let bytes = chats.reduce(0) { partial, chat in
            partial + chat.messages.reduce(0) { $0 + $1.text.utf8.count + ($1.attachment?.byteSize ?? 0) }
        }
        return (messages, media, bytes)
    }

    // MARK: - Persistence

    private var snapshot: AppSnapshot {
        AppSnapshot(
            currentUser: currentUser,
            contacts: contacts,
            chats: chats,
            calls: calls,
            preferences: preferences
        )
    }

    /// Coalesces bursts of edits (typing, status transitions) into one write.
    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self else { return }
            self.storage.save(self.snapshot)
        }
    }

    func save() {
        pendingSave?.cancel()
        storage.save(snapshot)
    }

    // MARK: - Previews

    static func preview() -> AppStore {
        let user = Contact(name: "Alex Rivers", phoneNumber: "+995 555 00 11 22", about: "Building Sakdrion", colorSeed: 0, isOnline: true)
        let contacts = MockData.contacts()
        let seeded = MockData.conversations(me: user, contacts: contacts)
        let snapshot = AppSnapshot(
            currentUser: user,
            contacts: contacts,
            chats: seeded.chats,
            calls: seeded.calls,
            preferences: Preferences()
        )
        return AppStore(storage: SnapshotStorage(fileName: "preview-store.json"), snapshot: snapshot)
    }
}
