import Foundation

// MARK: - People

struct Contact: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var phoneNumber: String
    var about: String = "Available"
    /// Index into `Palette.avatarTints` so an avatar keeps its colour everywhere.
    var colorSeed: Int = 0
    var isOnline: Bool = false
    var lastSeen: Date = .now

    var initials: String {
        let parts = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
        return parts.joined().uppercased()
    }

    var firstName: String {
        String(name.split(separator: " ").first ?? Substring(name))
    }
}

// MARK: - Messages

enum MessageStatus: String, Codable, Hashable {
    case sending, sent, delivered, read

    var symbolName: String {
        switch self {
        case .sending: "clock"
        case .sent: "checkmark"
        case .delivered, .read: "checkmark.circle.fill"
        }
    }
}

struct Attachment: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, Hashable {
        case photo, voice, document, location
    }

    var id: UUID = UUID()
    var kind: Kind
    /// Photo caption, document file name, or place name.
    var name: String = ""
    /// Voice note length in seconds.
    var duration: TimeInterval?
    /// Document size in bytes.
    var byteSize: Int?
    /// Drives the placeholder gradient for photos so it stays stable across launches.
    var colorSeed: Int = 0
    /// Normalised bar heights (0...1) for voice note waveforms.
    var waveform: [Double] = []

    var previewText: String {
        switch kind {
        case .photo: name.isEmpty ? "Photo" : name
        case .voice: "Voice message"
        case .document: name.isEmpty ? "Document" : name
        case .location: name.isEmpty ? "Location" : name
        }
    }

    var symbolName: String {
        switch kind {
        case .photo: "photo"
        case .voice: "waveform"
        case .document: "doc"
        case .location: "mappin.and.ellipse"
        }
    }
}

struct Reaction: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var emoji: String
    var authorID: UUID
}

struct Message: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var senderID: UUID
    var text: String = ""
    var attachment: Attachment?
    var date: Date = .now
    var status: MessageStatus = .sent
    var replyToID: UUID?
    var reactions: [Reaction] = []
    var isEdited: Bool = false
    var isDeleted: Bool = false
    /// System notices ("Messages are end-to-end encrypted", "Missed call", …).
    var isSystem: Bool = false

    var preview: String {
        if isDeleted { return "This message was deleted" }
        if let attachment, text.isEmpty { return attachment.previewText }
        if let attachment, !text.isEmpty { return "\(attachment.previewText) · \(text)" }
        return text
    }

    /// Groups reactions by emoji, preserving first-seen order.
    var groupedReactions: [(emoji: String, count: Int)] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for reaction in reactions {
            if counts[reaction.emoji] == nil { order.append(reaction.emoji) }
            counts[reaction.emoji, default: 0] += 1
        }
        return order.map { ($0, counts[$0] ?? 0) }
    }
}

// MARK: - Chats

struct Chat: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var isGroup: Bool = false
    /// Group name. One-to-one chats take their title from the other participant.
    var groupName: String?
    var memberIDs: [UUID]
    var messages: [Message] = []
    var isPinned: Bool = false
    var isMuted: Bool = false
    var isArchived: Bool = false
    var draft: String = ""
    var lastReadDate: Date = .distantPast
    var colorSeed: Int = 0

    var lastMessage: Message? { messages.last }

    var sortDate: Date { messages.last?.date ?? .distantPast }

    func unreadCount(for meID: UUID) -> Int {
        messages.filter { $0.senderID != meID && !$0.isSystem && $0.date > lastReadDate }.count
    }

    func otherMemberID(besides meID: UUID) -> UUID? {
        memberIDs.first { $0 != meID }
    }
}

// MARK: - Calls

struct CallRecord: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, Hashable {
        case audio, video

        var symbolName: String { self == .audio ? "phone.fill" : "video.fill" }
    }

    enum Outcome: String, Codable, Hashable {
        case incoming, outgoing, missed, declined

        var symbolName: String {
            switch self {
            case .incoming: "arrow.down.left"
            case .outgoing: "arrow.up.right"
            case .missed, .declined: "arrow.down.left"
            }
        }

        var label: String {
            switch self {
            case .incoming: "Incoming"
            case .outgoing: "Outgoing"
            case .missed: "Missed"
            case .declined: "Declined"
            }
        }
    }

    var id: UUID = UUID()
    var peerID: UUID
    var chatID: UUID?
    var kind: Kind
    var outcome: Outcome
    var date: Date = .now
    var duration: TimeInterval = 0

    var isMissed: Bool { outcome == .missed || outcome == .declined }
}

// MARK: - Preferences

struct Preferences: Codable, Hashable {
    enum Appearance: String, Codable, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    var appearance: Appearance = .light
    var readReceipts: Bool = true
    var typingIndicators: Bool = true
    var lastSeenVisible: Bool = true
    var messagePreviews: Bool = true
    var callNotifications: Bool = true
    var soundEnabled: Bool = true
    var autoReplyDemo: Bool = true
}

// MARK: - Formatting

enum Format {
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// Compact stamp for chat and call lists: time today, "Yesterday", weekday, then date.
    static func listStamp(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return time(date) }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if let days = calendar.dateComponents([.day], from: date, to: .now).day, days < 7 {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// Full-width separator shown between days inside a conversation.
    static func daySeparator(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if let days = calendar.dateComponents([.day], from: date, to: .now).day, days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(.dateTime.day().month(.wide).year())
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func lastSeen(_ date: Date, isOnline: Bool) -> String {
        if isOnline { return "online" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "last seen today at \(time(date))" }
        if calendar.isDateInYesterday(date) { return "last seen yesterday at \(time(date))" }
        return "last seen \(date.formatted(.dateTime.day().month(.abbreviated)))"
    }

    static func fileSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
