import Foundation
import SwiftUI
import ServiceManagement

@MainActor
final class PrayerStore: ObservableObject {
    @Published private(set) var location: LocationConfig
    @Published var reminderMinutes: Int { didSet { defaults.set(reminderMinutes, forKey: Keys.interval) } }
    @Published var playSound: Bool { didSet { defaults.set(playSound, forKey: Keys.sound) } }
    @Published private(set) var days: [String: DayTimes] = [:]
    @Published private(set) var prayed: Set<String> = []
    @Published private(set) var now = Date()
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    let notifier = Notifier()

    private let defaults = UserDefaults.standard
    private var lastNotified: [String: Date] = [:]
    private var lastFetchAttempt: Date?
    private var timer: Timer?

    private enum Keys {
        static let location = "location"
        static let interval = "reminderMinutes"
        static let sound = "playSound"
        static let prayed = "prayed"
        static let cache = "cachedDays"
        static let cacheLocation = "cachedLocation"
    }

    init() {
        if let data = defaults.data(forKey: Keys.location),
           let loc = try? JSONDecoder().decode(LocationConfig.self, from: data) {
            location = loc
        } else {
            location = .berlinDiyanet
        }
        reminderMinutes = defaults.object(forKey: Keys.interval) as? Int ?? 15
        playSound = defaults.object(forKey: Keys.sound) as? Bool ?? true
        prayed = Set(defaults.stringArray(forKey: Keys.prayed) ?? [])

        if let data = defaults.data(forKey: Keys.cache),
           let cachedFor = defaults.data(forKey: Keys.cacheLocation),
           (try? JSONDecoder().decode(LocationConfig.self, from: cachedFor)) == location,
           let cached = try? JSONDecoder().decode([DayTimes].self, from: data) {
            days = Dictionary(cached.map { ($0.date, $0) }, uniquingKeysWith: { _, b in b })
        }

        notifier.onPrayed = { [weak self] id in self?.setPrayed(id, true) }
        notifier.onLater = { [weak self] id in self?.lastNotified[id] = Date() }
        notifier.setup()

        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        Task { await refresh() }
        tick()
    }

    // MARK: - Location

    func setLocation(_ loc: LocationConfig) {
        guard loc != location else { return }
        location = loc
        if let data = try? JSONEncoder().encode(loc) { defaults.set(data, forKey: Keys.location) }
        days = [:]
        lastNotified = [:]
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        lastFetchAttempt = Date()
        defer { isLoading = false }
        let loc = location
        do {
            let fetched = try await TimesProvider.fetch(loc)
            guard loc == location else { return }
            days = Dictionary(fetched.map { ($0.date, $0) }, uniquingKeysWith: { _, b in b })
            lastError = nil
            defaults.set(try? JSONEncoder().encode(fetched), forKey: Keys.cache)
            defaults.set(try? JSONEncoder().encode(loc), forKey: Keys.cacheLocation)
        } catch {
            lastError = "Zeiten konnten nicht geladen werden: \(error.localizedDescription)"
        }
        tick()
    }

    // MARK: - Windows

    func windows(for day: String) -> [PrayerWindow] {
        guard let t = days[day] else { return [] }
        let nextDay = DateKeys.key(for: Calendar.current.date(byAdding: .day, value: 1, to: DateKeys.date(day: day, time: "12:00")!)!)

        func at(_ time: String) -> Date? { DateKeys.date(day: day, time: time) }

        var result: [PrayerWindow] = []
        for prayer in Prayer.allCases {
            guard let start = at(t.time(of: prayer)) else { continue }
            let end: Date? = switch prayer {
            case .sabah: at(t.gunes)
            case .ogle: at(t.ikindi)
            case .ikindi: at(t.aksam)
            case .aksam: at(t.yatsi)
            case .yatsi: days[nextDay].flatMap { DateKeys.date(day: nextDay, time: $0.imsak) }
                ?? start.addingTimeInterval(6 * 3600)
            }
            if let end, end > start {
                result.append(PrayerWindow(prayer: prayer, day: day, start: start, end: end))
            }
        }
        return result
    }

    var todayKey: String { DateKeys.key(for: now) }

    var todayWindows: [PrayerWindow] { windows(for: todayKey) }

    private var relevantWindows: [PrayerWindow] {
        let yesterday = DateKeys.key(for: Calendar.current.date(byAdding: .day, value: -1, to: now)!)
        let tomorrow = DateKeys.key(for: Calendar.current.date(byAdding: .day, value: 1, to: now)!)
        return windows(for: yesterday) + windows(for: todayKey) + windows(for: tomorrow)
    }

    var activeWindow: PrayerWindow? { relevantWindows.first { $0.contains(now) } }
    var nextWindow: PrayerWindow? { relevantWindows.first { $0.start > now } }

    /// The active prayer, if it has not been prayed yet.
    var openWindow: PrayerWindow? {
        guard let w = activeWindow, !prayed.contains(w.id) else { return nil }
        return w
    }

    // MARK: - Tracking

    func isPrayed(_ w: PrayerWindow) -> Bool { prayed.contains(w.id) }

    func setPrayed(_ id: String, _ value: Bool) {
        if value { prayed.insert(id) } else { prayed.remove(id) }
        // Keep roughly the last 90 days.
        let cutoff = DateKeys.key(for: Date().addingTimeInterval(-90 * 86400))
        prayed = prayed.filter { $0 >= cutoff }
        defaults.set(Array(prayed), forKey: Keys.prayed)
        if value { notifier.remove(id: id) }
    }

    var todayDone: Int { todayWindows.filter(isPrayed).count }

    /// Consecutive full days (all 5 prayers) ending yesterday, plus today if already complete.
    var streak: Int {
        let cal = Calendar.current
        var count = todayDone == 5 ? 1 : 0
        var date = cal.date(byAdding: .day, value: -1, to: now)!
        while Prayer.allCases.allSatisfy({ prayed.contains("\(DateKeys.key(for: date))|\($0.rawValue)") }) {
            count += 1
            date = cal.date(byAdding: .day, value: -1, to: date)!
        }
        return count
    }

    // MARK: - Reminder loop

    private func tick() {
        now = Date()

        // Refetch when today is missing or the cache runs out within 3 days (at most hourly).
        let soon = DateKeys.key(for: now.addingTimeInterval(3 * 86400))
        if !isLoading, days[todayKey] == nil || days[soon] == nil,
           lastFetchAttempt.map({ now.timeIntervalSince($0) > 3600 }) ?? true {
            Task { await refresh() }
        }

        guard let w = openWindow else { return }
        let remaining = Int(w.end.timeIntervalSince(now) / 60)

        if let last = lastNotified[w.id] {
            if now.timeIntervalSince(last) >= Double(reminderMinutes * 60) {
                notifier.send(window: w, kind: .reminder(remainingMinutes: remaining), sound: playSound)
                lastNotified[w.id] = now
            }
        } else {
            let justStarted = now.timeIntervalSince(w.start) < 120
            notifier.send(window: w, kind: justStarted ? .adhan : .reminder(remainingMinutes: remaining), sound: playSound)
            lastNotified[w.id] = now
        }
    }

    // MARK: - Launch at login

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                lastError = "Autostart: \(error.localizedDescription)"
            }
            objectWillChange.send()
        }
    }
}
