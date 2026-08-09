import SwiftUI

enum ChatRoute: Hashable {
    case conversation(UUID)
    case info(UUID)
    case archive
}

struct ChatListView: View {
    @Environment(AppStore.self) private var store
    @Environment(Navigator.self) private var navigator

    @State private var path: [ChatRoute] = []
    @State private var searchText = ""
    @State private var isPresentingNewChat = false
    @State private var chatPendingDeletion: Chat?

    private var chats: [Chat] {
        searchText.isEmpty ? store.activeChats : store.searchChats(searchText)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if chats.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(Palette.background)
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search chats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .accessibilityLabel("New chat")
                }
            }
            .navigationDestination(for: ChatRoute.self) { route in
                switch route {
                case .conversation(let id):
                    ConversationView(chatID: id, path: $path)
                case .info(let id):
                    ChatInfoView(chatID: id, path: $path)
                case .archive:
                    ArchivedChatsView(path: $path)
                }
            }
        }
        .onChange(of: navigator.pendingChatID) { _, newValue in
            guard newValue != nil, let chatID = navigator.consumePendingChat() else { return }
            path = [.conversation(chatID)]
        }
        .sheet(isPresented: $isPresentingNewChat) {
            NewChatView { chatID in
                isPresentingNewChat = false
                path.append(.conversation(chatID))
            }
        }
        .confirmationDialog(
            "Delete this chat?",
            isPresented: Binding(get: { chatPendingDeletion != nil }, set: { if !$0 { chatPendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete chat", role: .destructive) {
                if let chat = chatPendingDeletion { store.deleteChat(chat.id) }
                chatPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { chatPendingDeletion = nil }
        } message: {
            Text("Messages in this chat will be removed from this device.")
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            if searchText.isEmpty, !store.archivedChats.isEmpty {
                archiveRow
            }

            ForEach(chats) { chat in
                Button {
                    path.append(.conversation(chat.id))
                } label: {
                    ChatRow(chat: chat)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: Metrics.hPadding, bottom: 0, trailing: Metrics.hPadding))
                .listRowSeparator(.hidden)
                .listRowBackground(Palette.background)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        chatPendingDeletion = chat
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        store.toggleArchive(chat.id)
                    } label: {
                        Label(chat.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
                    }
                    .tint(Palette.textSecondary)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        store.togglePin(chat.id)
                    } label: {
                        Label(chat.isPinned ? "Unpin" : "Pin", systemImage: chat.isPinned ? "pin.slash" : "pin")
                    }
                    .tint(Palette.accent)

                    Button {
                        store.toggleMute(chat.id)
                    } label: {
                        Label(chat.isMuted ? "Unmute" : "Mute", systemImage: chat.isMuted ? "bell" : "bell.slash")
                    }
                    .tint(Palette.warning)
                }
                .contextMenu {
                    chatContextMenu(chat)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
    }

    private var archiveRow: some View {
        Button {
            path.append(.archive)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: Metrics.avatarSmall, height: Metrics.avatarSmall)
                    .background(Palette.surfaceSunken, in: Circle())

                Text("Archived")
                    .font(.sakBody)
                    .foregroundStyle(Palette.textPrimary)

                Spacer()

                Text("\(store.archivedChats.count)")
                    .font(.sakCaption)
                    .foregroundStyle(Palette.textTertiary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: Metrics.hPadding, bottom: 0, trailing: Metrics.hPadding))
        .listRowSeparator(.hidden)
        .listRowBackground(Palette.background)
    }

    @ViewBuilder
    private func chatContextMenu(_ chat: Chat) -> some View {
        Button {
            store.togglePin(chat.id)
        } label: {
            Label(chat.isPinned ? "Unpin chat" : "Pin chat", systemImage: chat.isPinned ? "pin.slash" : "pin")
        }

        Button {
            store.toggleMute(chat.id)
        } label: {
            Label(chat.isMuted ? "Unmute" : "Mute notifications", systemImage: chat.isMuted ? "bell" : "bell.slash")
        }

        Button {
            store.toggleArchive(chat.id)
        } label: {
            Label(chat.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
        }

        Button(role: .destructive) {
            chatPendingDeletion = chat
        } label: {
            Label("Delete chat", systemImage: "trash")
        }
    }

    private var emptyState: some View {
        ScrollView {
            EmptyStateView(
                icon: searchText.isEmpty ? "bubble.left.and.bubble.right" : "magnifyingglass",
                title: searchText.isEmpty ? "No chats yet" : "No results",
                message: searchText.isEmpty
                    ? "Start a conversation and it will show up here."
                    : "No chats or messages match “\(searchText)”."
            )
            .padding(.top, 60)
        }
        .background(Palette.background)
    }
}

// MARK: - Archived

struct ArchivedChatsView: View {
    @Environment(AppStore.self) private var store
    @Binding var path: [ChatRoute]

    var body: some View {
        List {
            ForEach(store.archivedChats) { chat in
                Button {
                    path.append(.conversation(chat.id))
                } label: {
                    ChatRow(chat: chat)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: Metrics.hPadding, bottom: 0, trailing: Metrics.hPadding))
                .listRowSeparator(.hidden)
                .listRowBackground(Palette.background)
                .swipeActions(edge: .trailing) {
                    Button {
                        store.toggleArchive(chat.id)
                    } label: {
                        Label("Unarchive", systemImage: "archivebox")
                    }
                    .tint(Palette.accent)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Archived")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if store.archivedChats.isEmpty {
                EmptyStateView(
                    icon: "archivebox",
                    title: "Nothing archived",
                    message: "Archived chats stay out of your main list until someone writes again."
                )
            }
        }
    }
}

#Preview {
    ChatListView()
        .environment(AppStore.preview())
        .environment(CallCenter())
        .environment(Navigator())
}
