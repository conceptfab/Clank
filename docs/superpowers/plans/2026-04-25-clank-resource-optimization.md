# Clank Resource Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut idle CPU/wake-ups and hot-path allocations in Clank without changing user-visible behaviour (slap detection thresholds, sound playback, lid detection).

**Architecture:** Six independent, sequenced changes. Pure-logic changes (settings snapshot, streaming median) come first under XCTest. Then small hardware-bound changes (CFRunLoop blocking, HID `ReportInterval` increase). Then audio pre-load. Optional final task replaces JSONL-file polling IPC with a FIFO. The app is shippable after every commit; you may stop after any task.

**Tech Stack:** Swift 5.9 (SwiftPM `.executableTarget`), XCTest, AppKit, AVFoundation, IOKit HID, Apple SPU accelerometer driver, FIFO/pipe IPC.

**Hardware requirement for manual verification:** Apple Silicon Mac with `AppleSPUHIDDevice` (the lid + IMU sensors). Helper must run as root.

---

## Pre-flight (manual, optional but recommended)

Take a baseline before touching code so you can prove the optimizations actually help.

- [ ] **P1: Build current main in release.**

```bash
cd /Users/micz/__DEV__/Clank
make clean
make bundle
```

Expected: `build/Clank.app/Contents/MacOS/Clank` exists.

- [ ] **P2: Capture an idle baseline for ~60 s.**

```bash
sudo build/Clank.app/Contents/MacOS/Clank &
APP_PID=$!
sleep 5
sudo powermetrics --samplers tasks -n 6 -i 10000 \
  --show-process-samp-mads --show-process-wait-times \
  | grep -E "^Clank|PID" > /tmp/clank-before.txt
kill $APP_PID
```

Expected: `/tmp/clank-before.txt` shows `Clank` rows with non-trivial `wakeups` and `%cpu`. Note the numbers — you will diff against them after Task 4 and Task 5.

- [ ] **P3 (optional): Work in a worktree.**

If you'd rather not modify `main` directly:

```bash
git worktree add ../Clank-perf -b perf/resource-optimization
cd ../Clank-perf
```

All subsequent paths in this plan are relative to the Clank repo root, so they resolve in either the main checkout or the worktree.

---

## Task 1: Add Swift test target

**Why:** The next two tasks are pure-logic changes that benefit from XCTest. Currently `Package.swift` has no test target.

**Files:**
- Modify: `Package.swift`
- Create: `Tests/ClankTests/SmokeTests.swift`

- [ ] **Step 1: Add a placeholder test that imports the executable target.**

Create `Tests/ClankTests/SmokeTests.swift`:

```swift
import XCTest
@testable import Clank

final class SmokeTests: XCTestCase {
    func test_soundResolver_levelClampsBelowMin() {
        let settings = AppSettings(
            soundMode: .scaled,
            singleSoundPath: "",
            scaledSoundPaths: Array(repeating: "", count: 5),
            soundVolume: 1.0,
            lidSoundEnabled: false,
            lidSoundPath: "",
            lidAngleThreshold: 4.0,
            lidSoundCooldownMilliseconds: 1200,
            minAmplitude: 0.05,
            cooldownMilliseconds: 750,
            maxScaleAmplitude: 0.15
        )
        let resolver = SoundResolver(settings: settings)
        XCTAssertEqual(resolver.level(for: 0.0), 0)
        XCTAssertEqual(resolver.level(for: 0.05), 0)
        XCTAssertEqual(resolver.level(for: 0.149), 4)
        XCTAssertEqual(resolver.level(for: 1.0), 4)
    }
}
```

- [ ] **Step 2: Add the test target to `Package.swift`.**

Replace the `targets:` block in `Package.swift` so it reads:

```swift
    targets: [
        .executableTarget(
            name: "Clank",
            resources: [
                .copy("Resources/audio")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "ClankTests",
            dependencies: ["Clank"]
        )
    ]
```

- [ ] **Step 3: Run the tests.**

```bash
swift test
```

Expected: `Test Suite 'SmokeTests' passed`. If `@testable import Clank` fails on the executable target with this Swift toolchain, fall back to building Clank as `.target` plus a tiny `ClankApp` `.executableTarget` whose `main.swift` calls into `Clank` — but try the simple form first.

- [ ] **Step 4: Commit.**

```bash
git add Package.swift Tests/ClankTests/SmokeTests.swift
git commit -m "test: add ClankTests target with SoundResolver smoke test"
```

---

## Task 2: Cache settings snapshot in `SlapDetector`

**Why:** `SlapDetector.process(_:)` calls `settingsProvider()` (which reads `SettingsStore.shared.settings`) on every accelerometer sample — currently ~125×/s on the audio hot path. The settings only change when the user opens the prefs window, so caching a snapshot and refreshing on `SettingsStore.changedNotification` removes the per-sample lookup entirely.

**Files:**
- Modify: `Sources/Clank/SlapDetector.swift`
- Create: `Tests/ClankTests/SlapDetectorTests.swift`

- [ ] **Step 1: Write a failing test that asserts the provider is called only once across many samples.**

Create `Tests/ClankTests/SlapDetectorTests.swift`:

