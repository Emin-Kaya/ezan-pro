# 🕌 Ezan Pro

Eine kleine macOS-Menüleisten-App, die dich an die Gebetszeiten erinnert und nachfragt, ob du gebetet hast.
Falls nicht, erinnert sie dich alle 15 Minuten erneut, bis du das Gebet abhakst oder die Zeit abläuft.

## Funktionen

- **Gebetszeiten von Diyanet oder IGMG**: Stadt und Quelle jederzeit in den Einstellungen änderbar
- **Mitteilung zur Ezan-Zeit** mit den Buttons **„✅ Gebetet“** und **„⏰ Noch nicht“**
- **Erneute Erinnerung** (Standard alle 15 Min., einstellbar 5–60 Min.), kurz vor Ablauf dringender
- **Menüleiste** zeigt das nächste Gebet bzw. „⚠ Öğle offen“, wenn ein Gebet noch fällig ist
- **Tagesübersicht** zum Abhaken, „Heute x/5“ und **Serie** (Tage mit allen 5 Gebeten)
- Zeiten werden für ~1 Monat gespeichert, die App funktioniert also auch offline
- Optional: Autostart beim Anmelden

## Installation

**Voraussetzung:** macOS 14 (Sonoma) oder neuer, Apple-Chip oder Intel.

### Variante A: ein Befehl im Terminal (empfohlen)

Öffne das Programm **Terminal** und füge diese Zeile ein:

```bash
curl -fsSL https://raw.githubusercontent.com/Emin-Kaya/ezan-pro/main/install.sh | bash
```

Das lädt die neueste Version herunter, installiert sie nach `/Programme` und startet sie.
Für ein Update führst du denselben Befehl einfach nochmal aus.

### Variante B: manuell herunterladen

1. Unter [Releases](https://github.com/Emin-Kaya/ezan-pro/releases/latest) die Datei **EzanPro.zip** herunterladen
2. Entpacken und **Ezan Pro.app** in den Ordner **Programme** ziehen
3. Die App ist nicht von Apple notarisiert, deshalb blockiert macOS beim ersten Start.
   Einmal im Terminal ausführen:
   ```bash
   xattr -dr com.apple.quarantine "/Applications/Ezan Pro.app"
   ```
   Alternativ: Öffnen versuchen, dann *Systemeinstellungen → Datenschutz & Sicherheit → „Trotzdem öffnen“*.

## Einrichtung nach dem ersten Start

1. **Mitteilungen erlauben**, wenn macOS fragt
2. *Systemeinstellungen → Mitteilungen → Ezan Pro* → Stil auf **„Hinweise“** stellen,
   damit die Mitteilung mit den Buttons stehen bleibt
3. Auf das Mond-Symbol in der Menüleiste klicken → **Einstellungen …**
   - **Quelle** wählen: Diyanet oder IGMG
   - **Stadt** wählen (Standard: Berlin) und **Übernehmen**
   - **Beim Anmelden starten** einschalten

## Wann wird erinnert?

| Gebet  | Ab     | Erinnerung bis           |
|--------|--------|--------------------------|
| Sabah  | İmsak  | Güneş (Sonnenaufgang)    |
| Öğle   | Öğle   | İkindi                   |
| İkindi | İkindi | Akşam                    |
| Akşam  | Akşam  | Yatsı                    |
| Yatsı  | Yatsı  | İmsak des nächsten Tages |

## Datenquellen

- **Diyanet**: offizielle Diyanet-Zeiten über den Spiegel-Server `ezanvakti.emushaf.net` (Land → Bundesland → Ort)
- **IGMG**: Gebetskalender von [igmg.org](https://www.igmg.org/gebetskalender/) (über 8000 Städte)

Beide Quellen sind keine offiziellen Schnittstellen. Ändern die Anbieter etwas, muss die App eventuell angepasst werden.
Die Zeiten werden in der Zeitzone deines Macs angezeigt.

## Selbst bauen

Benötigt Xcode bzw. die Xcode Command Line Tools.

```bash
git clone https://github.com/Emin-Kaya/ezan-pro.git
cd ezan-pro
./build.sh --install
```

| Datei | Inhalt |
|-------|--------|
| `Sources/EzanPro/PrayerStore.swift` | Zeiten, Abhaken, Erinnerungslogik |
| `Sources/EzanPro/Providers.swift`   | Diyanet- und IGMG-Abruf |
| `Sources/EzanPro/Notifier.swift`    | Mitteilungen mit Aktionen |
| `Sources/EzanPro/MenuView.swift`    | Menüleisten-Fenster |
| `Sources/EzanPro/SettingsView.swift`| Einstellungen |
