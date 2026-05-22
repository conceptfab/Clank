# Lid-Stop Cutoff Design

**Goal:** Cut the lid sound short when the lid stops moving, with two configurable sliders in preferences: a margin (silence after motion before fade-out) and a maximum total playback duration. Approved by user 2026-04-25.

## Motivation

Today the lid sound (currently empty by default; will become bundled `door.m4a`) plays to its natural end whenever the user opens or closes the lid by an accumulated angle of ≥ `lidAngleThreshold` ([AppDelegate.swift:269-319](../../../Sources/Clank/AppDelegate.swift)). The user wants:

1. **Stop the sound when the lid stops moving** — so audio matches the physical motion. A small configurable margin tolerates very brief pauses mid-motion.
2. **Cap the total playback duration** — even if the lid keeps moving for a long time, the sound never plays longer than a configured maximum. Whichever cutoff fires first wins.

## Detection semantics

The lid sensor emits `LidAngleEvent` only when the angle changes by ≥ 2° ([AccelerometerMonitor.swift:230](../../../Sources/Clank/AccelerometerMonitor.swift)). "Lid stopped moving" therefore means **no `LidAngleEvent` for `lidStopMarginMilliseconds`** (default 200 ms). No additional motion-trend logic is used.

"Maximum playback duration" is measured from the moment `player.play(...)` is invoked until `lidMaxPlaybackMilliseconds` (default 2000 ms) elapses, regardless of motion state.

## Approach

Use AVAudioPlayer's native `setVolume(_:fadeDuration:)` to perform a 100 ms fade-out, then call `stop()`. Native API is the simplest correct option. Manual ramp via `DispatchSourceTimer` was considered and rejected as YAGNI; `AVAudioEngine` was considered and rejected as overkill (would require rewriting the existing `AudioPlayer`).

## Components

### `Sources/Clank/SoundSettings.swift` — `AppSettings`

Add two new fields:

- `var lidStopMarginMilliseconds: Int` — default `200`. Decoded with `decodeIfPresent ... ?? 200`. Clamped to `50...800` in `SettingsStore.normalized(_:)`.
- `var lidMaxPlaybackMilliseconds: Int` — default `2000`. Decoded with `decodeIfPresent ... ?? 2000`. Clamped to `500...5000` in `SettingsStore.normalized(_:)`.

Change the default `lidSoundPath` in `SettingsStore.loadDefaults()` from `""` to the path of bundled `door.m4a` if present, otherwise `""`. New helper `static func bundledLidSounds() -> [URL]` mirrors `bundledPainSounds()`.

`lidSoundEnabled` default stays `false` — user must opt in.

### `Sources/Clank/AudioPlayer.swift`

Two new public methods plus a private state dictionary.

State:

- `private var pendingFadeStops: [URL: DispatchWorkItem] = [:]`

Methods:

- `func fadeOutAndStop(url: URL, fadeDuration: TimeInterval)`
  - Look up `cache[url]`. If absent or `!isPlaying`, return.
  - Call `player.setVolume(0, fadeDuration: fadeDuration)`.
  - Build a `DispatchWorkItem` whose body calls `player.stop()` and removes the entry from `pendingFadeStops`.
  - Cancel any existing item in `pendingFadeStops[url]`, then store the new one.
  - Dispatch it on `.main` after `fadeDuration`.

- `func cancelFade(url: URL, restoreVolume: Float)`
  - If `pendingFadeStops[url]` exists, cancel it and remove it from the dict.
  - Look up `cache[url]`; if present, call `player.setVolume(restoreVolume, fadeDuration: 0)`.

Both methods are main-thread only.

### `Sources/Clank/AppDelegate.swift`

Two independent timers govern lid sound termination:

- **Margin timer** (`pendingLidFade`) — resets on every lid event. Fires after the lid has been still for `lidStopMarginMilliseconds`.
- **Max-playback timer** (`pendingLidMaxPlayback`) — set once when `player.play(...)` is invoked. Does **not** reset on motion. Fires after `lidMaxPlaybackMilliseconds` regardless of motion state.

Whichever fires first triggers the fade and tears down both timers. New stored properties:

- `private var pendingLidFade: DispatchWorkItem?`
- `private var pendingLidMaxPlayback: DispatchWorkItem?`
- `private var currentLidSoundURL: URL?`

New private helper:

```swift
private func startLidPlaybackTimers(url: URL, marginMs: Int, maxMs: Int) {
    pendingLidFade?.cancel()
    pendingLidMaxPlayback?.cancel()

    currentLidSoundURL = url

    let margin = DispatchWorkItem { [weak self] in self?.endLidPlayback(url: url) }
    let maxPlay = DispatchWorkItem { [weak self] in self?.endLidPlayback(url: url) }
    pendingLidFade = margin
    pendingLidMaxPlayback = maxPlay

    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(marginMs), execute: margin)
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(maxMs), execute: maxPlay)
}

private func rescheduleLidMargin(url: URL, marginMs: Int) {
    pendingLidFade?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.endLidPlayback(url: url) }
    pendingLidFade = work
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(marginMs), execute: work)
}

private func endLidPlayback(url: URL) {
    pendingLidFade?.cancel()
    pendingLidMaxPlayback?.cancel()
    pendingLidFade = nil
    pendingLidMaxPlayback = nil
    currentLidSoundURL = nil
    player.fadeOutAndStop(url: url, fadeDuration: 0.1)
}
```

