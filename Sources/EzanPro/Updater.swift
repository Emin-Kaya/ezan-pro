import AppKit
import Foundation

/// Self-updater based on GitHub releases: compares the latest release tag with the
/// bundle version, downloads EzanPro.zip, swaps the app bundle and relaunches.
@MainActor
final class Updater: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(String)
        case installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle {
        didSet { NSLog("EzanPro updater: %@", String(describing: state)) }
    }
    @Published var autoInstall: Bool { didSet { UserDefaults.standard.set(autoInstall, forKey: "autoUpdate") } }

    private static let latestURL = URL(string: "https://api.github.com/repos/Emin-Kaya/ezan-pro/releases/latest")!
    private static let checkInterval: TimeInterval = 6 * 3600

    private var downloadURL: URL?
    private var timer: Timer?

    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    init() {
        autoInstall = UserDefaults.standard.object(forKey: "autoUpdate") as? Bool ?? true
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
        // Give the app a moment to start before the first check.
        Task {
            try? await Task.sleep(for: .seconds(10))
            await check()
        }
    }

    private struct Release: Decodable {
        struct Asset: Decodable { let name: String; let browser_download_url: URL }
        let tag_name: String
        let assets: [Asset]
    }

    func check() async {
        guard state != .installing else { return }
        state = .checking
        do {
            var req = URLRequest(url: Self.latestURL, cachePolicy: .reloadIgnoringLocalCacheData)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, _) = try await URLSession.shared.data(for: req)
            let release = try JSONDecoder().decode(Release.self, from: data)
            let latest = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

            guard Self.isNewer(latest, than: currentVersion),
                  let asset = release.assets.first(where: { $0.name == "EzanPro.zip" }) else {
                state = .upToDate
                return
            }
            downloadURL = asset.browser_download_url
            state = .available(latest)
            if autoInstall { await install() }
        } catch {
            state = .failed("Update-Prüfung fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func install() async {
        guard let downloadURL, case .available = state else { return }
        state = .installing
        do {
            let fm = FileManager.default
            let tmp = fm.temporaryDirectory.appendingPathComponent("EzanProUpdate-\(UUID().uuidString)")
            try fm.createDirectory(at: tmp, withIntermediateDirectories: true)

            let (zip, _) = try await URLSession.shared.download(from: downloadURL)
            try run("/usr/bin/ditto", ["-x", "-k", zip.path, tmp.path])

            let newApp = tmp.appendingPathComponent("Ezan Pro.app")
            guard Bundle(url: newApp)?.bundleIdentifier == Bundle.main.bundleIdentifier else {
                throw NSError(domain: "Updater", code: 1, userInfo: [NSLocalizedDescriptionKey: "Download enthält keine gültige App"])
            }
            try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])

            let target = Bundle.main.bundleURL
            _ = try fm.replaceItemAt(target, withItemAt: newApp)

            // Relaunch the new version once this process has exited.
            let relaunch = Process()
            relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
            relaunch.arguments = ["-c", "sleep 1; open \"$0\"", target.path]
            try relaunch.run()
            NSApp.terminate(nil)
        } catch {
            state = .failed("Update fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private func run(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            throw NSError(domain: "Updater", code: Int(p.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "\(tool) fehlgeschlagen"])
        }
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
