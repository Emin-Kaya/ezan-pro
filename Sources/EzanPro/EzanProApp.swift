import SwiftUI

@main
struct EzanProApp: App {
    @StateObject private var store = PrayerStore()
    // Not a @StateObject: those are created lazily, but update checks should start at launch.
    private let updater = Updater()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(store)
                .environmentObject(updater)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        Window("Ezan Pro – Einstellungen", id: "settings") {
            SettingsView()
                .environmentObject(store)
                .environmentObject(updater)
        }
        .windowResizability(.contentSize)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: PrayerStore

    var body: some View {
        if let open = store.openWindow {
            // Prayer is due: show how much time is left to pray it.
            Image(systemName: "exclamationmark.circle.fill")
            Text("\(open.prayer.name) noch \(Self.duration(until: open.end, from: store.now))")
        } else if let next = store.nextWindow {
            Image(systemName: "moon.stars.fill")
            Text("\(next.prayer.name) in \(Self.duration(until: next.start, from: store.now))")
        } else {
            Image(systemName: "moon.stars")
        }
    }

    static func duration(until date: Date, from now: Date) -> String {
        let minutes = Int(date.timeIntervalSince(now) / 60)
        if minutes < 1 { return "<1 Min" }
        if minutes < 60 { return "\(minutes) Min" }
        return "\(minutes / 60) Std \(minutes % 60) Min"
    }
}
