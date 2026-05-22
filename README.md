# Clank

Native macOS/AppKit menu bar app for accelerometer-driven sound feedback.
Apple Silicon only. macOS 13+.

> **Instalacja dla uzytkownikow koncowych:** patrz [INSTALL.md](INSTALL.md).
> Ten plik to dokumentacja deweloperska.

## Wymagania

- macOS 13+
- Apple Silicon (M1 / M2 / M3 / M4)
- Swift 5.9+ (Xcode Command Line Tools)

## Build z zrodel

```bash
# Build debug
swift build

# Build release + bundle
make bundle

# Ad-hoc codesign
make sign

# Build DMG z dolaczonymi skryptami instalacyjnymi
make release
```

Wynikowy DMG: `dist/Clank-<VERSION>.dmg`.

## Architektura

Aplikacja zlozona z dwoch procesow:

1. **`Clank.app`** — proces uzytkownika (LSUIElement), GUI w pasku menu,
   ustawienia, odtwarzanie dzwieku. Nie wymaga uprawnien root.

2. **`clank-sensor-helper`** — proces root (LaunchDaemon), czyta akcelerometr
   przez prywatne IOKit API. Instalowany jednorazowo do `/usr/local/libexec/`
   przez `scripts/install-helper.sh`.

Komunikacja: aplikacja zapisuje heartbeat (`/tmp/clank-helper.heartbeat`),
helper monitoruje akcelerometr gdy heartbeat jest swiezy (<3s), zapisuje
zdarzenia do `/tmp/clank-helper.events` (JSONL). Aplikacja odczytuje
zdarzenia z offsetu.

## Tryby dzwiekow

- **Jeden dzwiek**: kazde wykryte uderzenie odtwarza wybrany plik, bez wzgledu na amplitude
- **Skala 5 stopni**: amplitude mapowana jest na 5 konfigurowalnych dzwiekow

## Workflow deweloperski

Helper mozna uruchomic lokalnie (bez instalacji LaunchDaemona) podajac
flagi recznie:

```bash
sudo .build/release/Clank --sensor-helper \
    --events-file /tmp/clank-helper.events \
    --heartbeat-file /tmp/clank-helper.heartbeat
```

W innym terminalu uruchom aplikacje user-mode:

```bash
make run
```

Aby zainstalowac/odinstalowac LaunchDaemona lokalnie:

```bash
make install-helper
make uninstall-helper
```

## Testy

```bash
swift test
```

## Pliki kluczowe

- `Sources/Clank/AppDelegate.swift` — entry point, status bar, menu
- `Sources/Clank/AccelerometerMonitor.swift` — odczyt akcelerometru
- `Sources/Clank/SensorHelperMain.swift` — entry point helpera (`--sensor-helper`)
- `Sources/Clank/SensorHelperClient.swift` — IPC od strony aplikacji
- `Sources/Clank/AudioPlayer.swift` — cache + fade-out
- `Sources/Clank/SettingsWindowController.swift` — okno ustawien

## Dystrybucja

Aktualna wersja jest ad-hoc podpisana (`codesign --sign -`), bez notaryzacji.
Dla dystrybucji prywatnej (znajomi). Pelne wydanie wymagaloby Apple Developer ID
+ notaryzacji — patrz `docs/superpowers/plans/2026-05-22-distribution-friends.md`
dla zakresu pominietego.
