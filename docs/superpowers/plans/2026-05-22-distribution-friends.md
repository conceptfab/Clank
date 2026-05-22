# Clank — dystrybucja do znajomych (bez Developer ID) — plan wdrożenia

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Przygotować Clank.app do dystrybucji jako podpisany ad-hoc DMG, instalujący wymagany przywilejowany helper akcelerometru jako LaunchDaemon, bez konieczności płatnego Apple Developer ID.

**Architecture:** Likwidujemy aktualny model „sudo przy każdym starcie" (Makefile install-sudoers + SensorHelperClient.swift wywołujący `/usr/bin/sudo`) i zastępujemy go LaunchDaemonem instalowanym jednorazowo przez skrypt z jednym promptem o hasło administratora. Demon używa istniejącej logiki helpera (`--sensor-helper`) z stałych ścieżek `/tmp/clank-helper.*` zamiast plików per-sesja. Demon utrzymuje `KeepAlive: true` i przechodzi w idle, gdy heartbeat staje się przeterminowany. Aplikacja jest ad-hoc-podpisana (`codesign --sign -`), zapakowana w DMG. Znajomi obchodzą Gatekeeper jednorazowo (xattr -dr com.apple.quarantine albo prawy-klik → Otwórz).

**Tech Stack:** Swift 5.9, AppKit, swift build/SPM, codesign (ad-hoc), hdiutil, launchd (LaunchDaemons), shell scripts (bash).

