import Foundation
import AppKit
import UserNotifications

@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    enum Kind {
        case adhan
        case reminder(remainingMinutes: Int)
    }

    var onPrayed: ((String) -> Void)?
    var onLater: ((String) -> Void)?

    private let center = UNUserNotificationCenter.current()
    private static let category = "PRAYER"
    private static let prayedAction = "PRAYED"
    private static let laterAction = "LATER"

    func setup() {
        center.delegate = self
        let prayed = UNNotificationAction(identifier: Self.prayedAction, title: "✅ Gebetet", options: [])
        let later = UNNotificationAction(identifier: Self.laterAction, title: "⏰ Noch nicht", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.category, actions: [prayed, later], intentIdentifiers: [], options: [])
        ])
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func send(window w: PrayerWindow, kind: Kind, sound: Bool) {
        let content = UNMutableNotificationContent()
        switch kind {
        case .adhan:
            content.title = "🕌 \(w.prayer.name) vakti"
            content.body = "Es ist Zeit für \(w.prayer.name) (\(w.prayer.germanName)). Hast du gebetet?"
        case .reminder(let minutes):
            let left = minutes >= 60 ? "\(minutes / 60) Std. \(minutes % 60) Min." : "\(minutes) Min."
            if minutes <= 20 {
                content.title = "⚠️ \(w.prayer.name) – nur noch \(left)!"
                content.body = "Die Zeit für \(w.prayer.name) läuft bald ab. Jetzt beten?"
            } else {
                content.title = "Hast du \(w.prayer.name) gebetet?"
                content.body = "Noch \(left) Zeit für \(w.prayer.name)."
            }
        }
        content.categoryIdentifier = Self.category
        content.userInfo = ["id": w.id]
        content.interruptionLevel = .timeSensitive
        if sound { content.sound = .default }

        // Same identifier per prayer, so a new reminder replaces the previous one.
        center.add(UNNotificationRequest(identifier: w.id, content: content, trigger: nil))
    }

    /// Sends a test notification and returns a human-readable diagnosis.
    func sendTest() async -> String {
        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            settings = await center.notificationSettings()
        }

        switch settings.authorizationStatus {
        case .denied:
            return "❌ Mitteilungen sind für Ezan Pro nicht erlaubt. Bitte in den Mitteilungs-Einstellungen aktivieren."
        case .notDetermined:
            return "❌ macOS hat noch nicht nach der Erlaubnis gefragt. Bitte in den Mitteilungs-Einstellungen aktivieren."
        default:
            break
        }

        let content = UNMutableNotificationContent()
        content.title = "Ezan Pro"
        content.body = "Benachrichtigungen funktionieren ✅"
        content.sound = .default
        do {
            try await center.add(UNNotificationRequest(identifier: "test", content: content, trigger: nil))
        } catch {
            return "❌ Senden fehlgeschlagen: \(error.localizedDescription)"
        }

        var hints: [String] = []
        if settings.alertSetting != .enabled || settings.alertStyle == .none {
            hints.append("Banner/Hinweise sind ausgeschaltet")
        }
        if settings.soundSetting != .enabled {
            hints.append("Ton ist ausgeschaltet")
        }
        if hints.isEmpty {
            return "✅ Gesendet. Nichts zu sehen? Dann ist evtl. ein Fokus (Nicht stören) aktiv."
        }
        return "⚠️ Gesendet, aber: " + hints.joined(separator: ", ") + ". Bitte in den Mitteilungs-Einstellungen ändern."
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=de.ezanpro.app")!
        NSWorkspace.shared.open(url)
    }

    func remove(id: String) {
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        guard let id = response.notification.request.content.userInfo["id"] as? String else { return }
        let action = response.actionIdentifier
        await MainActor.run {
            if action == Self.prayedAction { onPrayed?(id) }
            else if action == Self.laterAction { onLater?(id) }
        }
    }
}
