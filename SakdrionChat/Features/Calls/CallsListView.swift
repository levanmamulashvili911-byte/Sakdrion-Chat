import SwiftUI

struct CallsListView: View {
    @Environment(AppStore.self) private var store
    @Environment(CallCenter.self) private var callCenter

    @State private var isPresentingNewCall = false
    @State private var isConfirmingClear = false
    @State private var searchText = ""

    private var calls: [CallRecord] {
        guard !searchText.isEmpty else { return store.calls }
        return store.calls.filter {
            store.contact($0.peerID)?.name.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if calls.isEmpty {
                    ScrollView {
                        EmptyStateView(
                            icon: "phone.badge.waveform",
                            title: "No calls yet",
                            message: "Voice and video calls you make will appear here."
                        )
                        .padding(.top, 60)
                    }
                    .background(Palette.background)
                } else {
                    list
                }
            }
            .background(Palette.background)
            .navigationTitle("Calls")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search calls")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingNewCall = true
                    } label: {
                        Image(systemName: "phone.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .accessibilityLabel("New call")
                }

                ToolbarItem(placement: .topBarLeading) {
                    if !store.calls.isEmpty {
                        Menu {
                            Button(role: .destructive) {
                                isConfirmingClear = true
                            } label: {
                                Label("Clear call log", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingNewCall) {
            NewCallSheet()
        }
        .confirmationDialog("Clear call log?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { store.clearCallHistory() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var list: some View {
        List {
            ForEach(calls) { record in
                CallRow(record: record) { kind in
                    guard let peer = store.contact(record.peerID) else { return }
                    callCenter.startCall(with: peer, chatID: record.chatID, kind: kind)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: Metrics.hPadding, bottom: 0, trailing: Metrics.hPadding))
                .listRowSeparator(.hidden)
                .listRowBackground(Palette.background)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        store.deleteCall(record.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Row

struct CallRow: View {
    @Environment(AppStore.self) private var store

    let record: CallRecord
    var onCall: (CallRecord.Kind) -> Void

    private var peer: Contact? { store.contact(record.peerID) }

    var body: some View {
        HStack(spacing: 12) {
            if let peer {
                AvatarView(contact: peer, size: 46)
            } else {
                AvatarView(initials: "?", colorSeed: 0, size: 46)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(peer?.name ?? "Unknown")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(record.isMissed ? Palette.danger : Palette.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Image(systemName: record.outcome.symbolName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(record.isMissed ? Palette.danger : Palette.textTertiary)

                    Text(subtitle)
                        .font(.sakCaption)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Button {
                onCall(record.kind)
            } label: {
                Image(systemName: record.kind.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 36, height: 36)
                    .background(Palette.accentSoft, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts = [record.outcome.label, Format.listStamp(record.date)]
        if record.duration > 0 {
            parts.append(Format.duration(record.duration))
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - New call

struct NewCallSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(CallCenter.self) private var callCenter
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Contacts") {
                    ForEach(store.searchContacts(searchText)) { contact in
                        HStack(spacing: 12) {
                            ContactRow(contact: contact)

                            Button {
                                place(contact, kind: .audio)
                            } label: {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Palette.accent)
                                    .frame(width: 34, height: 34)
                                    .background(Palette.accentSoft, in: Circle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                place(contact, kind: .video)
                            } label: {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Palette.accent)
                                    .frame(width: 34, height: 34)
                                    .background(Palette.accentSoft, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Palette.surface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .searchable(text: $searchText, prompt: "Search contacts")
            .navigationTitle("New call")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func place(_ contact: Contact, kind: CallRecord.Kind) {
        let chat = store.chat(with: contact.id)
        dismiss()
        callCenter.startCall(with: contact, chatID: chat.id, kind: kind)
    }
}

#Preview {
    CallsListView()
        .environment(AppStore.preview())
        .environment(CallCenter())
}
