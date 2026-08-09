import SwiftUI

@main
struct SakdrionChatApp: App {
    @State private var store = AppStore()
    @State private var callCenter = CallCenter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(callCenter)
                .tint(Palette.accent)
                .preferredColorScheme(colorScheme)
                .onAppear { callCenter.attach(store: store) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.save() }
        }
    }

    private var colorScheme: ColorScheme? {
        switch store.preferences.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
