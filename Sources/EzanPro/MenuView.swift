import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var store: PrayerStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let open = store.openWindow {
                openBanner(open)
            } else if let next = store.nextWindow {
                Text("Nächstes: **\(next.prayer.name)** in \(countdown(to: next.start))")
                    .font(.callout)
            }

            Divider()

            if store.todayWindows.isEmpty {
                Text(store.isLoading ? "Lade Zeiten …" : "Keine Zeiten für heute.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    ForEach(store.todayWindows) { w in
                        PrayerRow(window: w)
                    }
                }
            }

            if let error = store.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Divider()

            HStack {
                Label("Heute \(store.todayDone)/5", systemImage: "checkmark.circle")
                Spacer()
                Label("\(store.streak) Tage Serie", systemImage: "flame")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Button("Einstellungen …") {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Zeiten neu laden")
                Spacer()
                Button("Beenden") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.location.cityName).font(.headline)
                Text("\(store.location.source.label) · \(store.now.formatted(date: .complete, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.isLoading { ProgressView().controlSize(.small) }
        }
    }

    private func openBanner(_ w: PrayerWindow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hast du **\(w.prayer.name)** gebetet?")
            Text("Noch \(countdown(to: w.end)) Zeit")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                store.setPrayed(w.id, true)
            } label: {
                Label("Ja, gebetet", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(10)
        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
    }

    private func countdown(to date: Date) -> String {
        let minutes = max(0, Int(date.timeIntervalSince(store.now) / 60))
        return minutes >= 60 ? "\(minutes / 60) Std. \(minutes % 60) Min." : "\(minutes) Min."
    }
}

private struct PrayerRow: View {
    @EnvironmentObject private var store: PrayerStore
    let window: PrayerWindow

    var body: some View {
        let isActive = window.contains(store.now)
        let started = window.start <= store.now
        let done = store.isPrayed(window)

        HStack {
            Button {
                store.setPrayed(window.id, !done)
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? .green : (started ? .orange : .secondary))
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(!started)
            .help(started ? (done ? "Als nicht gebetet markieren" : "Als gebetet markieren") : "Noch nicht Zeit")

            Text(window.prayer.name).fontWeight(isActive ? .semibold : .regular)
            Spacer()
            Text(window.start.formatted(date: .omitted, time: .shortened))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isActive ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6))
    }
}