**Zakres co świadomie POMIJAMY (poza planem):**
- Płatne Developer ID, hardened runtime, notaryzacja, App Store, Sparkle auto-update, lokalizacja i18n, runtime-konfiguracja helpera (detection sliders w UI pozostają „kosmetyczne" dla parametrów min-amplitude/cooldown w wersji friend-testing; zmiana wymaga reinstallu)
- Privacy Manifest (`PrivacyInfo.xcprivacy`) — nie wymagany dla dystrybucji prywatnej
- Universal binary (Apple Silicon only — dokumentujemy)

---

## Mapa plików

**Tworzymy:**
- `LICENSE` — tekst licencji (MIT) z prawami `Michal Kleniewski 2026`
- `Clank.entitlements` — entitlements (puste, ale gotowe na przyszłe potrzeby)
- `scripts/install-helper.sh` — instalacja LaunchDaemona (sudo prompt × 1)
- `scripts/uninstall-helper.sh` — usunięcie LaunchDaemona
- `scripts/build-dmg.sh` — pakowanie do DMG
- `Resources/dev.conceptfab.clank.sensor-helper.plist.template` — szablon plist LaunchDaemona (instalator podstawia ścieżkę)
- `INSTALL.md` — instrukcja dla znajomych (Gatekeeper, instalacja helpera)
- `docs/superpowers/plans/2026-05-22-distribution-friends.md` — ten plik

**Modyfikujemy:**
- `Info.plist` — `CFBundleIdentifier`: `dev.taigrr.clank` → `dev.conceptfab.clank`, `CFBundleShortVersionString`: `0.1.0` → `1.0.0`
- `Sources/Clank/SensorHelperClient.swift` — usuwamy spawn przez sudo; tylko touch-heartbeat + poll events ze stałej ścieżki
- `Sources/Clank/SensorHelperMain.swift` — stałe ścieżki domyślne, KeepAlive-friendly idle loop (sleep zamiast exit przy stale-heartbeat), tworzenie plików z mode 0666
- `Sources/Clank/AppDelegate.swift` — usuwamy fallback `geteuid() == 0` (root-mode aktywujemy tylko przez LaunchDaemona), uproszczone `startMonitoring()`
- `Makefile` — usuwamy `install-sudoers`/`uninstall-sudoers`, dodajemy `sign`, `dmg`, `release`, `install-helper`, `uninstall-helper`
- `README.md` — przepisany pod kątem deweloperów; user-facing przeniesione do INSTALL.md
- `.gitignore` — dodaj `*.dmg`, `dist/`

---

## Task 1: Metadane projektu — LICENSE, bundle ID, wersja

**Files:**
- Create: `LICENSE`
- Modify: `Info.plist`

- [ ] **Step 1: Utwórz LICENSE (MIT)**

Zapisz do `LICENSE`:

```
MIT License

Copyright (c) 2026 Michal Kleniewski

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Zmień CFBundleIdentifier i wersję w Info.plist**

W `Info.plist` zamień:

```xml
<key>CFBundleIdentifier</key>
<string>dev.taigrr.clank</string>
```

na:

```xml
<key>CFBundleIdentifier</key>
<string>dev.conceptfab.clank</string>
```

oraz:

```xml
<key>CFBundleShortVersionString</key>
<string>0.1.0</string>
```

na:

```xml
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
```

- [ ] **Step 3: Weryfikacja**

```bash
plutil -lint Info.plist
grep "conceptfab" Info.plist
```

Oczekiwane: `Info.plist: OK` oraz znaleziona linia z bundle ID.

- [ ] **Step 4: Commit**

```bash
git add LICENSE Info.plist
git commit -m "chore: add LICENSE, bump bundle id to dev.conceptfab.clank, version 1.0.0"
```

---

## Task 2: Dokumentacja wymagania Apple Silicon

**Files:**
- Modify: `Info.plist`

- [ ] **Step 1: Dodaj `LSRequiresNativeExecution` i `LSMinimumSystemVersionByArchitecture` do Info.plist**

W `Info.plist` przed `</dict>` dodaj:

```xml
<key>LSRequiresNativeExecution</key>
<true/>
<key>LSArchitecturePriority</key>
<array>
    <string>arm64</string>
</array>
```

To uniemożliwia uruchomienie pod Rosettą i sygnalizuje Apple Silicon-only.

- [ ] **Step 2: Weryfikacja**

```bash
plutil -lint Info.plist
plutil -extract LSArchitecturePriority xml1 -o - Info.plist
```

Oczekiwane: `OK` oraz tablica z `arm64`.

- [ ] **Step 3: Commit**

```bash
git add Info.plist
git commit -m "chore: enforce Apple Silicon native execution in Info.plist"
```

---

## Task 3: Plik entitlements (placeholder pod codesign)

**Files:**
- Create: `Clank.entitlements`

- [ ] **Step 1: Utwórz `Clank.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

Świadomie wyłączamy sandbox — Clank korzysta z prywatnych IOKit API akcelerometru, sandbox by je odciął. Plik jest na razie minimalny; rozszerzymy gdy/jeśli kupimy Developer ID.

- [ ] **Step 2: Weryfikacja**

```bash
plutil -lint Clank.entitlements
```

Oczekiwane: `OK`.

- [ ] **Step 3: Commit**

```bash
git add Clank.entitlements
git commit -m "chore: add entitlements file for ad-hoc codesign"
```

---

## Task 4: Refaktor SensorHelperMain — stałe ścieżki + KeepAlive-friendly idle

**Files:**
- Modify: `Sources/Clank/SensorHelperMain.swift`

- [ ] **Step 1: Przeczytaj obecny stan**

```bash
cat Sources/Clank/SensorHelperMain.swift
```

Zapamiętaj: obecnie helper exit'uje przy braku heartbeatu (>3s). Zmieniamy to na sleep loop, bo demon będzie miał `KeepAlive: true`.

- [ ] **Step 2: Zastąp całą zawartość SensorHelperMain.swift**

```swift
import Foundation

enum SensorHelperMain {
    private static let defaultEventsPath = "/tmp/clank-helper.events"
    private static let defaultHeartbeatPath = "/tmp/clank-helper.heartbeat"
    private static let heartbeatStaleSeconds: TimeInterval = 3.0

    static func run() -> Never {
        let options = parseArguments()
        let eventsPath = options["events-file"] ?? defaultEventsPath
        let heartbeatPath = options["heartbeat-file"] ?? defaultHeartbeatPath

        ensureWorldWritable(path: eventsPath, initialContent: Data())
        ensureWorldWritable(path: heartbeatPath, initialContent: Data("alive".utf8))

        let minAmplitude = Double(options["min-amplitude"] ?? "") ?? 0.05
        let cooldown = Int(options["cooldown"] ?? "") ?? 750
        let settings = AppSettings(
            soundMode: .single,
            singleSoundPath: "",
            scaledSoundPaths: Array(repeating: "", count: 5),
            soundVolume: 1.0,
            lidSoundEnabled: false,
            lidSoundPath: "",
            lidAngleThreshold: 4.0,
            lidSoundCooldownMilliseconds: 1200,
            lidStopMarginMilliseconds: 2000,
            lidMaxPlaybackMilliseconds: 2000,
            minAmplitude: minAmplitude,
            cooldownMilliseconds: cooldown,
            maxScaleAmplitude: 0.15
        )

        let monitor = AccelerometerMonitor(settingsProvider: { settings })
        monitor.onEvent = { event in
            append(HelperEvent(kind: "slap", amplitude: event.amplitude, level: event.level, angle: nil, delta: nil, date: event.date), to: eventsPath)
        }
        monitor.onLidAngleEvent = { event in
            append(HelperEvent(kind: "lid", amplitude: nil, level: nil, angle: event.angle, delta: event.delta, date: event.date), to: eventsPath)
        }

        var monitoring = false

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(500), repeating: .milliseconds(500))
        timer.setEventHandler {
            let fresh = isHeartbeatFresh(path: heartbeatPath)
            if fresh && !monitoring {
                do {
                    try monitor.start()
                    monitoring = true
                } catch {
                    FileHandle.standardError.write(Data("sensor start failed: \(error.localizedDescription)\n".utf8))
                }
            } else if !fresh && monitoring {
                monitor.stop()
                monitoring = false
            }
        }
        timer.resume()

        dispatchMain()
    }

    private static func isHeartbeatFresh(path: String) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let modified = attrs[.modificationDate] as? Date else {
            return false
        }
        return Date().timeIntervalSince(modified) <= heartbeatStaleSeconds
    }

    private static func ensureWorldWritable(path: String, initialContent: Data) {
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: initialContent)
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: path)
    }

    private static func append(_ payload: HelperEvent, to path: String) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let url = URL(fileURLWithPath: path)
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }

        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.write(contentsOf: Data("\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("event write failed: \(error.localizedDescription)\n".utf8))
        }
    }

    private static func parseArguments() -> [String: String] {
        var result: [String: String] = [:]
        var iterator = CommandLine.arguments.dropFirst().makeIterator()

        while let arg = iterator.next() {
            guard arg.hasPrefix("--") else { continue }
            let key = String(arg.dropFirst(2))
            if key == "sensor-helper" {
                continue
            }
            if let value = iterator.next() {
                result[key] = value
            }
        }

        return result
    }
}

private struct HelperEvent: Codable {
    let kind: String
    let amplitude: Double?
    let level: Int?
    let angle: Double?
    let delta: Double?
    let date: Date
}
```

- [ ] **Step 3: Build**

```bash
swift build -c release
```

Oczekiwane: zielony build, bez warningów dotyczących helpera.

- [ ] **Step 4: Commit**

```bash
git add Sources/Clank/SensorHelperMain.swift
git commit -m "refactor(helper): use fixed /tmp paths and idle loop for daemon use"
```

---

## Task 5: Refaktor SensorHelperClient — usuwamy sudo, tylko poll + heartbeat

**Files:**
- Modify: `Sources/Clank/SensorHelperClient.swift`

- [ ] **Step 1: Zastąp całą zawartość SensorHelperClient.swift**

```swift
import AppKit
import Foundation

enum SensorHelperClientError: LocalizedError {
    case daemonNotInstalled
    case eventsFileMissing(String)

    var errorDescription: String? {
        switch self {
        case .daemonNotInstalled:
            return "Helper sensora nie jest zainstalowany. Uruchom scripts/install-helper.sh i sprobuj ponownie."
        case .eventsFileMissing(let path):
            return "Brak pliku zdarzen helpera (\(path)). Sprawdz czy LaunchDaemon dziala: sudo launchctl list | grep clank"
        }
    }
}

final class SensorHelperClient {
    static let eventsPath = "/tmp/clank-helper.events"
    static let heartbeatPath = "/tmp/clank-helper.heartbeat"
    static let plistInstallPath = "/Library/LaunchDaemons/dev.conceptfab.clank.sensor-helper.plist"

    var onEvent: ((SlapEvent) -> Void)?
    var onLidAngleEvent: ((LidAngleEvent) -> Void)?

    private let settingsProvider: () -> AppSettings
    private var pollTimer: DispatchSourceTimer?
    private var heartbeatTimer: DispatchSourceTimer?
    private var readOffset: UInt64 = 0
    private var pending = Data()

    init(settingsProvider: @escaping () -> AppSettings) {
        self.settingsProvider = settingsProvider
    }

    func start() throws {
        guard FileManager.default.fileExists(atPath: Self.plistInstallPath) else {
            throw SensorHelperClientError.daemonNotInstalled
        }

        touchHeartbeat()

        let pollDeadline = DispatchTime.now() + .milliseconds(500)
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: pollDeadline, repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            self?.pollEvents()
        }
        timer.resume()
        pollTimer = timer

        let heartbeat = DispatchSource.makeTimerSource(queue: .main)
        heartbeat.schedule(deadline: .now(), repeating: .milliseconds(1000))
        heartbeat.setEventHandler { [weak self] in
            self?.touchHeartbeat()
        }
        heartbeat.resume()
        heartbeatTimer = heartbeat
    }

    func stop() {
        pollTimer?.cancel()
        pollTimer = nil
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    private func touchHeartbeat() {
        let url = URL(fileURLWithPath: Self.heartbeatPath)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: Data("alive".utf8))
            try? FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: url.path)
        } else {
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        }
    }

    private func pollEvents() {
        guard FileManager.default.fileExists(atPath: Self.eventsPath) else { return }
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: Self.eventsPath)) else { return }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: readOffset)
            let data = try handle.readToEnd() ?? Data()
            guard !data.isEmpty else { return }
            readOffset += UInt64(data.count)
            pending.append(data)
            drainLines()
        } catch {
            NSLog("Clank: event poll failed: \(error.localizedDescription)")
        }
    }

    private func drainLines() {
        while let newline = pending.firstIndex(of: 0x0A) {
            let line = pending[..<newline]
            pending.removeSubrange(...newline)
            guard !line.isEmpty,
                  let payload = try? JSONDecoder().decode(HelperEvent.self, from: Data(line)) else {
                continue
            }
            switch payload.kind {
            case "slap":
                guard let amplitude = payload.amplitude, let level = payload.level else { continue }
                onEvent?(SlapEvent(amplitude: amplitude, level: level, date: payload.date))
            case "lid":
                guard let angle = payload.angle, let delta = payload.delta else { continue }
                onLidAngleEvent?(LidAngleEvent(angle: angle, delta: delta, date: payload.date))
            default:
                continue
            }
        }
    }
}

private struct HelperEvent: Codable {
    let kind: String
    let amplitude: Double?
    let level: Int?
    let angle: Double?
    let delta: Double?
    let date: Date
}
```

Kluczowe zmiany vs. obecny stan:
- usunięto `Process` + `/usr/bin/sudo` — klient nie spawnuje helpera
- usunięto `helperProcess` i jego cleanup
- stałe ścieżki `/tmp/clank-helper.{events,heartbeat}`
- `start()` rzuca `daemonNotInstalled` jeśli brak pliku plist
- `start()` od razu czyta od `readOffset = 0` — w aktualnej implementacji events file jest append-only przez czas życia bootu; jeśli wcześniej działała inna sesja, nowy klient zobaczy stare eventy, ale `Date.distantPast` w `handle()` w AppDelegate i tak je odrzuci

- [ ] **Step 2: Build**

```bash
swift build -c release
```

Oczekiwane: zielony build. Jeśli pojawiają się błędy o brakujących typach (SlapEvent / LidAngleEvent) — sprawdź `SensorNotifications.swift`, definicje powinny tam być nienaruszone.

- [ ] **Step 3: Test (przejrzyj swift test, sprawdź czy nie zepsuliśmy fixtures helpera)**

```bash
swift test
```

Oczekiwane: PASS (lub te same skip/pass co przed zmianą — jeśli pojawi się NEW failure, prawdopodobnie dotyczy SensorHelperClient i wymaga aktualizacji fixture).

- [ ] **Step 4: Commit**

```bash
git add Sources/Clank/SensorHelperClient.swift
git commit -m "refactor(helper-client): poll fixed-path events instead of spawning via sudo"
```

---

## Task 6: Uproszczenie AppDelegate.startMonitoring — usuwamy gałąź geteuid()==0

**Files:**
- Modify: `Sources/Clank/AppDelegate.swift:177-196`

- [ ] **Step 1: Zastąp metodę startMonitoring()**

W `Sources/Clank/AppDelegate.swift` znajdź:

```swift
    private func startMonitoring() {
        guard !isRunning else { return }

        if geteuid() != 0 {
            startPrivilegedHelper()
            return
        }

        do {
            try monitor.start()
            isRunning = true
            lastError = nil
        } catch {
            isRunning = false
            lastError = error.localizedDescription
            showPermissionAlertIfNeeded(error)
        }

        refreshMenuState()
    }
```

i zamień na:

```swift
    private func startMonitoring() {
        guard !isRunning else { return }
        startPrivilegedHelper()
    }
```

Aplikacja zawsze działa jako user (LSUIElement); akcelerometr czyta wyłącznie LaunchDaemon. Stara gałąź „uruchamiamy bezpośrednio jeśli jesteśmy rootem" była używana wyłącznie przez Makefile `make run` jako sudo — to deweloperski workflow, którego nie potrzebujemy w runtime production.

- [ ] **Step 2: Usuń teraz-nieużywaną `showPermissionAlertIfNeeded` (linie ~237-243)**

Znajdź:

```swift
    private func showPermissionAlertIfNeeded(_ error: Error) {
        guard geteuid() != 0 else {
            showPermissionAlert(error)
            return
        }
        showPermissionAlert(error)
    }
```

i usuń całość (pozostawiamy tylko `showPermissionAlert`).

- [ ] **Step 3: Usuń `import Darwin` jeśli był używany wyłącznie pod `geteuid()`**

Sprawdź czy `Darwin` jest jeszcze potrzebny:

```bash
grep -n "Darwin\|geteuid\|getppid\|getuid" Sources/Clank/AppDelegate.swift
```

Jeśli jedyne wystąpienie to `import Darwin`, usuń linię `import Darwin` (linia 2). Jeśli `Darwin` jest używany do innych symboli, zostaw.

- [ ] **Step 4: Build**

```bash
swift build -c release
```

Oczekiwane: zielony build.

- [ ] **Step 5: Commit**

```bash
git add Sources/Clank/AppDelegate.swift
git commit -m "refactor(app): always run helper via LaunchDaemon, drop root-mode branch"
```

---

## Task 7: Szablon LaunchDaemon plist

**Files:**
- Create: `Resources/dev.conceptfab.clank.sensor-helper.plist.template`

- [ ] **Step 1: Utwórz szablon plist**

Zapisz do `Resources/dev.conceptfab.clank.sensor-helper.plist.template`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>dev.conceptfab.clank.sensor-helper</string>
    <key>ProgramArguments</key>
    <array>
        <string>__HELPER_BINARY__</string>
        <string>--sensor-helper</string>
        <string>--events-file</string>
        <string>/tmp/clank-helper.events</string>
        <string>--heartbeat-file</string>
        <string>/tmp/clank-helper.heartbeat</string>
        <string>--min-amplitude</string>
        <string>0.05</string>
        <string>--cooldown</string>
        <string>750</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/clank-helper.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/clank-helper.log</string>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
```

Placeholder `__HELPER_BINARY__` zostanie podmieniony przez `scripts/install-helper.sh` na absolutną ścieżkę binarki w `/usr/local/libexec/clank-sensor-helper`.

- [ ] **Step 2: Weryfikacja**

```bash
plutil -lint Resources/dev.conceptfab.clank.sensor-helper.plist.template
```

Oczekiwane: `OK` (placeholder jako string nie zaburza walidacji XML).

- [ ] **Step 3: Commit**

```bash
git add Resources/dev.conceptfab.clank.sensor-helper.plist.template
git commit -m "feat(daemon): add LaunchDaemon plist template for sensor helper"
```

---

## Task 8: Skrypt install-helper.sh

**Files:**
- Create: `scripts/install-helper.sh`

- [ ] **Step 1: Utwórz katalog i skrypt**

```bash
mkdir -p scripts
```

Zapisz do `scripts/install-helper.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# install-helper.sh — instaluje Clank sensor LaunchDaemon
#
# Wywolanie: ./scripts/install-helper.sh /sciezka/do/Clank.app
# Jezeli sciezka nie podana, skrypt szuka aplikacji w standardowych lokalizacjach.

LABEL="dev.conceptfab.clank.sensor-helper"
DAEMON_PLIST="/Library/LaunchDaemons/${LABEL}.plist"
HELPER_BIN="/usr/local/libexec/clank-sensor-helper"

usage() {
    cat <<EOF
Uzycie: $0 [/sciezka/do/Clank.app]

Skrypt zainstaluje LaunchDaemon helpera sensora Clank.
Wymagane jest jednorazowe podanie hasla administratora.

Po instalacji helper bedzie startowal automatycznie i Clank.app
bedzie mogla go uzywac bez sudo.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

APP_PATH="${1:-}"
if [[ -z "${APP_PATH}" ]]; then
    for candidate in \
        "/Applications/Clank.app" \
        "${HOME}/Applications/Clank.app" \
        "$(cd "$(dirname "$0")/.." && pwd)/build/Clank.app"; do
        if [[ -d "${candidate}" ]]; then
            APP_PATH="${candidate}"
            break
        fi
    done
fi

if [[ ! -d "${APP_PATH}" ]]; then
    echo "blad: nie znaleziono Clank.app — podaj sciezke jako argument" >&2
    exit 1
fi

SRC_BIN="${APP_PATH}/Contents/MacOS/Clank"
SRC_TEMPLATE="${APP_PATH}/Contents/Resources/Clank_Clank.bundle/Contents/Resources/dev.conceptfab.clank.sensor-helper.plist.template"

if [[ ! -f "${SRC_BIN}" ]]; then
    echo "blad: brak binarki w ${SRC_BIN}" >&2
    exit 1
fi
if [[ ! -f "${SRC_TEMPLATE}" ]]; then
    # SPM moze umiescic bundle w innym miejscu — sprobuj alternatywnej sciezki
    SRC_TEMPLATE="${APP_PATH}/Clank_Clank.bundle/Contents/Resources/dev.conceptfab.clank.sensor-helper.plist.template"
fi
if [[ ! -f "${SRC_TEMPLATE}" ]]; then
    echo "blad: nie znaleziono pliku plist template w bundle aplikacji" >&2
    exit 1
fi

echo "==> Clank sensor helper — instalacja"
echo "    aplikacja:   ${APP_PATH}"
echo "    helper bin:  ${HELPER_BIN}"
echo "    daemon plist: ${DAEMON_PLIST}"
echo ""
echo "Skrypt poprosi o haslo administratora (sudo) — JEDNORAZOWO."
echo ""

# Generuj plist z podstawiona sciezka
TMP_PLIST="$(mktemp -t clank-helper.plist.XXXXXX)"
trap 'rm -f "${TMP_PLIST}"' EXIT
sed "s|__HELPER_BINARY__|${HELPER_BIN}|g" "${SRC_TEMPLATE}" > "${TMP_PLIST}"

# Walidacja wygenerowanego plist
plutil -lint "${TMP_PLIST}" >/dev/null

# Jezeli daemon juz dziala, unload przed wymiana
if sudo launchctl print "system/${LABEL}" >/dev/null 2>&1; then
    echo "==> Wylaczam istniejacy daemon"
    sudo launchctl bootout "system/${LABEL}" || true
fi

echo "==> Kopiuje binarke helpera do ${HELPER_BIN}"
sudo mkdir -p /usr/local/libexec
sudo cp "${SRC_BIN}" "${HELPER_BIN}"
sudo chown root:wheel "${HELPER_BIN}"
sudo chmod 755 "${HELPER_BIN}"

echo "==> Instaluje plist w ${DAEMON_PLIST}"
sudo cp "${TMP_PLIST}" "${DAEMON_PLIST}"
sudo chown root:wheel "${DAEMON_PLIST}"
sudo chmod 644 "${DAEMON_PLIST}"

echo "==> Laduje daemon"
sudo launchctl bootstrap system "${DAEMON_PLIST}"
sudo launchctl enable "system/${LABEL}"

echo ""
echo "Gotowe. Helper dziala jako system daemon."
echo "Sprawdzenie:  sudo launchctl print system/${LABEL} | head -20"
echo "Logi:         tail -f /var/log/clank-helper.log"
echo "Odinstalowanie: ./scripts/uninstall-helper.sh"
```

- [ ] **Step 2: Nadaj uprawnienia wykonywania**

```bash
chmod +x scripts/install-helper.sh
```

- [ ] **Step 3: Sprawdź składnię bash**

```bash
bash -n scripts/install-helper.sh
```

Oczekiwane: brak outputu (skrypt poprawny).

- [ ] **Step 4: Shellcheck (opcjonalnie jeśli zainstalowany)**

```bash
which shellcheck && shellcheck scripts/install-helper.sh || echo "shellcheck nie zainstalowany, pomijam"
```

- [ ] **Step 5: Commit**

```bash
git add scripts/install-helper.sh
git commit -m "feat(scripts): add install-helper.sh for one-time LaunchDaemon setup"
```

---

## Task 9: Skrypt uninstall-helper.sh

**Files:**
- Create: `scripts/uninstall-helper.sh`

- [ ] **Step 1: Utwórz skrypt**

Zapisz do `scripts/uninstall-helper.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

LABEL="dev.conceptfab.clank.sensor-helper"
DAEMON_PLIST="/Library/LaunchDaemons/${LABEL}.plist"
HELPER_BIN="/usr/local/libexec/clank-sensor-helper"

echo "==> Clank sensor helper — odinstalowanie"
echo "Skrypt poprosi o haslo administratora (sudo)."
echo ""

if sudo launchctl print "system/${LABEL}" >/dev/null 2>&1; then
    echo "==> Wylaczam daemon"
    sudo launchctl bootout "system/${LABEL}" || true
fi

if [[ -f "${DAEMON_PLIST}" ]]; then
    echo "==> Usuwam ${DAEMON_PLIST}"
    sudo rm -f "${DAEMON_PLIST}"
fi

if [[ -f "${HELPER_BIN}" ]]; then
    echo "==> Usuwam ${HELPER_BIN}"
    sudo rm -f "${HELPER_BIN}"
fi

sudo rm -f /tmp/clank-helper.events /tmp/clank-helper.heartbeat /var/log/clank-helper.log

echo ""
echo "Gotowe. Helper odinstalowany."
```

- [ ] **Step 2: Uprawnienia i walidacja**

```bash
chmod +x scripts/uninstall-helper.sh
bash -n scripts/uninstall-helper.sh
```

Oczekiwane: brak outputu.

- [ ] **Step 3: Commit**

```bash
git add scripts/uninstall-helper.sh
git commit -m "feat(scripts): add uninstall-helper.sh for clean daemon removal"
```

---

## Task 10: Aktualizacja Package.swift — dodanie plist template do resources

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: Dodaj plist template do resources**

W `Package.swift` znajdź sekcję `resources`:

```swift
            resources: [
                .copy("Resources/audio"),
                .copy("Resources/icon.png"),
                .copy("Resources/AppIcon.icns")
            ],
```

i zamień na:

```swift
            resources: [
                .copy("Resources/audio"),
                .copy("Resources/icon.png"),
                .copy("Resources/AppIcon.icns"),
                .copy("Resources/dev.conceptfab.clank.sensor-helper.plist.template")
            ],
```

- [ ] **Step 2: Przenieś plist template do Sources/Clank/Resources/**

W Task 7 utworzyliśmy plik w `Resources/dev.conceptfab.clank.sensor-helper.plist.template`. SPM oczekuje go w `Sources/Clank/Resources/`. Przenieś:

```bash
mv Resources/dev.conceptfab.clank.sensor-helper.plist.template Sources/Clank/Resources/
rmdir Resources 2>/dev/null || true
```

- [ ] **Step 3: Build**

```bash
swift build -c release
```

Oczekiwane: zielony build.

- [ ] **Step 4: Weryfikacja że plist jest w bundle**

```bash
ls .build/release/Clank_Clank.bundle/Contents/Resources/ | grep plist
```

Oczekiwane: `dev.conceptfab.clank.sensor-helper.plist.template`

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/Clank/Resources/
git commit -m "build: ship daemon plist template inside Clank bundle"
```

---

## Task 11: Update Makefile — usunięcie sudoers, dodanie sign/dmg/release/install-helper

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Zastąp całą zawartość Makefile**

```makefile
APP_NAME := Clank
EXECUTABLE := Clank
CONFIGURATION ?= release
BUILD_DIR := build
DIST_DIR := dist
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
ENTITLEMENTS := Clank.entitlements
VERSION := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
DMG_NAME := $(APP_NAME)-$(VERSION).dmg

.PHONY: build run bundle sign dmg release clean install-helper uninstall-helper

build:
	swift build -c $(CONFIGURATION)

run:
	swift run $(EXECUTABLE)

bundle: build
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS" "$(APP_DIR)/Contents/Resources"
	cp ".build/$(CONFIGURATION)/$(EXECUTABLE)" "$(APP_DIR)/Contents/MacOS/$(EXECUTABLE)"
	cp "Info.plist" "$(APP_DIR)/Contents/Info.plist"
	cp "Sources/Clank/Resources/AppIcon.icns" "$(APP_DIR)/Contents/Resources/AppIcon.icns"
	if [ -d ".build/$(CONFIGURATION)/Clank_Clank.bundle" ]; then \
		cp -R ".build/$(CONFIGURATION)/Clank_Clank.bundle" "$(APP_DIR)/Contents/Resources/"; \
	fi
	chmod +x "$(APP_DIR)/Contents/MacOS/$(EXECUTABLE)"

sign: bundle
	@echo "==> Ad-hoc codesign (bez Developer ID)"
	codesign --force --deep --sign - --entitlements "$(ENTITLEMENTS)" "$(APP_DIR)"
	codesign --verify --deep --strict "$(APP_DIR)"
	@echo "Podpis OK (ad-hoc — Gatekeeper bedzie wymagal recznego dopuszczenia)"

dmg: sign
	@./scripts/build-dmg.sh "$(APP_DIR)" "$(DIST_DIR)/$(DMG_NAME)"

release: dmg
	@echo ""
	@echo "==> Wydanie gotowe: $(DIST_DIR)/$(DMG_NAME)"
	@ls -lh "$(DIST_DIR)/$(DMG_NAME)"

clean:
	rm -rf .build "$(BUILD_DIR)" "$(DIST_DIR)"

install-helper: sign
	@./scripts/install-helper.sh "$(APP_DIR)"

uninstall-helper:
	@./scripts/uninstall-helper.sh
```

Zmiany vs. obecny Makefile:
- usunięte `install-sudoers` / `uninstall-sudoers` (workaround sudo)
- dodane `sign` (ad-hoc codesign z entitlements)
- dodane `dmg` (delegacja do scripts/build-dmg.sh)
- dodane `release` (sign → dmg, do dystrybucji)
- dodane `install-helper` / `uninstall-helper` (lokalna instalacja dla testów)
- `VERSION` wyciągana automatycznie z Info.plist

- [ ] **Step 2: Weryfikacja**

```bash
make clean
make bundle
ls -la build/Clank.app/Contents/
```

Oczekiwane: standardowa struktura `.app` z `MacOS/Clank`, `Info.plist`, `Resources/`.

- [ ] **Step 3: Test ad-hoc sign**

```bash
make sign
codesign --display --verbose=2 build/Clank.app 2>&1 | head -20
```

Oczekiwane: linia `Signature=adhoc` i identyfikator.

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "build: rework Makefile — drop sudoers hack, add adhoc sign/dmg/release targets"
```

---

## Task 12: Skrypt build-dmg.sh

**Files:**
- Create: `scripts/build-dmg.sh`

- [ ] **Step 1: Utwórz skrypt**

Zapisz do `scripts/build-dmg.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# build-dmg.sh — pakuje Clank.app w DMG razem ze skryptami instalacyjnymi
#
# Uzycie: ./scripts/build-dmg.sh <Clank.app> <wyjsciowy.dmg>

APP_PATH="${1:?usage: build-dmg.sh <Clank.app> <output.dmg>}"
OUT_DMG="${2:?usage: build-dmg.sh <Clank.app> <output.dmg>}"

if [[ ! -d "${APP_PATH}" ]]; then
    echo "blad: nie znaleziono ${APP_PATH}" >&2
    exit 1
fi

OUT_DIR="$(dirname "${OUT_DMG}")"
mkdir -p "${OUT_DIR}"

STAGE="$(mktemp -d -t clank-dmg.XXXXXX)"
trap 'rm -rf "${STAGE}"' EXIT

echo "==> Przygotowuje zawartosc DMG w ${STAGE}"
cp -R "${APP_PATH}" "${STAGE}/Clank.app"
cp INSTALL.md "${STAGE}/INSTALL.md"
cp LICENSE "${STAGE}/LICENSE"
mkdir -p "${STAGE}/scripts"
cp scripts/install-helper.sh "${STAGE}/scripts/"
cp scripts/uninstall-helper.sh "${STAGE}/scripts/"
chmod +x "${STAGE}/scripts/"*.sh

# Symlink do /Applications dla ladnego drag-to-install UX
ln -s /Applications "${STAGE}/Applications"

echo "==> Tworze DMG: ${OUT_DMG}"
rm -f "${OUT_DMG}"
hdiutil create \
    -volname "Clank" \
    -srcfolder "${STAGE}" \
    -ov \
    -format UDZO \
    "${OUT_DMG}"

echo ""
echo "Gotowe: ${OUT_DMG}"
ls -lh "${OUT_DMG}"
```

- [ ] **Step 2: Uprawnienia i walidacja**

```bash
chmod +x scripts/build-dmg.sh
bash -n scripts/build-dmg.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/build-dmg.sh
git commit -m "feat(scripts): add build-dmg.sh for distributable DMG creation"
```

---

## Task 13: INSTALL.md dla znajomych

**Files:**
- Create: `INSTALL.md`

- [ ] **Step 1: Utwórz INSTALL.md**

Zapisz do `INSTALL.md`:

````markdown
# Clank — instalacja

Clank to aplikacja na pasek menu macOS, ktora odtwarza dzwieki gdy
czujnik klapy / akcelerometr wykryje uderzenie lub ruch klapy.

**Wymagania:**
- Mac z Apple Silicon (M1 / M2 / M3 / M4 / nowsze)
- macOS 13 Ventura lub nowszy

## Instalacja krok po kroku

### 1. Otwarcie DMG i przeciagniecie aplikacji

1. Otworz `Clank-1.0.0.dmg`
2. Przeciagnij `Clank.app` do folderu `Applications`

### 2. Pierwsze uruchomienie — obejscie Gatekeepera

Aplikacja nie jest podpisana przez Apple (nie kupilismy Developer ID),
wiec macOS zablokuje pierwsze uruchomienie. Trzeba to obejsc raz:

**Opcja A — przez Findera (najprostsza):**
1. W `Applications` kliknij `Clank.app` **prawym przyciskiem** (lub Ctrl+klik)
2. Wybierz `Otworz`
3. Pojawi sie ostrzezenie — kliknij `Otworz` jeszcze raz
4. Aplikacja zostaje na bialej liscie. Kolejne uruchomienia juz beda dzialaly normalnie.

**Opcja B — przez Terminal (jezeli A nie zadziala):**
```bash
xattr -dr com.apple.quarantine /Applications/Clank.app
open /Applications/Clank.app
```

### 3. Instalacja helpera sensora (jednorazowo)

Clank potrzebuje uprawnien administratora zeby czytac akcelerometr.
Zamiast prosic o haslo za kazdym razem, instalujemy raz LaunchDaemon
ktory dziala w tle.

W DMG znajdziesz folder `scripts`. Otworz Terminal w tym katalogu
(albo przeciagnij `install-helper.sh` do Terminala) i uruchom:

```bash
./scripts/install-helper.sh /Applications/Clank.app
```

Skrypt poprosi o haslo administratora **raz**. Po wykonaniu:
- helper dziala w tle jako system daemon
- Clank.app moze go uzywac bez sudo
- daemon uruchamia sie automatycznie po restarcie Maca

### 4. Sprawdzenie ze wszystko dziala

1. Otworz `Clank.app` z `Applications`
2. W pasku menu (gora ekranu) powinna pojawic sie ikona Clank
3. Kliknij ikone — w menu rozwinie sie status: `Clank: nasluchuje`
4. Stuknij lekko w obudowe Maca — powinien zagrac dzwiek

Jezeli widzisz `Clank: blad - Helper sensora nie jest zainstalowany`,
wroc do kroku 3.

## Odinstalowanie

```bash
# 1. Helper
./scripts/uninstall-helper.sh

# 2. Aplikacja
rm -rf /Applications/Clank.app
rm -rf ~/Library/Application\ Support/Clank
```

## Diagnostyka

**Helper nie startuje:**
```bash
sudo launchctl print system/dev.conceptfab.clank.sensor-helper | head -20
tail -50 /var/log/clank-helper.log
```

**Sprawdz czy daemon dziala:**
```bash
sudo launchctl list | grep clank
```

Powinno wypisac PID + label `dev.conceptfab.clank.sensor-helper`.

**Brak ikony w pasku menu po uruchomieniu:**
Sprawdz Activity Monitor czy proces `Clank` zyje. Jezeli nie,
otworz Konsole.app, filtruj `Clank` — bedzie tam log bledu.

## Znane ograniczenia (wersja test-friend)

- aplikacja jest Apple Silicon only (Intel Maki nie maja tego akcelerometru)
- parametry detekcji (`Min amplitude`, `Cooldown`) w ustawieniach
  **nie wplywaja** na aktywny helper w tej wersji; sa fixed w plist daemona.
  Zmiana wymaga edycji `/Library/LaunchDaemons/dev.conceptfab.clank.sensor-helper.plist`
  + `sudo launchctl bootout system/... && sudo launchctl bootstrap system/...`.
- aplikacja nie jest podpisana przez Apple — przy kazdym restarcie macOS
  moze pokazac ostrzezenie, jezeli atrybut quarantine zostal odnowiony
  (zazwyczaj nie powraca). W razie potrzeby powtorz `xattr -dr com.apple.quarantine`.
- brak auto-update — nowe wersje trzeba pobrac recznie.
````

- [ ] **Step 2: Commit**

```bash
git add INSTALL.md
git commit -m "docs: add user-facing INSTALL.md for friend distribution"
```

---

## Task 14: Aktualizacja README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Zastąp całą zawartość README.md**

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README for developer audience, point users to INSTALL.md"
```

---

## Task 15: Aktualizacja .gitignore

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Sprawdź obecny .gitignore**

```bash
cat .gitignore 2>/dev/null || echo "brak .gitignore"
```

- [ ] **Step 2: Dodaj wpisy dla dist/ i DMG**

Dopisz do `.gitignore` (lub utwórz):

```
# Distribution artifacts
dist/
*.dmg
*.zip
```

(jeśli `.gitignore` nie istnieje, utwórz z tą zawartością + wcześniejszymi wpisami które zostały dodane wcześniej dla `.build/` i `build/`)

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: gitignore dist/ and dmg/zip artifacts"
```

---

## Task 16: Manualny smoke test pelnego flow

**Files:** brak

- [ ] **Step 1: Czysty build od zera**

```bash
make clean
make release
```

Oczekiwane:
- bez warningów
- powstaje `dist/Clank-1.0.0.dmg`
- `codesign --verify` zwraca sukces

- [ ] **Step 2: Symulacja instalacji u znajomego**

```bash
# Odpinamy quarantine i symulujemy "swieze pobranie"
xattr -w com.apple.quarantine "0083;65000000;Safari;" "build/Clank.app" 2>/dev/null || true

# Otwieramy DMG
open "dist/Clank-1.0.0.dmg"
```

W oknie DMG:
1. Przeciagnij Clank.app do Applications (jeśli już tam jest, zastąp)
2. Zamknij DMG
3. W Finderze: prawy-klik na `/Applications/Clank.app` → Otwórz → Otwórz
4. Sprawdz że aplikacja startuje (ikona w pasku menu)
5. Status powinien pokazywać `Clank: blad - Helper sensora nie jest zainstalowany`

- [ ] **Step 3: Instalacja helpera**

```bash
./scripts/install-helper.sh /Applications/Clank.app
```

Oczekiwane:
- prompt o sudo password jeden raz
- skrypt wypisuje "Gotowe. Helper dziala jako system daemon."

Weryfikacja:

```bash
sudo launchctl list | grep clank
tail -5 /var/log/clank-helper.log
```

Oczekiwane: PID + label `dev.conceptfab.clank.sensor-helper`. Log pokazuje start.

- [ ] **Step 4: Restart aplikacji**

Z paska menu Clank: `Zakoncz`. Otwórz Clank.app ponownie. Status w menu powinien teraz pokazywać `Clank: nasluchuje`.

Stuknij lekko w obudowę Maca. Powinien zagrać dźwięk.

Otwórz/zamknij klapę MacBooka (z włączonym lid sound w ustawieniach) — powinien zagrać dźwięk klapy.

- [ ] **Step 5: Test odinstalowania**

Zakończ Clank. Następnie:

```bash
./scripts/uninstall-helper.sh
sudo launchctl list | grep clank
```

Oczekiwane: brak wpisu w launchctl po uninstall.

```bash
ls /Library/LaunchDaemons/ | grep clank || echo "OK — usuniete"
ls /usr/local/libexec/clank-sensor-helper 2>/dev/null || echo "OK — usuniete"
```

Oczekiwane: oba „usuniete".

- [ ] **Step 6: Final commit (jeśli były drobne poprawki w trakcie testu)**

Jeśli smoke test wymagał poprawek w skryptach lub kodzie, commituj je tutaj. Inaczej pomiń.

- [ ] **Step 7: Tag release**

```bash
git tag -a v1.0.0 -m "v1.0.0 — first friend-testing release"
```

(NIE pushuj automatycznie — user zdecyduje czy/kiedy.)

---

## Self-Review (zrobione przy pisaniu planu)

**1. Spec coverage:**
- ✅ Sudo każdorazowy → LaunchDaemon (Task 4-9)
- ✅ Bundle ID change (Task 1)
- ✅ LICENSE (Task 1)
- ✅ Wersja (Task 1)
- ✅ Apple Silicon enforcement (Task 2)
- ✅ Entitlements (Task 3)
- ✅ Ad-hoc codesign (Task 11)
- ✅ DMG packaging (Task 12)
- ✅ User docs / Gatekeeper bypass (Task 13)
- ✅ Dev docs (Task 14)
- ✅ Uninstall path (Task 9)
- ✅ Smoke test (Task 16)
- ⚠️ Świadomie POZA zakresem: hardened runtime/notaryzacja (brak Dev ID), Sparkle, runtime config helpera, lokalizacja i18n, Privacy Manifest.

**2. Placeholder scan:** brak TBD/TODO; każdy krok zawiera konkretną komendę lub kod.

**3. Type consistency:**
- `dev.conceptfab.clank` używane w Info.plist, plist template, install/uninstall scripts, SensorHelperClient — konsystentne.
- `/tmp/clank-helper.events` i `/tmp/clank-helper.heartbeat` używane w SensorHelperMain, SensorHelperClient, plist, uninstall — konsystentne.
- `/usr/local/libexec/clank-sensor-helper` używane w install/uninstall scripts i plist template (przez `__HELPER_BINARY__`) — konsystentne.
- `Label`: `dev.conceptfab.clank.sensor-helper` w plist, install, uninstall — konsystentne.

**Ryzyka / decyzje techniczne do potwierdzenia w trakcie wykonywania:**
1. *Lokalizacja plist template wewnątrz bundle*: SPM `.copy("Resources/...")` umieszcza pliki w `Clank_Clank.bundle/Contents/Resources/`. Install-helper.sh próbuje dwóch ścieżek (linia z `SRC_TEMPLATE`); jedna z nich powinna trafić. Jeśli nie — wykonawca musi zrobić `find build/Clank.app -name "*.plist.template"` i poprawić skrypt.
2. *Ad-hoc codesign z entitlements*: macOS pozwala na codesign --sign - z entitlements, ale niektóre entitlements wymagają realnego cert. Nasz entitlements wyłącza tylko sandbox — powinno działać.
3. *KeepAlive: true*: oznacza że demon pracuje cały czas (idle gdy brak heartbeat). Akcelerometr czytany tylko gdy aplikacja żyje. Zużycie CPU w idle ~0%.

---

**Plan complete and saved to `docs/superpowers/plans/2026-05-22-distribution-friends.md`.**

Dwie opcje wykonania:

1. **Subagent-Driven (zalecane)** — dispatchuję świeży subagent dla każdego z 16 tasków, review między taskami, szybka iteracja, czysty kontekst.
2. **Inline Execution** — wykonuję taski w tej sesji używając executing-plans, batch z checkpointami do review.

Którą wybierasz?
