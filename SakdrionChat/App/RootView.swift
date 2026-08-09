import SwiftUI

enum AppTab: Hashable {
    case chats, calls, contacts, settings
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(CallCenter.self) private var callCenter

    @State private var navigator = Navigator()

    var body: some View {
        Group {
            if store.isSignedIn {
                mainTabs
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .environment(navigator)
        .animation(.easeInOut(duration: 0.25), value: store.isSignedIn)
        .fullScreenCover(isPresented: callPresentation) {
            CallScreen()
        }
    }

    private var mainTabs: some View {
        TabView(selection: $navigator.selectedTab) {
            ChatListView()
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right.fill") }
                .badge(store.totalUnread)
                .tag(AppTab.chats)

            CallsListView()
                .tabItem { Label("Calls", systemImage: "phone.fill") }
                .tag(AppTab.calls)

            ContactsView()
                .tabItem { Label("Contacts", systemImage: "person.2.fill") }
                .tag(AppTab.contacts)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Palette.surface, for: .tabBar)
    }

    /// The call screen is owned by `CallCenter`; SwiftUI only mirrors its state.
    private var callPresentation: Binding<Bool> {
        Binding(get: { callCenter.isPresentingFullScreen }, set: { _ in })
    }
}

#Preview {
    RootView()
        .environment(AppStore.preview())
        .environment(CallCenter())
}
