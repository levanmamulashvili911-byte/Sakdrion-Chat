import Foundation

/// Seed content so the app has something to show on first launch.
///
/// This is the only place that fabricates data — every other layer reads from
/// `AppStore`, so wiring a real backend means replacing this file and the
/// simulation hooks in `AppStore`.
enum MockData {
    static func minutesAgo(_ minutes: Double) -> Date {
        Date.now.addingTimeInterval(-minutes * 60)
    }

    static func hoursAgo(_ hours: Double) -> Date {
        minutesAgo(hours * 60)
    }

    static func daysAgo(_ days: Double) -> Date {
        hoursAgo(days * 24)
    }

    /// Stable pseudo-random waveform so a voice note looks the same every launch.
    static func waveform(seed: Int, count: Int = 34) -> [Double] {
        var value = UInt64(abs(seed) &+ 7)
        return (0..<count).map { _ in
            value = value &* 6364136223846793005 &+ 1442695040888963407
            let unit = Double((value >> 33) % 1000) / 1000.0
            return 0.22 + unit * 0.78
        }
    }

    static func contacts() -> [Contact] {
        [
            Contact(name: "Nino Beridze", phoneNumber: "+995 599 12 34 56", about: "Designing things", colorSeed: 0, isOnline: true, lastSeen: .now),
            Contact(name: "Luka Kapanadze", phoneNumber: "+995 577 88 21 04", about: "At the studio 🎧", colorSeed: 1, isOnline: false, lastSeen: minutesAgo(24)),
            Contact(name: "Maya Ellis", phoneNumber: "+44 7700 900312", about: "Coffee first", colorSeed: 2, isOnline: true, lastSeen: .now),
            Contact(name: "Tamar Gelashvili", phoneNumber: "+995 555 40 77 19", about: "Busy", colorSeed: 3, isOnline: false, lastSeen: hoursAgo(3)),
            Contact(name: "Daniel Cross", phoneNumber: "+1 415 555 0182", about: "Available", colorSeed: 4, isOnline: false, lastSeen: hoursAgo(9)),
            Contact(name: "Sofia Marchetti", phoneNumber: "+39 351 555 2210", about: "Ciao!", colorSeed: 5, isOnline: false, lastSeen: daysAgo(1.2)),
            Contact(name: "Giorgi Tsereteli", phoneNumber: "+995 591 63 90 22", about: "Running late, always", colorSeed: 1, isOnline: false, lastSeen: daysAgo(2.4)),
            Contact(name: "Anna Voss", phoneNumber: "+49 152 555 8890", about: "Hiking 🏔️", colorSeed: 3, isOnline: false, lastSeen: daysAgo(4))
        ]
    }

