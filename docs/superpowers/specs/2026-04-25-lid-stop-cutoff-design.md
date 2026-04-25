# Lid-Stop Cutoff Design

**Goal:** Cut the lid sound short when the lid stops moving, with a configurable margin in preferences. Approved by user 2026-04-25.

## Motivation

Today the lid sound (currently empty by default; will become bundled `door.m4a`) plays to its natural end whenever the user opens or closes the lid by an accumulated angle of ≥ `lidAngleThreshold` ([AppDelegate.swift:269-319](../../../Sources/Clank/AppDelegate.swift)). The user wants the sound interrupted as soon as the lid stops moving so the audio matches the physical motion. A small configurable margin tolerates very brief pauses mid-motion.

## Detection semantics

The lid sensor emits `LidAngleEvent` only when the angle changes by ≥ 2° ([AccelerometerMonitor.swift:230](../../../Sources/Clank/AccelerometerMonitor.swift)). "Lid stopped moving" therefore means **no `LidAngleEvent` for `lidStopMarginMilliseconds`** (default 200 ms). No additional motion-trend logic is used.

## Approach

Use AVAudioPlayer's native `setVolume(_:fadeDuration:)` to perform a 100 ms fade-out, then call `stop()`. Native API is the simplest correct option. Manual ramp via `DispatchSourceTimer` was considered and rejected as YAGNI; `AVAudioEngine` was considered and rejected as overkill (would require rewriting the existing `AudioPlayer`).

## Components

### `Sources/Clank/SoundSettings.swift` — `AppSettings`

Add a new field:

- `var lidStopMarginMilliseconds: Int` — default `200`. Decoded with `decodeIfPresent ... ?? 200` in the custom `init(from:)` for forward compatibility with stored settings written before this feature. Clamped to `50...800` in `SettingsStore.normalized(_:)`.

Change the default `lidSoundPath` in `SettingsStore.loadDefaults()` from `""` to the path of bundled `door.m4a` if present, otherwise `""`. New helper `static func bundledLidSounds() -> [URL]` mirrors `bundledPainSounds()` and reads `audio/door` (or `audio/lid` — whichever subfolder we choose; see "Bundled assets" below). `loadDefaults()` picks `bundledLidSounds().first?.path ?? ""`.

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

Both methods are main-thread only (matches existing `play(url:volume:)` contract).

### `Sources/Clank/AppDelegate.swift`

In `handle(_ event: LidAngleEvent)` — after the existing accumulated-delta logic that decides to call `player.play(url: url, volume: settings.soundVolume)` ([AppDelegate.swift:316-318](../../../Sources/Clank/AppDelegate.swift)) — capture the URL and schedule a fade. New behaviour at the entry of every lid event (BEFORE running the accumulated-delta logic): if `pendingLidFade != nil`, the lid is still moving — cancel the pending fade and reschedule.

New stored properties on `AppDelegate`:

- `private var pendingLidFade: DispatchWorkItem?`
- `private var currentLidSoundURL: URL?`

New private method:

```swift
private func scheduleLidFade(url: URL, marginMilliseconds: Int) {
    pendingLidFade?.cancel()
    let work = DispatchWorkItem { [weak self] in
        self?.player.fadeOutAndStop(url: url, fadeDuration: 0.1)
        self?.pendingLidFade = nil
        self?.currentLidSoundURL = nil
    }
    pendingLidFade = work
    currentLidSoundURL = url
    DispatchQueue.main.asyncAfter(
        deadline: .now() + .milliseconds(marginMilliseconds),
        execute: work
    )
}
```

Modifications to `handle(_ event: LidAngleEvent)`:

