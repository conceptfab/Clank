import AppKit
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let monitor = AccelerometerMonitor()
    private var helperClient: SensorHelperClient?
    private let player = AudioPlayer()
    private let settingsStore = SettingsStore.shared

    private var menu = NSMenu()
    private var stateItem = NSMenuItem()
    private var toggleItem = NSMenuItem()
    private var lastEventItem = NSMenuItem()
    private var singleModeItem = NSMenuItem()
    private var scaledModeItem = NSMenuItem()
    private var settingsWindowController: SettingsWindowController?
    private var isRunning = false
    private var lastError: String?
    private var lastLidSoundTime = Date.distantPast
    private var lidReferenceAngle: Double?
    private var lidLastAngle: Double?
    private var lidMotionDirection = 0
    private var lidLastMotionTime = Date.distantPast
    private var ignoreSensorEventsUntil = Date.distantPast
    private var pendingSlapPeakAmplitude: Double?
    private var pendingSlapPlayback: DispatchWorkItem?
    private var pendingLidFade: DispatchWorkItem?
    private var pendingLidMaxPlayback: DispatchWorkItem?
    private var currentLidSoundURL: URL?

    private let selfNoiseGuard: TimeInterval = 2.0
    private let lidMotionContinuityWindow: TimeInterval = 0.8
    private let slapPeakWindow: TimeInterval = 0.16

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let image = appIconImage() {
            NSApplication.shared.applicationIconImage = image
        }
        configureStatusItem()
        rebuildMenu()
        monitor.onEvent = { [weak self] event in
            self?.handle(event)
        }
        monitor.onLidAngleEvent = { [weak self] event in
            self?.handle(event)
        }
        startMonitoring()
        preloadConfiguredSounds()
        NotificationCenter.default.addObserver(
            forName: SettingsStore.changedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.preloadConfiguredSounds()
        }
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            statusItem.length = 28
            button.image = appIconImage(size: NSSize(width: 18, height: 18)) ?? fallbackMenuBarImage()
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = "Clank"
        }
    }

    private func appIconImage(size: NSSize? = nil) -> NSImage? {
        guard let url = Bundle.module.url(forResource: "icon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        if let size {
            image.size = size
        }
        image.isTemplate = false
        image.accessibilityDescription = "Clank"
        return image
    }

    private func fallbackMenuBarImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.labelColor.setStroke()

        let outer = NSBezierPath(ovalIn: NSRect(x: 2.0, y: 2.0, width: 14.0, height: 14.0))
        outer.lineWidth = 1.8
        outer.stroke()

        let wave = NSBezierPath()
        wave.lineWidth = 1.7
        wave.lineCapStyle = .round
        wave.lineJoinStyle = .round
        wave.move(to: NSPoint(x: 4.0, y: 9.0))
        wave.line(to: NSPoint(x: 6.5, y: 9.0))
        wave.line(to: NSPoint(x: 8.0, y: 5.0))
        wave.line(to: NSPoint(x: 10.2, y: 13.0))
        wave.line(to: NSPoint(x: 11.8, y: 9.0))
        wave.line(to: NSPoint(x: 14.0, y: 9.0))
        wave.stroke()

        image.isTemplate = true
        image.accessibilityDescription = "Clank"
        return image
    }

    private func rebuildMenu() {
        menu = NSMenu()

        stateItem = NSMenuItem(title: stateTitle(), action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        lastEventItem = NSMenuItem(title: "Ostatni pomiar: brak", action: nil, keyEquivalent: "")
        lastEventItem.isEnabled = false
        menu.addItem(lastEventItem)

        menu.addItem(.separator())

        toggleItem = NSMenuItem(title: isRunning ? "Wstrzymaj detekcje" : "Wlacz detekcje",
                                action: #selector(toggleMonitoring),
                                keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let modeItem = NSMenuItem(title: "Tryb dzwiekow", action: nil, keyEquivalent: "")
        let modeMenu = NSMenu()

        singleModeItem = NSMenuItem(title: "1 dzwiek", action: #selector(setSingleSoundMode), keyEquivalent: "")
        singleModeItem.target = self
        modeMenu.addItem(singleModeItem)

        scaledModeItem = NSMenuItem(title: "5 dzwiekow wedlug sily", action: #selector(setScaledSoundMode), keyEquivalent: "")
        scaledModeItem.target = self
        modeMenu.addItem(scaledModeItem)

        modeItem.submenu = modeMenu
        menu.addItem(modeItem)

        let settings = NSMenuItem(title: "Ustawienia...", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let test = NSMenuItem(title: "Test dzwieku", action: #selector(testSound), keyEquivalent: "")
        test.target = self
        menu.addItem(test)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Zakoncz", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func stateTitle() -> String {
        if let lastError {
            return "Clank: blad - \(lastError)"
        }
        return isRunning ? "Clank: nasluchuje" : "Clank: zatrzymany"
    }

    private func refreshMenuState() {
        stateItem.title = stateTitle()
        toggleItem.title = isRunning ? "Wstrzymaj detekcje" : "Wlacz detekcje"
        singleModeItem.state = settingsStore.settings.soundMode == .single ? .on : .off
        scaledModeItem.state = settingsStore.settings.soundMode == .scaled ? .on : .off
    }

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

    private func stopMonitoring() {
        monitor.stop()
        helperClient?.stop()
        helperClient = nil
        pendingSlapPlayback?.cancel()
        pendingSlapPlayback = nil
        pendingSlapPeakAmplitude = nil
        pendingLidFade?.cancel()
        pendingLidFade = nil
        pendingLidMaxPlayback?.cancel()
        pendingLidMaxPlayback = nil
        currentLidSoundURL = nil
        isRunning = false
        refreshMenuState()
    }

    private func startPrivilegedHelper() {
        let client = SensorHelperClient(settingsProvider: { SettingsStore.shared.settings })
        client.onEvent = { [weak self] event in
            self?.handle(event)
        }
        client.onLidAngleEvent = { [weak self] event in
            self?.handle(event)
        }

        do {
            try client.start()
            helperClient = client
            isRunning = true
            lastError = nil
        } catch {
            isRunning = false
            lastError = error.localizedDescription
            showPermissionAlert(error)
        }

        refreshMenuState()
    }

    private func showPermissionAlertIfNeeded(_ error: Error) {
        guard geteuid() != 0 else {
            showPermissionAlert(error)
            return
        }
        showPermissionAlert(error)
    }

    private func showPermissionAlert(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Clank potrzebuje uprawnien administratora"
        alert.informativeText = "Nie udalo sie uruchomic helpera sensora: \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func handle(_ event: SlapEvent) {
        let settings = settingsStore.settings
        let resolver = SoundResolver(settings: settings)
        let level = resolver.level(for: event.amplitude)
        NotificationCenter.default.post(
            name: .clankSlapMeasurement,
            object: self,
            userInfo: ["amplitude": event.amplitude, "level": level]
        )

        guard Date() >= ignoreSensorEventsUntil else { return }

        if let currentPeak = pendingSlapPeakAmplitude {
            pendingSlapPeakAmplitude = max(currentPeak, event.amplitude)
            return
        }

        pendingSlapPeakAmplitude = event.amplitude
        let work = DispatchWorkItem { [weak self] in
            self?.playPendingSlap()
        }
        pendingSlapPlayback = work
        DispatchQueue.main.asyncAfter(deadline: .now() + slapPeakWindow, execute: work)
    }

    private func playPendingSlap() {
        guard let amplitude = pendingSlapPeakAmplitude else { return }
        pendingSlapPeakAmplitude = nil
        pendingSlapPlayback = nil

        guard Date() >= ignoreSensorEventsUntil else { return }

        let settings = settingsStore.settings
        let resolver = SoundResolver(settings: settings)
        guard let url = resolver.soundURL(for: amplitude) else { return }
        let level = resolver.level(for: amplitude)

        NotificationCenter.default.post(
            name: .clankSlapMeasurement,
            object: self,
            userInfo: ["amplitude": amplitude, "level": level]
        )

        suppressSensorFeedback()
        player.play(url: url, volume: settings.soundVolume)
        lastEventItem.title = String(format: "Ostatni pomiar: %.4fg, poziom %d/5", amplitude, level + 1)
    }

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
        urls.append(contentsOf: SettingsStore.bundledLidSounds())
        player.preload(urls)
    }

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

    private func handle(_ event: LidAngleEvent) {
        NotificationCenter.default.post(
            name: .clankLidMeasurement,
            object: self,
            userInfo: ["angle": event.angle, "delta": event.delta]
        )

        guard Date() >= ignoreSensorEventsUntil else { return }

        let settings = settingsStore.settings
        guard settings.lidSoundEnabled else { return }

        if let activeURL = currentLidSoundURL {
            player.cancelFade(url: activeURL, restoreVolume: Float(settings.soundVolume))
            rescheduleLidMargin(url: activeURL, marginMs: settings.lidStopMarginMilliseconds)
        }

        let now = Date()
        guard let previousAngle = lidLastAngle else {
            lidLastAngle = event.angle
            lidReferenceAngle = event.angle
            return
        }

        let step = event.angle - previousAngle
        guard abs(step) >= 2.0 else { return }

        let direction = step > 0 ? 1 : -1
        if now.timeIntervalSince(lidLastMotionTime) > lidMotionContinuityWindow || direction != lidMotionDirection {
            lidReferenceAngle = previousAngle
            lidMotionDirection = direction
        }

        lidLastAngle = event.angle
        lidLastMotionTime = now

        let reference = lidReferenceAngle ?? previousAngle
        let accumulatedDelta = abs(event.angle - reference)
        guard accumulatedDelta >= settings.lidAngleThreshold else { return }

        lidReferenceAngle = event.angle
        lidMotionDirection = 0

        let elapsed = Date().timeIntervalSince(lastLidSoundTime) * 1000.0
        if elapsed < Double(settings.lidSoundCooldownMilliseconds) {
            return
        }

        let url = URL(fileURLWithPath: settings.lidSoundPath)
        guard !settings.lidSoundPath.isEmpty, FileManager.default.fileExists(atPath: url.path) else { return }

        lastLidSoundTime = Date()
        suppressSensorFeedback()
        player.play(url: url, volume: settings.soundVolume)
        startLidPlaybackTimers(
            url: url,
            marginMs: settings.lidStopMarginMilliseconds,
            maxMs: settings.lidMaxPlaybackMilliseconds
        )
        lastEventItem.title = String(format: "Kat klapy: %.0f deg, zmiana %.0f deg", event.angle, accumulatedDelta)
    }

    private func suppressSensorFeedback() {
        ignoreSensorEventsUntil = Date().addingTimeInterval(selfNoiseGuard)
    }

    @objc private func toggleMonitoring() {
        isRunning ? stopMonitoring() : startMonitoring()
    }

    @objc private func openSettings() {
        let controller = settingsWindowController ?? SettingsWindowController()
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func setSingleSoundMode() {
        var settings = settingsStore.settings
        settings.soundMode = .single
        settingsStore.save(settings)
        refreshMenuState()
    }

    @objc private func setScaledSoundMode() {
        var settings = settingsStore.settings
        settings.soundMode = .scaled
        settingsStore.save(settings)
        refreshMenuState()
    }

    @objc private func testSound() {
        let resolver = SoundResolver(settings: settingsStore.settings)
        if let url = resolver.soundURL(for: 0.05) {
            player.play(url: url, volume: settingsStore.settings.soundVolume)
        }
    }

    @objc private func quit() {
        stopMonitoring()
        NSApp.terminate(nil)
    }
}

extension String {
    func shellQuoted() -> String {
        "'\(replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    func appleScriptQuoted() -> String {
        "\"\(replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}