    /// Builds the starter chats and call history for a freshly created account.
    static func conversations(me: Contact, contacts: [Contact]) -> (chats: [Chat], calls: [CallRecord]) {
        guard contacts.count >= 7 else { return ([], []) }
        let nino = contacts[0]
        let luka = contacts[1]
        let maya = contacts[2]
        let tamar = contacts[3]
        let daniel = contacts[4]
        let sofia = contacts[5]
        let giorgi = contacts[6]

        var chats: [Chat] = []

        // MARK: Nino — active, unread, mixed media
        var ninoChat = Chat(isGroup: false, memberIDs: [me.id, nino.id], colorSeed: 0)
        ninoChat.isPinned = true
        ninoChat.lastReadDate = minutesAgo(90)
        let ninoPhoto = Message(
            senderID: nino.id,
            attachment: Attachment(kind: .photo, name: "Morning at the lake", colorSeed: 2),
            date: minutesAgo(96),
            status: .read
        )
        ninoChat.messages = [
            Message(senderID: me.id, text: "Messages and calls are end-to-end encrypted. No one outside of this chat can read or listen to them.", date: daysAgo(6), isSystem: true),
            Message(senderID: nino.id, text: "Morning! Did the new build land?", date: minutesAgo(140), status: .read),
            Message(senderID: me.id, text: "Yep, pushed it last night. Light theme is in.", date: minutesAgo(136), status: .read),
            ninoPhoto,
            Message(senderID: me.id, text: "That view is unfair", date: minutesAgo(94), status: .read, replyToID: ninoPhoto.id, reactions: [Reaction(emoji: "😍", authorID: nino.id)]),
            Message(senderID: nino.id, attachment: Attachment(kind: .voice, duration: 14, colorSeed: 5, waveform: waveform(seed: 11)), date: minutesAgo(12), status: .delivered),
            Message(senderID: nino.id, text: "Call me when you're free?", date: minutesAgo(11), status: .delivered)
        ]
        chats.append(ninoChat)

        // MARK: Design group
        var groupChat = Chat(isGroup: true, groupName: "Design Sync", memberIDs: [me.id, nino.id, maya.id, daniel.id], colorSeed: 3)
        groupChat.lastReadDate = minutesAgo(40)
        groupChat.messages = [
            Message(senderID: maya.id, text: "Pushed the spacing tokens — 4pt base everywhere now.", date: hoursAgo(5), status: .read),
            Message(senderID: daniel.id, text: "Much better. The chat rows breathe.", date: hoursAgo(4.6), status: .read),
            Message(senderID: me.id, text: "Agreed. I'll match the composer padding tonight.", date: hoursAgo(4.2), status: .read),
            Message(senderID: nino.id, attachment: Attachment(kind: .document, name: "Sakdrion-Specs-v4.pdf", byteSize: 2_411_724), date: minutesAgo(38), status: .delivered),
            Message(senderID: nino.id, text: "Latest specs, review before Thursday 🙏", date: minutesAgo(37), status: .delivered, reactions: [Reaction(emoji: "👍", authorID: maya.id), Reaction(emoji: "👍", authorID: daniel.id)])
        ]
        chats.append(groupChat)

        // MARK: Maya — short, read
        var mayaChat = Chat(isGroup: false, memberIDs: [me.id, maya.id], colorSeed: 2)
        mayaChat.lastReadDate = .now
        mayaChat.messages = [
            Message(senderID: maya.id, text: "Lunch at 1?", date: hoursAgo(7), status: .read),
            Message(senderID: me.id, text: "Works. The place with the terrace.", date: hoursAgo(6.9), status: .read),
            Message(senderID: maya.id, text: "Perfect ☀️", date: hoursAgo(6.8), status: .read)
        ]
        chats.append(mayaChat)

        // MARK: Tamar — missed call thread
        var tamarChat = Chat(isGroup: false, memberIDs: [me.id, tamar.id], colorSeed: 3)
        tamarChat.isMuted = true
        tamarChat.lastReadDate = .now
        tamarChat.messages = [
            Message(senderID: tamar.id, text: "Missed voice call", date: hoursAgo(3.2), isSystem: true),
            Message(senderID: tamar.id, text: "Sorry, was on the metro. Try again later?", date: hoursAgo(3.1), status: .read)
        ]
        chats.append(tamarChat)

        // MARK: Daniel — location
        var danielChat = Chat(isGroup: false, memberIDs: [me.id, daniel.id], colorSeed: 4)
        danielChat.lastReadDate = .now
        danielChat.draft = "Sounds good, I'll be there"
        danielChat.messages = [
            Message(senderID: daniel.id, attachment: Attachment(kind: .location, name: "Riverside Studio", colorSeed: 1), date: daysAgo(1.1), status: .read),
            Message(senderID: daniel.id, text: "Here's the spot for Friday.", date: daysAgo(1.09), status: .read)
        ]
        chats.append(danielChat)

        // MARK: Sofia — older
        var sofiaChat = Chat(isGroup: false, memberIDs: [me.id, sofia.id], colorSeed: 5)
        sofiaChat.lastReadDate = .now
        sofiaChat.messages = [
            Message(senderID: me.id, text: "Landed! Thanks again for the recommendations.", date: daysAgo(3.4), status: .read),
            Message(senderID: sofia.id, text: "Anytime 🇮🇹", date: daysAgo(3.3), status: .read)
        ]
        chats.append(sofiaChat)

        // MARK: Giorgi — archived
        var giorgiChat = Chat(isGroup: false, memberIDs: [me.id, giorgi.id], colorSeed: 1)
        giorgiChat.isArchived = true
        giorgiChat.lastReadDate = .now
        giorgiChat.messages = [
            Message(senderID: giorgi.id, text: "Old thread — moving this to email.", date: daysAgo(12), status: .read)
        ]
        chats.append(giorgiChat)

        let calls: [CallRecord] = [
            CallRecord(peerID: nino.id, chatID: ninoChat.id, kind: .video, outcome: .outgoing, date: minutesAgo(58), duration: 742),
            CallRecord(peerID: tamar.id, chatID: tamarChat.id, kind: .audio, outcome: .missed, date: hoursAgo(3.2)),
            CallRecord(peerID: maya.id, chatID: mayaChat.id, kind: .audio, outcome: .incoming, date: hoursAgo(8), duration: 128),
            CallRecord(peerID: daniel.id, chatID: danielChat.id, kind: .video, outcome: .outgoing, date: daysAgo(1.3), duration: 2_260),
            CallRecord(peerID: nino.id, chatID: ninoChat.id, kind: .audio, outcome: .incoming, date: daysAgo(2.1), duration: 64),
            CallRecord(peerID: sofia.id, chatID: sofiaChat.id, kind: .audio, outcome: .declined, date: daysAgo(4.5))
        ]

        return (chats, calls)
    }

    /// Canned replies for the demo auto-responder.
    static let replyPool: [String] = [
        "Got it 👍",
        "Makes sense — let's do that.",
        "On it, give me ten minutes.",
        "Haha, fair enough.",
        "Can we talk about it on a call?",
        "Just sent you the details.",
        "Perfect, thanks!",
        "I'll check and get back to you.",
        "Sounds good to me.",
        "Sorry, was away from my phone."
    ]
}