Modifications to `handle(_ event: LidAngleEvent)`:

1. **Near the top**, after the `NotificationCenter.default.post` for measurement and after the `guard Date() >= ignoreSensorEventsUntil else { return }` check, if `currentLidSoundURL != nil`:
   - `player.cancelFade(url: currentLidSoundURL!, restoreVolume: Float(settings.soundVolume))`.
   - `rescheduleLidMargin(url: currentLidSoundURL!, marginMs: settings.lidStopMarginMilliseconds)`. **Do not touch `pendingLidMaxPlayback`** — it keeps counting.
   - **Do NOT return early.** Fall through to angle-tracking and accumulated-delta logic so `lidLastAngle`, `lidMotionDirection`, `lidLastMotionTime` continue to update on every event. The existing `lidSoundCooldownMilliseconds` guard at [AppDelegate.swift:307-310](../../../Sources/Clank/AppDelegate.swift) blocks a second `player.play(...)` while the sound is still alive.
2. **At the bottom**, immediately after the existing `player.play(url: url, volume: settings.soundVolume)` call ([AppDelegate.swift:317](../../../Sources/Clank/AppDelegate.swift)), call `startLidPlaybackTimers(url: url, marginMs: settings.lidStopMarginMilliseconds, maxMs: settings.lidMaxPlaybackMilliseconds)`.

### `Sources/Clank/SettingsWindowController.swift`

Three changes to the **Klapa** tab:

**(a) Add two new sliders.** Stored properties:

- `private let lidStopMarginSlider = NSSlider(value: 200, minValue: 50, maxValue: 800, target: nil, action: nil)`
- `private let lidStopMarginValue = NSTextField(labelWithString: "")`
- `private let lidMaxPlaybackSlider = NSSlider(value: 2000, minValue: 500, maxValue: 5000, target: nil, action: nil)`
- `private let lidMaxPlaybackValue = NSTextField(labelWithString: "")`

Use the existing `sliderRow(slider:value:)` helper. Labels: `"Margines stopu"` and `"Max długość"`.

**(b) Convert `lidCooldownField: NSTextField` to `lidCooldownSlider: NSSlider`.** Replace the `private let lidCooldownField = NSTextField(string: "1200")` declaration with:

- `private let lidCooldownSlider = NSSlider(value: 1200, minValue: 100, maxValue: 5000, target: nil, action: nil)`
- `private let lidCooldownValue = NSTextField(labelWithString: "")`

Replace the `numericRow(field: lidCooldownField, suffix: "ms")` row with `sliderRow(slider: lidCooldownSlider, value: lidCooldownValue)`. Update `loadCurrent()` to set `lidCooldownSlider.doubleValue = Double(settings.lidSoundCooldownMilliseconds)` and `saveCurrent()` to write `Int(lidCooldownSlider.doubleValue)` back. The slider's action handler updates `lidCooldownValue.stringValue = "\(Int(lidCooldownSlider.doubleValue)) ms"` and calls `saveCurrent()`.

**(c) Fix vertical layout.** The Klapa tab currently has a large empty gap between the sensor-action checkbox and the sound-file row. Cause: an `NSStackView` with `distribution = .equalSpacing` (or similar) on the outer container that stretches to fill available space. Change the relevant outer stack's `distribution` to `.fill` (or `.gravityAreas`) and add an explicit `setCustomSpacing(_:after:)` of 12 pt between sections so the result is compact and top-aligned. The exact stack to fix is the one wrapping the Klapa tab content in `setupContent` — the implementation plan identifies it precisely.

Final Klapa tab layout (target):

```
─ Czujnik klapy ─────────────────────────────────
  Akcja:            ☑ Odtwarzaj dźwięk przy ruchu klapy
  Próg ruchu:       [─────●──────] N deg
  Cooldown:         [─────●──────] N ms        (was TextField)
  Margines stopu:   [───●────────] N ms        NEW
  Max długość:      [────●───────] N ms        NEW

─ Dźwięk ────────────────────────────────────────
  Plik:             door.m4a   [Wybierz...] [▶ Odtwórz]
```

## Data flow

```
1. Lid moves ≥ lidAngleThreshold accumulated → player.play(door.m4a, soundVolume)
                                              → startLidPlaybackTimers(url, 200ms, 2000ms)
                                              → pendingLidFade        = workItem A (margin)
                                              → pendingLidMaxPlayback = workItem M (cap)

2. Within 200 ms, new lid event arrives:
   - player.cancelFade(url, restoreVolume: soundVolume)  [fade may not have started yet]
   - rescheduleLidMargin(url, 200ms)
   - pendingLidFade = workItem B
   - pendingLidMaxPlayback unchanged (workItem M still ticking)

3. ...repeat step 2 for every lid event during continuous motion...

4a. (Margin path) 200 ms with no event → workItem B fires → endLidPlayback(url):
    - cancel both timers, null out state
    - player.fadeOutAndStop(url, 0.1)
    - setVolume(0, fadeDuration: 0.1) → schedule player.stop() @ +0.1s

4b. (Cap path) 2000 ms total elapsed (motion still ongoing) → workItem M fires → endLidPlayback(url):
    - identical effect: cancel both timers, fadeOutAndStop

5. After 0.1s fade → player.stop().
```

