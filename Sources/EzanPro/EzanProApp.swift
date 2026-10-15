import SwiftUI

@main
struct EzanProApp: App {
    @StateObject private var store = PrayerStore()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        Window("Ezan Pro – Einstellungen", id: "settings") {
            SettingsView()
                .environmentObject(store)
        }
        .windowResizability(.contentSize)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: PrayerStore

    var body: some View {
        if let open = store.openWindow {
            Image(systemName: "exclamationmark.circle.fill")
            Text("\(open.prayer.name) offen")
        } else if let next = store.nextWindow {
            Image(systemName: "moon.stars.fill")
            Text("\(next.prayer.name) \(next.start.formatted(date: .omitted, time: .shortened))")
        } else {
            Image(systemName: "moon.stars")
        }
    }
}