1. **Near the top**, after the `NotificationCenter.default.post` for measurement and after the `guard Date() >= ignoreSensorEventsUntil else { return }` check (so a slap-suppressed window doesn't keep extending the fade timer), if `pendingLidFade != nil` AND `currentLidSoundURL != nil`:
   - `player.cancelFade(url: currentLidSoundURL!, restoreVolume: Float(settings.soundVolume))`.
   - Reschedule via `scheduleLidFade(url: currentLidSoundURL!, marginMilliseconds: settings.lidStopMarginMilliseconds)` (which internally cancels the previous work item).
   - **Do NOT return early.** Fall through to the existing angle-tracking and accumulated-delta logic so `lidLastAngle`, `lidMotionDirection`, and `lidLastMotionTime` continue to update on every event. The existing `lidSoundCooldownMilliseconds` guard at [AppDelegate.swift:307-310](../../../Sources/Clank/AppDelegate.swift) naturally blocks a second `player.play(...)` while the sound is still alive, so no double-trigger occurs.
2. **At the bottom**, where the existing code calls `player.play(url:volume:)` ([AppDelegate.swift:317](../../../Sources/Clank/AppDelegate.swift)), immediately after that call, also call `scheduleLidFade(url: url, marginMilliseconds: settings.lidStopMarginMilliseconds)`.

### `Sources/Clank/SettingsWindowController.swift`

Add stored properties:

- `private let lidStopMarginSlider = NSSlider(value: 200, minValue: 50, maxValue: 800, target: nil, action: nil)`
- `private let lidStopMarginValue = NSTextField(labelWithString: "")`

In the lid section of the settings layout (next to the existing `lidThresholdSlider` row at [SettingsWindowController.swift:19](../../../Sources/Clank/SettingsWindowController.swift)), add a new row using the existing `sliderRow(slider:value:)` helper. The label is `"Margines zatrzymania klapy"`.

Wire-up:

- `loadCurrent()` reads `settings.lidStopMarginMilliseconds` into the slider, formats `"\(Int(slider.doubleValue)) ms"` into the value label.
- The slider's action handler updates `lidStopMarginValue` and triggers `saveCurrent()`, identical pattern to `lidThresholdSlider`.
- `saveCurrent()` writes `Int(lidStopMarginSlider.doubleValue)` to `settings.lidStopMarginMilliseconds`.

## Data flow

```
1. Lid moves ≥ lidAngleThreshold accumulated → player.play(door.m4a, soundVolume)
                                              → scheduleLidFade(url, 200ms)
                                              → pendingLidFade = workItem A

2. Within 200 ms, new lid event arrives:
   - cancel workItem A
   - player.cancelFade(url, restoreVolume: soundVolume)  [fade may not have started yet]
   - scheduleLidFade(url, 200ms)
   - pendingLidFade = workItem B

3. ...repeat step 2 for every lid event during continuous motion...

4. 200 ms with no event → workItem B fires:
   - player.fadeOutAndStop(url, 0.1)
     → player.setVolume(0, fadeDuration: 0.1)
     → schedule player.stop() @ +0.1s
   - pendingLidFade = nil
   - currentLidSoundURL = nil

5. After 0.1 s → player.stop().
```

## Edge cases

| Case | Behaviour |
|---|---|
| Lid resumes during fade-out (steps 4 → 5 window) | Step 2 path. `cancelFade` aborts the pending `stop()` and restores volume to `soundVolume`. Sound continues seamlessly. |
| Lid resumes after `stop()` completed | Existing `lidSoundCooldownMilliseconds` (default 1200 ms) blocks retrigger. Pre-existing behaviour, **not changed by this feature**. If this becomes a UX issue, address it in a separate task. |
| Test sound menu action ([AppDelegate.swift:362](../../../Sources/Clank/AppDelegate.swift)) | Calls `player.play(url:volume:)` directly without `scheduleLidFade`. Plays to natural end. Pre-existing, unchanged. |
| Slap event during lid sound playback | `suppressSensorFeedback()` (existing, [AppDelegate.swift:325-328](../../../Sources/Clank/AppDelegate.swift)) blocks slap for 2 s. Unchanged. |
| `fadeOutAndStop` fires after the player ended naturally | `setVolume` and `stop()` on a non-playing player are no-ops. Guard `!isPlaying` short-circuits in `fadeOutAndStop`. Safe. |
| Settings change mid-motion (slider moved while lid is moving) | The next `scheduleLidFade` call reads the fresh `settings.lidStopMarginMilliseconds`. No restart needed. |
| User saves new lid sound mid-fade | `preloadConfiguredSounds()` (existing observer) repopulates the cache. The pending `stop()` work item still references the old URL via the captured `url` parameter; if that URL is evicted, `cache[url]` is `nil` and `stop()` becomes a no-op. The new URL has not been played yet so no fade is scheduled for it. Acceptable. |

## Tests

Extend `Tests/ClankTests/AudioPlayerTests.swift`:

- `test_fadeOutAndStop_stopsPlayerAfterFadeDuration` — preload, start `play`, call `fadeOutAndStop(url, 0.1)`, wait 0.2 s via `XCTestExpectation`, assert `cachedPlayer(for: url)?.isPlaying == false`.
- `test_cancelFade_restoresVolume_andLeavesPlayerPlaying` — preload, set volume to 0.7, start `play`, call `fadeOutAndStop(url, 0.1)`, immediately call `cancelFade(url, restoreVolume: 0.7)`, wait 0.15 s (longer than fadeDuration), assert `player.volume == 0.7 ± 0.05` AND `player.isPlaying == true`.

Both tests skip via `XCTSkip` if `bundledPainSounds().first` is not visible to the test runtime (consistent with existing test pattern).

No `AppDelegate` unit test: the class is bound to `NSStatusItem` and `NSApplication`, hard to test in isolation. Verification of the `scheduleLidFade` orchestration is manual: open the lid → confirm sound plays → stop moving lid → confirm sound fades out within ~300 ms (200 ms margin + 100 ms fade).

## Bundled assets

`door.m4a` is added to `Sources/Clank/Resources/audio/lid/door.m4a`. New helper `static func bundledLidSounds() -> [URL]` in `SettingsStore` mirrors `bundledPainSounds()`, reading `m4a` (and any other audio extensions if needed) from `audio/lid` via `Bundle.module.urls(forResourcesWithExtension:subdirectory:)`. `loadDefaults()` uses `bundledLidSounds().first?.path ?? ""` for `lidSoundPath`. This convention keeps `audio/pain/` and `audio/lid/` symmetrical and easy to extend.

`door.mp3` is **not** committed. AAC (`.m4a`) is sufficient.

## Out of scope

- Configurable fade duration (hardcoded 100 ms).
- Non-linear fade curves (Apple API does linear).
- Restart of finished sound when lid resumes after full stop (`lidSoundCooldownMilliseconds` semantics preserved).
- Bundled lid-sound picker UI (only `door.m4a` for now; user can still browse to a custom path via the existing file picker).
- Slider for fade duration in preferences (YAGNI).
