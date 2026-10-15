import Foundation

enum Prayer: String, CaseIterable, Codable, Identifiable {
    case sabah, ogle, ikindi, aksam, yatsi

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sabah: "Sabah"
        case .ogle: "Öğle"
        case .ikindi: "İkindi"
        case .aksam: "Akşam"
        case .yatsi: "Yatsı"
        }
    }

    var germanName: String {
        switch self {
        case .sabah: "Morgengebet"
        case .ogle: "Mittagsgebet"
        case .ikindi: "Nachmittagsgebet"
        case .aksam: "Abendgebet"
        case .yatsi: "Nachtgebet"
        }
    }
}

enum Source: String, CaseIterable, Codable, Identifiable {
    case diyanet, igmg

    var id: String { rawValue }
    var label: String { self == .diyanet ? "Diyanet" : "IGMG" }
}

struct LocationConfig: Codable, Equatable {
    var source: Source
    var cityID: String
    var cityName: String

    static let berlinDiyanet = LocationConfig(source: .diyanet, cityID: "11002", cityName: "Berlin")
    static let berlinIGMG = LocationConfig(source: .igmg, cityID: "20015", cityName: "Berlin (DE)")
}

/// Times for one day as local "HH:mm" strings, keyed by date "yyyy-MM-dd".
struct DayTimes: Codable, Equatable {
    var date: String
    var imsak: String
    var gunes: String
    var ogle: String
    var ikindi: String
    var aksam: String
    var yatsi: String

    func time(of prayer: Prayer) -> String {
        switch prayer {
        case .sabah: imsak
        case .ogle: ogle
        case .ikindi: ikindi
        case .aksam: aksam
        case .yatsi: yatsi
        }
    }
}

/// A concrete prayer occurrence with its time window [start, end).
struct PrayerWindow: Identifiable, Equatable {
    var prayer: Prayer
    var day: String
    var start: Date
    var end: Date

    var id: String { "\(day)|\(prayer.rawValue)" }

    func contains(_ date: Date) -> Bool { date >= start && date < end }
}

enum DateKeys {
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(for date: Date) -> String { dayFormatter.string(from: date) }

    static func date(day: String, time: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: "\(day) \(time)")
    }

    /// "dd.MM.yyyy" -> "yyyy-MM-dd"
    static func fromGerman(_ s: String) -> String? {
        let p = s.split(separator: ".")
        guard p.count == 3 else { return nil }
        return "\(p[2])-\(p[1])-\(p[0])"
    }
}
