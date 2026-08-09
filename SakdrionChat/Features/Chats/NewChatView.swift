import SwiftUI

struct NewChatView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var onOpenChat: (UUID) -> Void

    @State private var searchText = ""
    @State private var isCreatingGroup = false

    private var contacts: [Contact] { store.searchContacts(searchText) }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section {
                        actionRow(icon: "person.2.fill", title: "New group") {
                            isCreatingGroup = true
                        }
                        actionRow(icon: "person.crop.circle.badge.plus", title: "New contact") {
                            Haptics.tap()
                        }
                    }
                    .listRowBackground(Palette.surface)
                }

                Section("Contacts on Sakdrion") {
                    ForEach(contacts) { contact in
                        Button {
                            let chat = store.chat(with: contact.id)
                            onOpenChat(chat.id)
                        } label: {
                            ContactRow(contact: contact)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Palette.surface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .searchable(text: $searchText, prompt: "Search name or number")
            .navigationTitle("New chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $isCreatingGroup) {
                NewGroupView(onCreated: onOpenChat)
            }
        }
    }

    private func actionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                Text(title)
                    .font(.sakBody)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Group creation

struct NewGroupView: View {
    @Environment(AppStore.self) private var store

    var onCreated: (UUID) -> Void

    @State private var groupName = ""
    @State private var selected: Set<UUID> = []
    @State private var searchText = ""

    private var contacts: [Contact] { store.searchContacts(searchText) }

    var body: some View {
        List {
            Section {
                TextField("Group name", text: $groupName)
                    .font(.sakBody)
            }
            .listRowBackground(Palette.surface)

            Section("Add members (\(selected.count))") {
                ForEach(contacts) { contact in
                    Button {
                        if selected.contains(contact.id) {
                            selected.remove(contact.id)
                        } else {
                            selected.insert(contact.id)
                        }
                        Haptics.tap()
                    } label: {
                        HStack {
                            ContactRow(contact: contact)
                            Image(systemName: selected.contains(contact.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 19))
                                .foregroundStyle(selected.contains(contact.id) ? Palette.accent : Palette.separator)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowBackground(Palette.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .searchable(text: $searchText, prompt: "Search contacts")
        .navigationTitle("New group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Create") {
                    let chat = store.createGroup(name: trimmedName, memberIDs: Array(selected))
                    onCreated(chat.id)
                }
                .fontWeight(.semibold)
                .disabled(trimmedName.isEmpty || selected.isEmpty)
            }
        }
    }

    private var trimmedName: String {
        groupName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Shared row

struct ContactRow: View {
    let contact: Contact
    var showsPresence: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(contact: contact, size: 42, showPresence: showsPresence)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                Text(contact.about)
                    .font(.sakCaption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    NewChatView { _ in }
        .environment(AppStore.preview())
}