```swift
import XCTest
@testable import Clank

final class SlapDetectorTests: XCTestCase {
    private func makeSettings(min: Double = 0.05, cooldown: Int = 750) -> AppSettings {
        AppSettings(
            soundMode: .single,
            singleSoundPath: "",
            scaledSoundPaths: Array(repeating: "", count: 5),
            soundVolume: 1.0,
            lidSoundEnabled: false,
            lidSoundPath: "",
            lidAngleThreshold: 4.0,
            lidSoundCooldownMilliseconds: 1200,
            minAmplitude: min,
            cooldownMilliseconds: cooldown,
            maxScaleAmplitude: 0.15
        )
    }

    func test_settingsProvider_isCalledOnceUntilRefresh() {
        var calls = 0
        let detector = SlapDetector(settingsProvider: {
            calls += 1
            return self.makeSettings()
        })

        for _ in 0..<200 {
            _ = detector.process(AccelSample(x: 0, y: 0, z: 0.001))
        }
        XCTAssertEqual(calls, 1, "expected snapshot reuse, got \(calls) provider calls")

        detector.refreshSettings()
        for _ in 0..<200 {
            _ = detector.process(AccelSample(x: 0, y: 0, z: 0.001))
        }
        XCTAssertEqual(calls, 2, "expected exactly one extra call after refreshSettings()")
    }
}
```

- [ ] **Step 2: Run the test and confirm it fails.**

```bash
swift test --filter SlapDetectorTests/test_settingsProvider_isCalledOnceUntilRefresh
```