## Edge cases

| Case | Behaviour |
|---|---|
| Lid resumes during margin fade-out | Step 2 path. `cancelFade` aborts the pending `stop()` and restores volume. Sound continues. |
| Lid resumes during max-playback fade-out | Same as above — `cancelFade` would restore volume. **However**, `endLidPlayback` already nulled `currentLidSoundURL`, so the new event's "early cancel" branch doesn't fire. The sound fades out and stops as intended. (`cancelFade` is never called for max-playback cuts.) |
| Lid resumes after `stop()` completed | Existing `lidSoundCooldownMilliseconds` blocks retrigger. Pre-existing behaviour, not changed. |
| Margin timer fires before max-playback timer | Normal case for fast lid motions. Margin path runs, both timers cancelled. |
| Max-playback timer fires before margin timer | Cap path runs (lid still moving). Both timers cancelled. New motion events see `currentLidSoundURL == nil` and don't try to revive. |
| Test sound menu action ([AppDelegate.swift:362](../../../Sources/Clank/AppDelegate.swift)) | Calls `player.play(url:volume:)` directly without timers. Plays to natural end. Pre-existing, unchanged. |
| Slap event during lid sound playback | `suppressSensorFeedback()` blocks slap for 2 s. Pre-existing, unchanged. |
| `fadeOutAndStop` fires after natural playback end | `setVolume` and `stop()` on a non-playing player are no-ops. Safe. |
| Settings change mid-motion | Margin slider: next `rescheduleLidMargin` reads fresh value. Max-playback slider: the running `pendingLidMaxPlayback` keeps the old value (it was scheduled at play time); next play picks up the new value. Acceptable — cap is a "policy when sound starts" knob. |
| User saves new lid sound mid-fade | `preloadConfiguredSounds()` repopulates the cache. The pending stop work item still references the old URL; if that URL is evicted, `cache[url] == nil` → `stop()` is a no-op. Safe. |

## Tests

Extend `Tests/ClankTests/AudioPlayerTests.swift`:

- `test_fadeOutAndStop_stopsPlayerAfterFadeDuration` — preload, start `play`, call `fadeOutAndStop(url, 0.1)`, wait 0.2 s via `XCTestExpectation`, assert `cachedPlayer(for: url)?.isPlaying == false`.
- `test_cancelFade_restoresVolume_andLeavesPlayerPlaying` — preload, set volume to 0.7, start `play`, call `fadeOutAndStop(url, 0.1)`, immediately call `cancelFade(url, restoreVolume: 0.7)`, wait 0.15 s, assert `player.volume == 0.7 ± 0.05` AND `player.isPlaying == true`.

Both tests skip via `XCTSkip` if `bundledPainSounds().first` is unavailable, consistent with existing pattern.

No `AppDelegate` or `SettingsWindowController` unit test (UI-bound). Manual verification matrix:

| Scenario | Expected |
|---|---|
| Open/close lid quickly (<2 s) | Sound plays, fades out ~300 ms after motion stops. |
| Open/close lid slowly (>2 s of continuous motion) | Sound caps at 2000 ms (or whatever max slider is set to), fades out at the cap. |
| Move lid → pause briefly (<200 ms) → continue | Sound plays continuously, no audible cut. |
| Move lid → stop → resume after 1 s | First sound fades and stops. Second motion blocked by cooldown — silence. |
| Adjust margin slider in prefs | Next motion uses new margin. |
| Adjust max-playback slider in prefs | Next playback (next `play` call) uses new cap; ongoing playback keeps old cap. |
| Adjust cooldown slider in prefs | Next play after cooldown gating uses new value. |

## Bundled assets

`door.m4a` is added to `Sources/Clank/Resources/audio/lid/door.m4a`. New helper `static func bundledLidSounds() -> [URL]` in `SettingsStore` mirrors `bundledPainSounds()`, reading audio from `audio/lid` via `Bundle.module.urls(forResourcesWithExtension:subdirectory:)`. `loadDefaults()` uses `bundledLidSounds().first?.path ?? ""` for `lidSoundPath`. Convention keeps `audio/pain/` and `audio/lid/` symmetrical.

`door.mp3` is **not** committed. AAC (`.m4a`) is sufficient.

## Out of scope

- Configurable fade duration (hardcoded 100 ms).
- Non-linear fade curves (Apple API does linear).
- Restart of finished sound when lid resumes after full stop (`lidSoundCooldownMilliseconds` semantics preserved).
- Bundled lid-sound picker UI (only `door.m4a` for now; user can still browse to a custom path).
- Reusing `pendingFadeStops` in `AudioPlayer` for cross-talk between the margin and max-playback timers — they share the same `fadeOutAndStop` exit point, no shared timer.
