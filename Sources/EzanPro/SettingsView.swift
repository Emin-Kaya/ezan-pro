import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PrayerStore

    @State private var source: Source = .diyanet

    // Diyanet: Land → Bundesland/Provinz → Ort
    @State private var countries: [Place] = []
    @State private var states: [Place] = []
    @State private var districts: [Place] = []
    @State private var countryID = "13"
    @State private var stateID = ""
    @State private var districtID = ""

    // IGMG: searchable city list
    @State private var igmgCities: [Place] = []
    @State private var search = ""
    @State private var igmgSelection: String?

    @State private var loadError: String?
    @State private var testResult: String?

    var body: some View {
        Form {
            Section("Ort & Berechnung") {
                LabeledContent("Aktuell") {
                    Text("\(store.location.cityName) (\(store.location.source.label))")
                }

                Picker("Quelle", selection: $source) {
                    ForEach(Source.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                if source == .diyanet { diyanetPicker } else { igmgPicker }

                if let loadError {
                    Text(loadError).font(.caption).foregroundStyle(.red)
                }

                HStack {
                    Spacer()
                    Button("Übernehmen") { apply() }
                        .buttonStyle(.borderedProminent)
                        .disabled(pendingLocation == nil || pendingLocation == store.location)
                }
            }

            Section("Erinnerungen") {
                Stepper(value: $store.reminderMinutes, in: 5...60, step: 5) {
                    Text("Erneut erinnern alle **\(store.reminderMinutes) Min.**, bis gebetet")
                }
                Toggle("Ton abspielen", isOn: $store.playSound)
                Toggle("Beim Anmelden starten", isOn: Binding(
                    get: { store.launchAtLogin },
                    set: { store.launchAtLogin = $0 }
                ))
                HStack {
                    Button("Test-Benachrichtigung senden") {
                        Task { testResult = await store.notifier.sendTest() }
                    }
                    Button("Mitteilungs-Einstellungen …") { Notifier.openSystemSettings() }
                }
                if let testResult {
                    Text(testResult).font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 560)
        .task {
            source = store.location.source
            await loadDiyanetDefaults()
        }
        .onChange(of: source) { _, new in
            if new == .igmg, igmgCities.isEmpty { Task { await loadIGMG() } }
        }
    }

    // MARK: - Diyanet

    private var diyanetPicker: some View {
        Group {
            Picker("Land", selection: $countryID) {
                ForEach(countries) { Text($0.name).tag($0.id) }
            }
            .onChange(of: countryID) { _, id in Task { await loadStates(id) } }

            Picker("Bundesland / Provinz", selection: $stateID) {
                ForEach(states) { Text($0.name).tag($0.id) }
            }
            .onChange(of: stateID) { _, id in Task { await loadDistricts(id) } }

            Picker("Ort", selection: $districtID) {
                ForEach(districts) { Text($0.name).tag($0.id) }
            }
        }
    }

    private func loadDiyanetDefaults() async {
        do {
            countries = try await DiyanetProvider.countries()
            await loadStates(countryID)
            if store.location.source == .diyanet { districtID = store.location.cityID }
        } catch {
            loadError = "Diyanet-Liste: \(error.localizedDescription)"
        }
        if store.location.source == .igmg {
            igmgSelection = store.location.cityID
            await loadIGMG()
        }
    }

    private func loadStates(_ country: String) async {
        guard !country.isEmpty else { return }
        do {
            states = try await DiyanetProvider.states(country: country)
            // Default to Berlin in Germany, otherwise the first entry.
            stateID = states.first { $0.id == "852" }?.id ?? states.first?.id ?? ""
            await loadDistricts(stateID)
        } catch {
            loadError = "Diyanet-Liste: \(error.localizedDescription)"
        }
    }

    private func loadDistricts(_ state: String) async {
        guard !state.isEmpty else { return }
        do {
            districts = try await DiyanetProvider.districts(state: state)
            if !districts.contains(where: { $0.id == districtID }) {
                districtID = districts.first?.id ?? ""
            }
        } catch {
            loadError = "Diyanet-Liste: \(error.localizedDescription)"
        }
    }

    // MARK: - IGMG

    private var filteredIGMG: [Place] {
        let q = search.trimmingCharacters(in: .whitespaces)
        let list = q.isEmpty ? igmgCities : igmgCities.filter { $0.name.localizedCaseInsensitiveContains(q) }
        return Array(list.prefix(300))
    }

    private var igmgPicker: some View {
        VStack(alignment: .leading) {
            TextField("Stadt suchen …", text: $search)
                .textFieldStyle(.roundedBorder)
            if igmgCities.isEmpty {
                ProgressView("Lade IGMG-Städte …").controlSize(.small)
            } else {
                List(filteredIGMG, selection: $igmgSelection) { city in
                    Text(city.name).tag(city.id)
                }
                .frame(height: 180)
            }
        }
    }

    private func loadIGMG() async {
        do {
            igmgCities = try await IGMGProvider.cities()
        } catch {
            loadError = "IGMG-Liste: \(error.localizedDescription)"
        }
    }

    // MARK: - Apply

    private var pendingLocation: LocationConfig? {
        switch source {
        case .diyanet:
            guard let d = districts.first(where: { $0.id == districtID }) else { return nil }
            let state = states.first { $0.id == stateID }?.name
            let name = (state == nil || state == d.name) ? d.name : "\(d.name), \(state!)"
            return LocationConfig(source: .diyanet, cityID: d.id, cityName: name)
        case .igmg:
            guard let id = igmgSelection, let c = igmgCities.first(where: { $0.id == id }) else { return nil }
            return LocationConfig(source: .igmg, cityID: c.id, cityName: c.name)
        }
    }

    private func apply() {
        if let loc = pendingLocation { store.setLocation(loc) }
    }
}