Expected: failure (`expected snapshot reuse, got 200 provider calls` or similar — `refreshSettings()` doesn't exist yet).

- [ ] **Step 3: Make `SlapDetector` cache the snapshot.**

Edit `Sources/Clank/SlapDetector.swift` to replace the `settingsProvider`/usage with a cached snapshot. Replace the body of `final class SlapDetector` so it reads:

```swift
final class SlapDetector {
    private let settingsProvider: () -> AppSettings
    private var cachedSettings: AppSettings

    private var hpReady = false
    private var previousRaw = AccelSample(x: 0, y: 0, z: 0)
    private var previousOut = AccelSample(x: 0, y: 0, z: 0)
    private var sta = 0.0
    private var lta = 1e-10
    private var cusumPos = 0.0
    private var cusumNeg = 0.0
    private var cusumMean = 0.0
    private var peakBuffer: [Double] = []
    private var lastEvent = Date.distantPast
    private var sampleCount = 0

    init(settingsProvider: @escaping () -> AppSettings) {
        self.settingsProvider = settingsProvider
        self.cachedSettings = settingsProvider()
    }

    func refreshSettings() {
        cachedSettings = settingsProvider()
    }

    func process(_ sample: AccelSample, at date: Date = Date()) -> SlapEvent? {
        sampleCount += 1

        guard hpReady else {
            hpReady = true
            previousRaw = sample
            return nil
        }

        let alpha = 0.95
        let hx = alpha * (previousOut.x + sample.x - previousRaw.x)
        let hy = alpha * (previousOut.y + sample.y - previousRaw.y)
        let hz = alpha * (previousOut.z + sample.z - previousRaw.z)
        previousRaw = sample
        previousOut = AccelSample(x: hx, y: hy, z: hz)

        let amplitude = sqrt(hx * hx + hy * hy + hz * hz)
        updateBaselines(amplitude)

        let settings = cachedSettings
        let elapsed = date.timeIntervalSince(lastEvent) * 1000.0
        guard elapsed >= Double(settings.cooldownMilliseconds) else { return nil }
        guard amplitude >= settings.minAmplitude else { return nil }

        if shouldTrigger(amplitude) {
            lastEvent = date
            let level = SoundResolver(settings: settings).level(for: amplitude)
            return SlapEvent(amplitude: amplitude, level: level, date: date)
        }

        return nil
    }
```

(Leave `updateBaselines` and `shouldTrigger` private functions untouched.)

- [ ] **Step 4: Wire `refreshSettings()` into the live notification.**

In `Sources/Clank/AccelerometerMonitor.swift`, add an observer in `init` that forwards settings changes to the detector. Replace the `init` so it reads:

```swift
    init(settingsProvider: @escaping () -> AppSettings = { SettingsStore.shared.settings }) {
        detector = SlapDetector(settingsProvider: settingsProvider)
        NotificationCenter.default.addObserver(
            forName: SettingsStore.changedNotification,
            object: nil,
            queue: nil
        ) { [weak detector] _ in
            detector?.refreshSettings()
        }
    }
```

- [ ] **Step 5: Run the test and confirm it passes.**

```bash
swift test --filter SlapDetectorTests
```

Expected: PASS. Also run `swift test` to confirm nothing else regressed.

- [ ] **Step 6: Commit.**

```bash
git add Sources/Clank/SlapDetector.swift Sources/Clank/AccelerometerMonitor.swift Tests/ClankTests/SlapDetectorTests.swift
git commit -m "perf(detector): cache settings snapshot, refresh on changedNotification"
```

---

## Task 3: Replace sort-based median/MAD with a streaming ring buffer

**Why:** Today `peakBuffer` (Swift `Array`) calls `removeFirst(...)` (O(n)) on every overflow and `.sorted()` twice every 10 samples ([Sources/Clank/SlapDetector.swift:104-109](../../Sources/Clank/SlapDetector.swift#L104-L109)). At 125 Hz that is ~12.5×/s sorting two 200-element arrays. A fixed-capacity ring buffer with on-demand sorting (only when the early STA/LTA and CUSUM checks have not already triggered) eliminates the per-overflow shuffle and most of the sorts.

**Files:**
- Create: `Sources/Clank/AmplitudeWindow.swift`
- Create: `Tests/ClankTests/AmplitudeWindowTests.swift`
- Modify: `Sources/Clank/SlapDetector.swift`

- [ ] **Step 1: Write failing tests for the ring buffer + median/MAD computation.**

Create `Tests/ClankTests/AmplitudeWindowTests.swift`:

```swift
import XCTest
@testable import Clank

final class AmplitudeWindowTests: XCTestCase {
    func test_pushOverflow_evictsOldestInOrder() {
        let window = AmplitudeWindow(capacity: 3)
        window.push(1)
        window.push(2)
        window.push(3)
        window.push(4)
        XCTAssertEqual(window.snapshot().sorted(), [2, 3, 4])
    }

    func test_medianAndMAD_matchNaiveImplementation() {
        let values: [Double] = [0.10, 0.05, 0.30, 0.02, 0.07, 0.04, 0.20, 0.06, 0.08, 0.03]
        let window = AmplitudeWindow(capacity: values.count)
        for v in values { window.push(v) }
        let stats = window.medianAndMAD()

        let sorted = values.sorted()
        let expectedMedian = sorted[sorted.count / 2]
        let deviations = sorted.map { abs($0 - expectedMedian) }.sorted()
        let expectedMAD = deviations[deviations.count / 2]

        XCTAssertEqual(stats.median, expectedMedian, accuracy: 1e-12)
        XCTAssertEqual(stats.mad, expectedMAD, accuracy: 1e-12)
    }

    func test_count_reportsHowFullTheWindowIs() {
        let window = AmplitudeWindow(capacity: 4)
        XCTAssertEqual(window.count, 0)
        window.push(0.1)
        window.push(0.2)
        XCTAssertEqual(window.count, 2)
        window.push(0.3); window.push(0.4); window.push(0.5)
        XCTAssertEqual(window.count, 4)
    }
}
```

- [ ] **Step 2: Run, confirm failure.**

```bash
swift test --filter AmplitudeWindowTests
```

Expected: compile error (`AmplitudeWindow` doesn't exist).

- [ ] **Step 3: Create the ring-buffer implementation.**

Create `Sources/Clank/AmplitudeWindow.swift`:

```swift
import Foundation

final class AmplitudeWindow {
    struct Stats {
        let median: Double
        let mad: Double
    }

    private var storage: [Double]
    private var writeIndex = 0
    private var filled = 0
    private let capacity: Int

    init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
        self.storage = Array(repeating: 0, count: capacity)
    }

    var count: Int { filled }

    func push(_ value: Double) {
        storage[writeIndex] = value
        writeIndex = (writeIndex + 1) % capacity
        if filled < capacity { filled += 1 }
    }

    func snapshot() -> [Double] {
        if filled < capacity {
            return Array(storage[0..<filled])
        }
        return Array(storage[writeIndex..<capacity]) + Array(storage[0..<writeIndex])
    }

    func medianAndMAD() -> Stats {
        precondition(filled > 0, "medianAndMAD on empty window")
        var working = snapshot()
        working.sort()
        let median = working[working.count / 2]
        for i in working.indices {
            working[i] = abs(working[i] - median)
        }
        working.sort()
        let mad = working[working.count / 2]
        return Stats(median: median, mad: mad)
    }
}
```

- [ ] **Step 4: Run, confirm pass.**

```bash
swift test --filter AmplitudeWindowTests
```

Expected: PASS.

- [ ] **Step 5: Wire `AmplitudeWindow` into `SlapDetector`.**

Edit `Sources/Clank/SlapDetector.swift`. Replace `private var peakBuffer: [Double] = []` with:

```swift
    private let peakWindow = AmplitudeWindow(capacity: 200)
```

In `updateBaselines(_:)`, replace the `peakBuffer.append`/`removeFirst` block so the function reads:

```swift
    private func updateBaselines(_ amplitude: Double) {
        let energy = amplitude * amplitude
        sta += (energy - sta) / 15.0
        lta += (energy - lta) / 500.0

        cusumMean += 0.0001 * (amplitude - cusumMean)
        cusumPos = max(0, cusumPos + amplitude - cusumMean - 0.0005)
        cusumNeg = max(0, cusumNeg - amplitude + cusumMean - 0.0005)

        peakWindow.push(amplitude)
    }
```

In `shouldTrigger(_:)`, replace the bottom block (from `guard sampleCount % 10 == 0 ...`) so the function reads:

```swift
    private func shouldTrigger(_ amplitude: Double) -> Bool {
        let ratio = sta / (lta + 1e-30)
        if ratio > 2.5 {
            return true
        }

        if cusumPos > 0.01 || cusumNeg > 0.01 {
            cusumPos = 0
            cusumNeg = 0
            return true
        }

        guard sampleCount % 10 == 0, peakWindow.count >= 50 else {
            return amplitude > 0.12
        }

        let stats = peakWindow.medianAndMAD()
        let sigma = 1.4826 * stats.mad + 1e-30
        return abs(amplitude - stats.median) / sigma > 2.0
    }
```

- [ ] **Step 6: Run the full test suite.**

```bash
swift test
```

Expected: all tests PASS.

- [ ] **Step 7: Commit.**

```bash
git add Sources/Clank/AmplitudeWindow.swift Sources/Clank/SlapDetector.swift Tests/ClankTests/AmplitudeWindowTests.swift
git commit -m "perf(detector): replace Array peakBuffer with ring AmplitudeWindow"
```

---

## Task 4: Block on the run loop instead of polling every 0.5 s

**Why:** [Sources/Clank/AccelerometerMonitor.swift:89-91](../../Sources/Clank/AccelerometerMonitor.swift#L89-L91) calls `CFRunLoopRunInMode(.defaultMode, 0.5, true)` in a `while isRunning` loop, waking the sensor thread twice per second whether or not anything happened. Switching to a blocking `CFRunLoopRun()` plus `CFRunLoopStop` gives the same shutdown semantics with no idle wake-ups.

**Files:**
- Modify: `Sources/Clank/AccelerometerMonitor.swift`

This task has no unit test — the run loop is bound to `IOHIDDeviceScheduleWithRunLoop`, which only does anything against real hardware. Verification is manual.

- [ ] **Step 1: Hold a reference to the sensor thread's run loop.**

In `AccelerometerMonitor`, add a private property and assign it inside `run(semaphore:)`. Edit `Sources/Clank/AccelerometerMonitor.swift`:

Add near the other `private var` declarations:

```swift
    private var sensorRunLoop: CFRunLoop?
```

Replace the `run(semaphore:)` body so it reads:

```swift
    private func run(semaphore: DispatchSemaphore) throws {
        try wakeSPUDrivers()
        try registerSensors()
        sensorRunLoop = CFRunLoopGetCurrent()
        semaphore.signal()

        CFRunLoopRun()

        registrations.removeAll()
        sensorRunLoop = nil
    }
```

- [ ] **Step 2: Make `stop()` ask the sensor thread's run loop to exit.**

Replace `stop()` so it reads:

```swift
    func stop() {
        guard isRunning else { return }
        isRunning = false
        if let loop = sensorRunLoop {
            CFRunLoopStop(loop)
        }
    }
```

- [ ] **Step 3: Build and run as root.**

```bash
swift test
make bundle
sudo build/Clank.app/Contents/MacOS/Clank &
APP_PID=$!
sleep 5
```

Expected: app starts, status item appears, no errors on stderr.

- [ ] **Step 4: Verify wakeups dropped vs. the pre-flight baseline.**

```bash
sudo powermetrics --samplers tasks -n 6 -i 10000 \
  --show-process-samp-mads --show-process-wait-times \
  | grep -E "^Clank|PID" > /tmp/clank-after-task4.txt
kill $APP_PID
diff /tmp/clank-before.txt /tmp/clank-after-task4.txt | head -40
```

Expected: `wakeups` for the helper process noticeably lower (the polling thread previously woke 2×/s; now it only wakes on real HID reports).

- [ ] **Step 5: Verify shutdown still works.**

```bash
sudo build/Clank.app/Contents/MacOS/Clank &
APP_PID=$!
sleep 3
kill -INT $APP_PID
sleep 1
ps -p $APP_PID
```

Expected: `ps` reports no such process — `CFRunLoopStop` released the thread cleanly.

- [ ] **Step 6: Commit.**

```bash
git add Sources/Clank/AccelerometerMonitor.swift
git commit -m "perf(sensor): block on CFRunLoopRun instead of 0.5s polling"
```

---

## Task 5: Raise HID `ReportInterval`, drop software decimation

**Why:** [Sources/Clank/AccelerometerMonitor.swift:115](../../Sources/Clank/AccelerometerMonitor.swift#L115) sets `ReportInterval=1000` µs (1 kHz) and then [line 32-33](../../Sources/Clank/AccelerometerMonitor.swift#L32-L33) decimates by 8 to ~125 Hz at the detector. The driver still issues callbacks 1000×/s, 7 of every 8 land in `handleReport` only to be discarded. Setting `ReportInterval=8000` µs (125 Hz) and removing the `imuDecimation` logic produces identical detector input at one-eighth the IPC/syscall traffic.

**Files:**
- Modify: `Sources/Clank/AccelerometerMonitor.swift`

No unit test — driver-bound. Verification is manual against real hardware.

- [ ] **Step 1: Change the driver report interval to 8 ms.**

In `Sources/Clank/AccelerometerMonitor.swift`, inside `wakeSPUDrivers()`, change:

```swift
            setRegistryInt32(service, key: "ReportInterval", value: 1000)
```

to:

```swift
            setRegistryInt32(service, key: "ReportInterval", value: 8000)
```

- [ ] **Step 2: Remove the software decimator.**

Delete the constant declaration:

```swift
    private let imuDecimation = 8
```

Delete the field:

```swift
    private var decimation = 0
```

In `handleReport(_:length:kind:)`, delete:

```swift
        decimation += 1
        guard decimation >= imuDecimation else { return }
        decimation = 0
```

- [ ] **Step 3: Build & run.**

```bash
swift build -c release
make bundle
sudo build/Clank.app/Contents/MacOS/Clank
```

Expected: app launches, `registered sensors: accelerometer=true lid=true` appears on stderr.

- [ ] **Step 4: Manually verify slap detection still triggers.**

Tap the laptop chassis once at the volume you normally use. Expected: a sound plays, status menu shows `Ostatni pomiar: ...`. If it stops triggering, the detector tuning constants (sta/lta in [Sources/Clank/SlapDetector.swift:73-86](../../Sources/Clank/SlapDetector.swift#L73-L86)) assume ~125 Hz input — re-confirm sample rate by adding a temporary `print(sampleCount)` once a second; you should see ~125 increments. If the rate is off (driver clamps `ReportInterval` to a different value), adjust `setRegistryInt32(...,"ReportInterval", ...)` to the value that yields 125 Hz at the callback.

- [ ] **Step 5: Re-run powermetrics and diff against the Task 4 capture.**

```bash
sudo build/Clank.app/Contents/MacOS/Clank &
APP_PID=$!
sleep 5
sudo powermetrics --samplers tasks -n 6 -i 10000 \
  --show-process-samp-mads --show-process-wait-times \
  | grep -E "^Clank|PID" > /tmp/clank-after-task5.txt
kill $APP_PID
diff /tmp/clank-after-task4.txt /tmp/clank-after-task5.txt | head -40
```

Expected: `%cpu` for the root helper drops further (callbacks went from ~1000/s to ~125/s).

- [ ] **Step 6: Commit.**

```bash
git add Sources/Clank/AccelerometerMonitor.swift
git commit -m "perf(sensor): set HID ReportInterval to 8ms, drop software decimation"
```

---

## Task 6: Pre-load `AVAudioPlayer` instances per configured URL

**Why:** [Sources/Clank/AudioPlayer.swift:7-18](../../Sources/Clank/AudioPlayer.swift#L7-L18) instantiates `AVAudioPlayer(contentsOf:)` on every slap, which decodes the file from disk on the main queue. With 5 sounds in scaled mode this is wasteful and adds latency. Pre-loading on settings change keeps a warm `AVAudioPlayer` per URL; `play(url:)` reuses it.

**Files:**
- Modify: `Sources/Clank/AudioPlayer.swift`
- Modify: `Sources/Clank/AppDelegate.swift`
- Create: `Tests/ClankTests/AudioPlayerTests.swift`

- [ ] **Step 1: Write a failing test for cache reuse.**

Create `Tests/ClankTests/AudioPlayerTests.swift`:

```swift
import XCTest
@testable import Clank

final class AudioPlayerTests: XCTestCase {
    private func bundledSound() -> URL? {
        SettingsStore.bundledPainSounds().first
    }

    func test_preload_thenPlay_reusesSameAVAudioPlayer() throws {
        guard let url = bundledSound() else {
            throw XCTSkip("no bundled audio in test runtime")
        }
        let player = AudioPlayer()
        player.preload([url])

        let firstID = ObjectIdentifier(try XCTUnwrap(player.cachedPlayer(for: url)))
        player.play(url: url, volume: 0.0)
        let secondID = ObjectIdentifier(try XCTUnwrap(player.cachedPlayer(for: url)))

        XCTAssertEqual(firstID, secondID, "play should reuse the preloaded AVAudioPlayer")
    }

    func test_preload_evictsURLsNoLongerInList() throws {
        let sounds = SettingsStore.bundledPainSounds()
        guard sounds.count >= 2 else {
            throw XCTSkip("need two bundled sounds")
        }
        let player = AudioPlayer()
        player.preload([sounds[0], sounds[1]])
        XCTAssertNotNil(player.cachedPlayer(for: sounds[0]))
        XCTAssertNotNil(player.cachedPlayer(for: sounds[1]))

        player.preload([sounds[1]])
        XCTAssertNil(player.cachedPlayer(for: sounds[0]))
        XCTAssertNotNil(player.cachedPlayer(for: sounds[1]))
    }
}
```

- [ ] **Step 2: Run, confirm failure.**

```bash
swift test --filter AudioPlayerTests
```

Expected: compile error (`preload`/`cachedPlayer(for:)` don't exist).

- [ ] **Step 3: Implement preloading in `AudioPlayer`.**

Replace the contents of `Sources/Clank/AudioPlayer.swift` with:

```swift
import AVFoundation
import Foundation

final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var cache: [URL: AVAudioPlayer] = [:]

    func preload(_ urls: [URL]) {
        let unique = Set(urls)
        for url in unique where cache[url] == nil {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.delegate = self
                player.prepareToPlay()
                cache[url] = player
            } catch {
                NSLog("Clank: preload failed for \(url.path): \(error.localizedDescription)")
            }
        }
        for key in cache.keys where !unique.contains(key) {
            cache.removeValue(forKey: key)
        }
    }

    func play(url: URL, volume: Double = 1.0) {
        let player: AVAudioPlayer
        if let cached = cache[url] {
            player = cached
        } else {
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player.delegate = self
                player.prepareToPlay()
                cache[url] = player
            } catch {
                NSLog("Clank: cannot play \(url.path): \(error.localizedDescription)")
                return
            }
        }
        player.volume = Float(min(max(volume, 0.0), 1.0))
        if player.isPlaying {
            player.currentTime = 0
        }
        player.play()
    }

    func cachedPlayer(for url: URL) -> AVAudioPlayer? {
        cache[url]
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Keep the cached instance; AVAudioPlayer is reusable after finishing.
    }
}
```

- [ ] **Step 4: Make `AppDelegate` preload on launch and on settings change.**

In `Sources/Clank/AppDelegate.swift`, at the bottom of `applicationDidFinishLaunching(_:)` (after `startMonitoring()`), add:

```swift
        preloadConfiguredSounds()
        NotificationCenter.default.addObserver(
            forName: SettingsStore.changedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.preloadConfiguredSounds()
        }
```

Add this method on `AppDelegate` (place it next to `playPendingSlap()`):

```swift
    private func preloadConfiguredSounds() {
        let settings = settingsStore.settings
        var urls: [URL] = []
        if !settings.singleSoundPath.isEmpty {
            urls.append(URL(fileURLWithPath: settings.singleSoundPath))
        }
        urls.append(contentsOf: settings.scaledSoundPaths
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) })
        if settings.lidSoundEnabled, !settings.lidSoundPath.isEmpty {
            urls.append(URL(fileURLWithPath: settings.lidSoundPath))
        }
        urls.append(contentsOf: SettingsStore.bundledPainSounds())
        player.preload(urls)
    }
```

- [ ] **Step 5: Run the full suite.**

```bash
swift test
```

Expected: all PASS (the new tests may `XCTSkip` if the bundled audio is not visible to the test runtime — that's acceptable).

- [ ] **Step 6: Manual smoke test.**

```bash
make bundle
sudo build/Clank.app/Contents/MacOS/Clank
```

Expected: tap → sound plays. Open settings, change scaled-mode sound; tap → new sound plays without re-decoding artifacts.

- [ ] **Step 7: Commit.**

```bash
git add Sources/Clank/AudioPlayer.swift Sources/Clank/AppDelegate.swift Tests/ClankTests/AudioPlayerTests.swift
git commit -m "perf(audio): preload AVAudioPlayer per URL, reuse on play"
```

---

## Task 7 (largest, optional): Replace JSONL-file polling IPC with a FIFO

**Why:** Today the privileged helper writes `events.jsonl`, the unprivileged client polls it every 100 ms ([Sources/Clank/SensorHelperClient.swift:68-74](../../Sources/Clank/SensorHelperClient.swift#L68-L74)) and writes a heartbeat file every second so the helper knows it can exit ([Sources/Clank/SensorHelperClient.swift:100-104](../../Sources/Clank/SensorHelperClient.swift#L100-L104), [Sources/Clank/SensorHelperMain.swift:43-56](../../Sources/Clank/SensorHelperMain.swift#L43-L56)). Three timers (100 ms client poll, 1 s client heartbeat write, 1 s helper heartbeat read). A FIFO replaces all of them: the helper writes, the client reads via `DispatchSource.read`, and the helper's `write()` returns `EPIPE` when the client closes — natural death detection without heartbeats.

**Risk:** This is the largest change in the plan. The helper is launched via AppleScript with admin privileges, so file-descriptor inheritance is not available. Use a named FIFO (`mkfifo`) at a known temp path; both ends open by path. Stop here if you want a smaller increment.

**Files:**
- Create: `Sources/Clank/HelperEventStream.swift`
- Create: `Tests/ClankTests/HelperEventStreamTests.swift`
- Modify: `Sources/Clank/SensorHelperMain.swift`
- Modify: `Sources/Clank/SensorHelperClient.swift`

- [ ] **Step 1: Write failing tests for line framing.**

Create `Tests/ClankTests/HelperEventStreamTests.swift`:

```swift
import XCTest
@testable import Clank

final class HelperEventStreamTests: XCTestCase {
    func test_drainLines_yieldsCompleteLinesAndKeepsRemainder() {
        var assembler = LineAssembler()
        let chunk1 = Data("{\"a\":1}\n{\"a\":2".utf8)
        let chunk2 = Data("}\n".utf8)
        let lines1 = assembler.append(chunk1)
        XCTAssertEqual(lines1.map { String(data: $0, encoding: .utf8) }, ["{\"a\":1}"])
        let lines2 = assembler.append(chunk2)
        XCTAssertEqual(lines2.map { String(data: $0, encoding: .utf8) }, ["{\"a\":2}"])
    }

    func test_drainLines_skipsEmptyLines() {
        var assembler = LineAssembler()
        let lines = assembler.append(Data("\n\n{\"x\":1}\n\n".utf8))
        XCTAssertEqual(lines.map { String(data: $0, encoding: .utf8) }, ["{\"x\":1}"])
    }
}
```

- [ ] **Step 2: Run, confirm failure.**

```bash
swift test --filter HelperEventStreamTests
```

Expected: compile error (no `LineAssembler`).

- [ ] **Step 3: Create the FIFO + framing module.**

Create `Sources/Clank/HelperEventStream.swift`:

```swift
import Darwin
import Foundation

struct LineAssembler {
    private var pending = Data()

    mutating func append(_ data: Data) -> [Data] {
        pending.append(data)
        var out: [Data] = []
        while let nl = pending.firstIndex(of: 0x0A) {
            let line = pending[..<nl]
            pending.removeSubrange(...nl)
            if !line.isEmpty {
                out.append(Data(line))
            }
        }
        return out
    }
}

enum HelperFIFO {
    static func makeFIFO(at path: String) throws {
        unlink(path)
        if mkfifo(path, 0o600) != 0 {
            let err = String(cString: strerror(errno))
            throw NSError(domain: "Clank.HelperFIFO", code: Int(errno),
                          userInfo: [NSLocalizedDescriptionKey: "mkfifo failed: \(err)"])
        }
    }

    static func openForReading(at path: String) throws -> Int32 {
        let fd = open(path, O_RDONLY | O_NONBLOCK)
        if fd < 0 {
            let err = String(cString: strerror(errno))
            throw NSError(domain: "Clank.HelperFIFO", code: Int(errno),
                          userInfo: [NSLocalizedDescriptionKey: "open(\(path)) failed: \(err)"])
        }
        return fd
    }

    static func openForWriting(at path: String) throws -> Int32 {
        let fd = open(path, O_WRONLY)
        if fd < 0 {
            let err = String(cString: strerror(errno))
            throw NSError(domain: "Clank.HelperFIFO", code: Int(errno),
                          userInfo: [NSLocalizedDescriptionKey: "open(\(path)) failed: \(err)"])
        }
        return fd
    }
}
```

- [ ] **Step 4: Run framing tests.**

```bash
swift test --filter HelperEventStreamTests
```

Expected: PASS.

- [ ] **Step 5: Helper writes events to the FIFO instead of appending to a regular file.**

Edit `Sources/Clank/SensorHelperMain.swift`. Replace `static func run() -> Never` so it reads:

```swift
    static func run() -> Never {
        let options = parseArguments()
        guard let fifoPath = options["events-fifo"] else {
            FileHandle.standardError.write(Data("missing --events-fifo\n".utf8))
            exit(2)
        }

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
            minAmplitude: minAmplitude,
            cooldownMilliseconds: cooldown,
            maxScaleAmplitude: 0.15
        )

        let fd: Int32
        do {
            fd = try HelperFIFO.openForWriting(at: fifoPath)
        } catch {
            FileHandle.standardError.write(Data("fifo open failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
        signal(SIGPIPE, SIG_IGN)

        let monitor = AccelerometerMonitor(settingsProvider: { settings })
        monitor.onEvent = { event in
            send(HelperEvent(kind: "slap", amplitude: event.amplitude, level: event.level, angle: nil, delta: nil, date: event.date), fd: fd)
        }
        monitor.onLidAngleEvent = { event in
            send(HelperEvent(kind: "lid", amplitude: nil, level: nil, angle: event.angle, delta: event.delta, date: event.date), fd: fd)
        }

        do {
            try monitor.start()
        } catch {
            FileHandle.standardError.write(Data("sensor start failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }

        dispatchMain()
    }

    private static func send(_ payload: HelperEvent, fd: Int32) {
        guard var data = try? JSONEncoder().encode(payload) else { return }
        data.append(0x0A)
        let result = data.withUnsafeBytes { buffer -> Int in
            guard let base = buffer.baseAddress else { return 0 }
            return Darwin.write(fd, base, buffer.count)
        }
        if result < 0 {
            // EPIPE means the client closed the FIFO — exit cleanly.
            if errno == EPIPE { exit(0) }
            FileHandle.standardError.write(Data("write failed: \(String(cString: strerror(errno)))\n".utf8))
        }
    }
```

(Delete the old `append(_:to:)` function.)

- [ ] **Step 6: Client creates the FIFO, opens for reading via `DispatchSource.read`.**

Replace the contents of `Sources/Clank/SensorHelperClient.swift` with:

```swift
import AppKit
import Darwin
import Foundation

enum SensorHelperClientError: LocalizedError {
    case missingExecutable
    case launchRejected(String)
    case fifoSetup(String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable: return "brak sciezki do pliku wykonywalnego"
        case .launchRejected(let message): return message
        case .fifoSetup(let message): return message
        }
    }
}

final class SensorHelperClient {
    var onEvent: ((SlapEvent) -> Void)?
    var onLidAngleEvent: ((LidAngleEvent) -> Void)?

    private let settingsProvider: () -> AppSettings
    private let sessionID = UUID().uuidString
    private let fifoURL: URL
    private var readFD: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var assembler = LineAssembler()

    init(settingsProvider: @escaping () -> AppSettings) {
        self.settingsProvider = settingsProvider
        self.fifoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Clank-\(sessionID).events.fifo")
    }

    func start() throws {
        guard let executablePath = Bundle.main.executableURL?.path else {
            throw SensorHelperClientError.missingExecutable
        }

        do {
            try HelperFIFO.makeFIFO(at: fifoURL.path)
            readFD = try HelperFIFO.openForReading(at: fifoURL.path)
        } catch {
            throw SensorHelperClientError.fifoSetup(error.localizedDescription)
        }

        let settings = settingsProvider()
        let helperCommand = [
            executablePath.shellQuoted(),
            "--sensor-helper",
            "--events-fifo", fifoURL.path.shellQuoted(),
            "--min-amplitude", String(format: "%.6f", settings.minAmplitude),
            "--cooldown", "\(settings.cooldownMilliseconds)"
        ].joined(separator: " ")

        let logPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("Clank-\(sessionID).helper.log")
            .path
        let shellCommand = "\(helperCommand) > \(logPath.shellQuoted()) 2>&1 &"
        let script = "do shell script \(shellCommand.appleScriptQuoted()) with administrator privileges"

        var errorInfo: NSDictionary?
        if NSAppleScript(source: script)?.executeAndReturnError(&errorInfo) == nil {
            let message = (errorInfo?[NSAppleScript.errorMessage] as? String) ?? "macOS odrzucil uruchomienie helpera."
            close(readFD); readFD = -1
            unlink(fifoURL.path)
            throw SensorHelperClientError.launchRejected(message)
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: readFD, queue: .main)
        source.setEventHandler { [weak self] in
            self?.drain()
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.readFD >= 0 { Darwin.close(self.readFD) }
            self.readFD = -1
            unlink(self.fifoURL.path)
        }
        source.resume()
        readSource = source
    }

    func stop() {
        readSource?.cancel()
        readSource = nil
    }

    private func drain() {
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = buffer.withUnsafeMutableBufferPointer { ptr -> Int in
                guard let base = ptr.baseAddress else { return 0 }
                return Darwin.read(readFD, base, ptr.count)
            }
            if n > 0 {
                let chunk = Data(bytes: buffer, count: n)
                for line in assembler.append(chunk) {
                    handle(line: line)
                }
                if n < buffer.count { break }
            } else if n == 0 {
                // Helper closed the FIFO — surfaces via cancel.
                stop()
                return
            } else {
                if errno == EAGAIN || errno == EWOULDBLOCK { return }
                NSLog("Clank: read error \(String(cString: strerror(errno)))")
                stop()
                return
            }
        }
    }

    private func handle(line: Data) {
        guard let payload = try? JSONDecoder().decode(HelperEvent.self, from: line) else { return }
        switch payload.kind {
        case "slap":
            guard let amplitude = payload.amplitude, let level = payload.level else { return }
            onEvent?(SlapEvent(amplitude: amplitude, level: level, date: payload.date))
        case "lid":
            guard let angle = payload.angle, let delta = payload.delta else { return }
            onLidAngleEvent?(LidAngleEvent(angle: angle, delta: delta, date: payload.date))
        default:
            return
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

- [ ] **Step 7: Build and integration-test.**

```bash
swift test
make bundle
sudo build/Clank.app/Contents/MacOS/Clank
```

Expected: app launches, helper starts, tap → sound plays. Open Activity Monitor and verify `Clank` (helper) and `Clank` (UI) are both present and idle CPU is near zero.

- [ ] **Step 8: Verify helper exits when the UI quits.**

```bash
sudo build/Clank.app/Contents/MacOS/Clank &
APP_PID=$!
sleep 3
ps -ax | grep -E "Clank.*sensor-helper" | grep -v grep
kill -INT $APP_PID
sleep 2
ps -ax | grep -E "Clank.*sensor-helper" | grep -v grep
```

Expected: helper present after `sleep 3`, gone after the second check (UI closed the FIFO → helper got `EPIPE` → exited).

- [ ] **Step 9: Final powermetrics diff.**

```bash
sudo build/Clank.app/Contents/MacOS/Clank &
APP_PID=$!
sleep 5
sudo powermetrics --samplers tasks -n 6 -i 10000 \
  --show-process-samp-mads --show-process-wait-times \
  | grep -E "^Clank|PID" > /tmp/clank-after-task7.txt
kill $APP_PID
diff /tmp/clank-before.txt /tmp/clank-after-task7.txt
```

Expected: UI process wakeups dropped from ~10/s (the 100 ms timer) plus 1/s (heartbeat write) toward the noise floor.

- [ ] **Step 10: Commit.**

```bash
git add Sources/Clank/HelperEventStream.swift Sources/Clank/SensorHelperMain.swift Sources/Clank/SensorHelperClient.swift Tests/ClankTests/HelperEventStreamTests.swift
git commit -m "perf(ipc): replace polled events.jsonl + heartbeat with FIFO streaming"
```

---

## Self-review

**Spec coverage** — every recommendation from the prior analysis maps to a task:

| Recommendation | Task |
|---|---|
| HID `ReportInterval` + drop decimation | 5 |
| Pipe-based IPC (no file polling, no heartbeat) | 7 |
| `CFRunLoopRun()` blocking | 4 |
| Streaming median/MAD | 3 |
| Pre-load `AVAudioPlayer` instances | 6 |
| Cache settings snapshot in detector | 2 |

**Type/name consistency** — `AmplitudeWindow` (Task 3) is referenced exactly the same way in `SlapDetector.swift` (Step 5). `LineAssembler` and `HelperFIFO` (Task 7 Step 3) are used by the same names in Steps 5 and 6. `preload(_:)` and `cachedPlayer(for:)` introduced in Task 6 Step 1 are implemented in Step 3 with matching signatures.

**Placeholder scan** — no "TBD", no "add appropriate error handling" hand-waves, every code step ships actual code. Manual-test steps are explicitly labelled as such, with the exact commands and expected output.

**Independent shippability** — every commit leaves `swift test` green and the app functional. Tasks can be stopped after any number 1–7.
