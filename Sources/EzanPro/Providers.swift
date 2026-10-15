import Foundation

struct Place: Identifiable, Hashable, Decodable {
    var id: String
    var name: String
}

enum ProviderError: LocalizedError {
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .badResponse(let s): "Ungültige Antwort: \(s)"
        }
    }
}

/// Official Diyanet times via the ezanvakti.emushaf.net mirror.
enum DiyanetProvider {
    private static let base = URL(string: "https://ezanvakti.emushaf.net")!

    private struct Country: Decodable { let UlkeAdi: String; let UlkeID: String }
    private struct State: Decodable { let SehirAdi: String; let SehirID: String }
    private struct District: Decodable { let IlceAdi: String; let IlceID: String }
    private struct Vakit: Decodable {
        let MiladiTarihKisa: String
        let Imsak, Gunes, Ogle, Ikindi, Aksam, Yatsi: String
    }

    private static func get<T: Decodable>(_ path: String) async throws -> T {
        let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent(path))
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func countries() async throws -> [Place] {
        let c: [Country] = try await get("ulkeler")
        return c.map { Place(id: $0.UlkeID, name: $0.UlkeAdi.capitalized) }
    }

    static func states(country: String) async throws -> [Place] {
        let s: [State] = try await get("sehirler/\(country)")
        return s.map { Place(id: $0.SehirID, name: $0.SehirAdi.capitalized) }
    }

    static func districts(state: String) async throws -> [Place] {
        let d: [District] = try await get("ilceler/\(state)")
        return d.map { Place(id: $0.IlceID, name: $0.IlceAdi.capitalized) }
    }

    static func times(district: String) async throws -> [DayTimes] {
        let v: [Vakit] = try await get("vakitler/\(district)")
        return v.compactMap {
            guard let day = DateKeys.fromGerman($0.MiladiTarihKisa) else { return nil }
            return DayTimes(date: day, imsak: $0.Imsak, gunes: $0.Gunes, ogle: $0.Ogle,
                            ikindi: $0.Ikindi, aksam: $0.Aksam, yatsi: $0.Yatsi)
        }
    }
}

/// IGMG times scraped from the igmg.org prayer calendar.
enum IGMGProvider {
    private static let page = URL(string: "https://www.igmg.org/gebetskalender/")!
    private static let api = URL(string: "https://www.igmg.org/wp-content/themes/igmg/include/gebetskalender_ajax_api.php")!

    static func cities() async throws -> [Place] {
        let (data, _) = try await URLSession.shared.data(from: page)
        guard let html = String(data: data, encoding: .utf8),
              let start = html.range(of: "id=\"alman_sehirleri\""),
              let end = html.range(of: "id=\"year_germany\"", range: start.upperBound..<html.endIndex)
        else { throw ProviderError.badResponse("IGMG-Städteliste nicht gefunden") }

        let section = String(html[start.lowerBound..<end.lowerBound])
        let regex = #/<option value="(\d+)"[^>]*>([^<]+)/#
        var seen = Set<String>()
        var result: [Place] = []
        for m in section.matches(of: regex) {
            let id = String(m.1)
            let name = String(m.2).trimmingCharacters(in: .whitespacesAndNewlines)
            if seen.insert(id).inserted { result.append(Place(id: id, name: name)) }
        }
        return result
    }

    static func times(city: String, month: Int, year: Int) async throws -> [DayTimes] {
        var req = URLRequest(url: api)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(page.absoluteString, forHTTPHeaderField: "Referer")
        req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        req.httpBody = "show_ajax_variable=\(city)&show_month=\(month)&show_year=\(year)&lang=de".data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let html = String(data: data, encoding: .utf8) else { throw ProviderError.badResponse("IGMG") }

        let regex = #/<span class="tarih">(\d\d\.\d\d\.\d{4})<\/span>\s*<span class="imsak_time">(\d\d:\d\d)<\/span>\s*<span class="gunes_time">(\d\d:\d\d)<\/span>\s*<span class="ogle_time">(\d\d:\d\d)<\/span>\s*<span class="ikindi_time">(\d\d:\d\d)<\/span>\s*<span class="aksam_time">(\d\d:\d\d)<\/span>\s*<span class="yatsi_time">(\d\d:\d\d)<\/span>/#
        let days = html.matches(of: regex).compactMap { m -> DayTimes? in
            guard let day = DateKeys.fromGerman(String(m.1)) else { return nil }
            return DayTimes(date: day, imsak: String(m.2), gunes: String(m.3), ogle: String(m.4),
                            ikindi: String(m.5), aksam: String(m.6), yatsi: String(m.7))
        }
        if days.isEmpty { throw ProviderError.badResponse(String(html.prefix(120))) }
        return days
    }

    /// Current and next month, so the cache stays valid across month boundaries.
    static func times(city: String, from date: Date = Date()) async throws -> [DayTimes] {
        let cal = Calendar.current
        let next = cal.date(byAdding: .month, value: 1, to: date)!
        async let a = times(city: city, month: cal.component(.month, from: date), year: cal.component(.year, from: date))
        async let b = times(city: city, month: cal.component(.month, from: next), year: cal.component(.year, from: next))
        return try await a + b
    }
}

enum TimesProvider {
    static func fetch(_ loc: LocationConfig) async throws -> [DayTimes] {
        switch loc.source {
        case .diyanet: try await DiyanetProvider.times(district: loc.cityID)
        case .igmg: try await IGMGProvider.times(city: loc.cityID)
        }
    }
}
