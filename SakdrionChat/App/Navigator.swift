import Foundation
import Observation

/// Cross-tab navigation. Views ask the navigator to open a chat; the tab switch
/// and the push both happen from one place instead of being reinvented per screen.
@MainActor
@Observable
final class Navigator {
    var selectedTab: AppTab = .chats
    /// Set when another tab wants the chats stack to open a conversation.
    var pendingChatID: UUID?

    func openChat(_ chatID: UUID) {
        pendingChatID = chatID
        selectedTab = .chats
    }

    func consumePendingChat() -> UUID? {
        defer { pendingChatID = nil }
        return pendingChatID
    }
}
