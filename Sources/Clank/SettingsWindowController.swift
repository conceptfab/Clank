import AppKit
import UniformTypeIdentifiers

final class SettingsWindowController: NSWindowController {
    private let store = SettingsStore.shared
    private let player = AudioPlayer()

    private let modeControl = NSSegmentedControl(labels: ["1 dzwiek", "5 dzwiekow"], trackingMode: .selectOne, target: nil, action: nil)
    private let singleStack = NSStackView()
    private let scaledStack = NSStackView()
    private let singlePathLabel = NSTextField(labelWithString: "")
    private var scaledPathLabels: [NSTextField] = []

    private let volumeSlider = NSSlider(value: 100, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let volumeValue = NSTextField(labelWithString: "")

    private let lidEnabledCheckbox = NSButton(checkboxWithTitle: "Odtwarzaj dzwiek przy ruchu klapy", target: nil, action: nil)
    private let lidSoundLabel = NSTextField(labelWithString: "")
    private let lidThresholdSlider = NSSlider(value: 4, minValue: 1, maxValue: 45, target: nil, action: nil)
    private let lidThresholdValue = NSTextField(labelWithString: "")
    private let lidCooldownSlider = NSSlider(value: 1200, minValue: 100, maxValue: 5000, target: nil, action: nil)
    private let lidCooldownValue = NSTextField(labelWithString: "")
    private let lidStopMarginSlider = NSSlider(value: 200, minValue: 50, maxValue: 800, target: nil, action: nil)
    private let lidStopMarginValue = NSTextField(labelWithString: "")
    private let lidMaxPlaybackSlider = NSSlider(value: 2000, minValue: 500, maxValue: 5000, target: nil, action: nil)
    private let lidMaxPlaybackValue = NSTextField(labelWithString: "")

    private let sensitivitySlider = NSSlider(value: 0.05, minValue: 0.005, maxValue: 0.30, target: nil, action: nil)
    private let sensitivityValue = NSTextField(labelWithString: "")
    private let maxScaleSlider = NSSlider(value: 0.15, minValue: 0.06, maxValue: 0.50, target: nil, action: nil)
    private let maxScaleValue = NSTextField(labelWithString: "")
    private let cooldownField = NSTextField(string: "750")
    private let autostartCheckbox = NSButton(checkboxWithTitle: "Uruchamiaj Clank przy logowaniu", target: nil, action: nil)
    private let visualizerView = SensorVisualizerView()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clank"
        window.subtitle = "Ustawienia"
        window.toolbarStyle = .preference
        window.center()
        super.init(window: window)
        buildUI()
        loadSettings()
        NotificationCenter.default.addObserver(self, selector: #selector(slapMeasurement(_:)), name: .clankSlapMeasurement, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(lidMeasurement(_:)), name: .clankLidMeasurement, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let visual = NSVisualEffectView()
        visual.material = .windowBackground
        visual.blendingMode = .behindWindow
        visual.state = .active
        visual.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(visual)

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .centerX
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 18, left: 22, bottom: 18, right: 22)
        root.translatesAutoresizingMaskIntoConstraints = false
        visual.addSubview(root)

        NSLayoutConstraint.activate([
            visual.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            visual.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            visual.topAnchor.constraint(equalTo: contentView.topAnchor),
            visual.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            root.leadingAnchor.constraint(equalTo: visual.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: visual.trailingAnchor),
            root.topAnchor.constraint(equalTo: visual.topAnchor),
            root.bottomAnchor.constraint(equalTo: visual.bottomAnchor)
        ])

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.addTabViewItem(tab(label: "Dzwieki", view: soundsPane()))
        tabView.addTabViewItem(tab(label: "Klapa", view: lidPane()))
        tabView.addTabViewItem(tab(label: "Detekcja", view: detectionPane()))
        tabView.widthAnchor.constraint(equalToConstant: 656).isActive = true
        tabView.heightAnchor.constraint(equalToConstant: 420).isActive = true
        root.addArrangedSubview(tabView)

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 10
        footer.widthAnchor.constraint(equalToConstant: 656).isActive = true

        let note = NSTextField(labelWithString: "Zmiany zapisuja sie automatycznie.")
        note.textColor = .secondaryLabelColor
        note.font = .systemFont(ofSize: 12)
        footer.addArrangedSubview(note)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        footer.addArrangedSubview(spacer)

        let done = NSButton(title: "Gotowe", target: self, action: #selector(closeWindow))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        footer.addArrangedSubview(done)

        root.addArrangedSubview(footer)
    }

    private func tab(label: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: label)
        item.label = label
        item.view = view
        return item
    }

    private func soundsPane() -> NSView {
        let root = paneStack()

        modeControl.target = self
        modeControl.action = #selector(modeChanged)
        root.addArrangedSubview(section(title: "Tryb", rows: [
            formRow("Tryb dzwiekow", modeControl)
        ]))

        configureStack(singleStack)
        singleStack.addArrangedSubview(soundRow(label: singlePathLabel, chooseAction: #selector(chooseSingleSound), playAction: #selector(playSingleSound)))

        configureStack(scaledStack)
        for idx in 0..<5 {
            let label = fileLabel()
            scaledPathLabels.append(label)
            scaledStack.addArrangedSubview(formRow(
                "Poziom \(idx + 1)",
                soundRow(label: label, chooseAction: #selector(chooseScaledSound(_:)), playAction: #selector(playScaledSound(_:)), tag: idx)
            ))
        }

        root.addArrangedSubview(section(title: "Pliki audio", rows: [
            formRow("Dzwiek", singleStack),
            formRow("", scaledStack)
        ]))

        volumeSlider.target = self
        volumeSlider.action = #selector(volumeChanged)
        root.addArrangedSubview(section(title: "Odtwarzanie", rows: [
            formRow("Glosnosc", sliderRow(slider: volumeSlider, value: volumeValue))
        ]))

        return root
    }

    private func lidPane() -> NSView {
        let root = paneStack()

        lidEnabledCheckbox.target = self
        lidEnabledCheckbox.action = #selector(lidEnabledChanged)
        lidThresholdSlider.target = self
        lidThresholdSlider.action = #selector(lidThresholdChanged)
        lidCooldownSlider.target = self
        lidCooldownSlider.action = #selector(lidCooldownChanged)
        lidStopMarginSlider.target = self
        lidStopMarginSlider.action = #selector(lidStopMarginChanged)
        lidMaxPlaybackSlider.target = self
        lidMaxPlaybackSlider.action = #selector(lidMaxPlaybackChanged)

        root.addArrangedSubview(section(title: "Klapa", rows: [
            formRow("Akcja", lidEnabledCheckbox),
            formRow("Plik", soundRow(label: lidSoundLabel, chooseAction: #selector(chooseLidSound), playAction: #selector(playLidSound))),
            formRow("Prog ruchu", sliderRow(slider: lidThresholdSlider, value: lidThresholdValue)),
            formRow("Cooldown", sliderRow(slider: lidCooldownSlider, value: lidCooldownValue)),
            formRow("Margines stopu", sliderRow(slider: lidStopMarginSlider, value: lidStopMarginValue)),
            formRow("Max dlugosc", sliderRow(slider: lidMaxPlaybackSlider, value: lidMaxPlaybackValue))
        ]))

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        root.addArrangedSubview(spacer)

        return root
    }

    private func detectionPane() -> NSView {
        let root = paneStack()

        sensitivitySlider.target = self
        sensitivitySlider.action = #selector(sensitivityChanged)
        maxScaleSlider.target = self
        maxScaleSlider.action = #selector(maxScaleChanged)
        cooldownField.alignment = .right
        cooldownField.target = self
        cooldownField.action = #selector(cooldownChanged)

        root.addArrangedSubview(section(title: "Pomiar uderzen", rows: [
            formRow("Czulosc minimum", sliderRow(slider: sensitivitySlider, value: sensitivityValue)),
            formRow("Gorny prog skali", sliderRow(slider: maxScaleSlider, value: maxScaleValue)),
            formRow("Cooldown", numericRow(field: cooldownField, suffix: "ms"))
        ]))

        visualizerView.widthAnchor.constraint(equalToConstant: 600).isActive = true
        visualizerView.heightAnchor.constraint(equalToConstant: 116).isActive = true
        root.addArrangedSubview(section(title: "Podglad odczytow", rows: [
            visualizerView
        ]))

        autostartCheckbox.target = self
        autostartCheckbox.action = #selector(autostartChanged)
        root.addArrangedSubview(section(title: "Aplikacja", rows: [
            formRow("Autostart", autostartCheckbox)
        ]))

        return root
    }

    private func paneStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 16, bottom: 14, right: 16)
        return stack
    }

    private func section(title: String, rows: [NSView]) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.widthAnchor.constraint(equalToConstant: 600).isActive = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.widthAnchor.constraint(equalToConstant: 600).isActive = true
        stack.addArrangedSubview(titleLabel)

        let rowsStack = NSStackView()
        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 8
        rows.forEach { stack.addArrangedSubview($0) }
        return stack
    }

    private func formRow(_ title: String, _ control: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 14
        row.widthAnchor.constraint(equalToConstant: 600).isActive = true

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 132).isActive = true
        row.addArrangedSubview(label)

        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(control)

        return row
    }

    private func soundRow(label: NSTextField, chooseAction: Selector, playAction: Selector, tag: Int = 0) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.widthAnchor.constraint(equalToConstant: 454).isActive = true

        label.lineBreakMode = .byTruncatingMiddle
        label.widthAnchor.constraint(equalToConstant: 230).isActive = true
        row.addArrangedSubview(label)

        let choose = NSButton(title: "Wybierz...", target: self, action: chooseAction)
        choose.tag = tag
        choose.bezelStyle = .rounded
        choose.widthAnchor.constraint(equalToConstant: 94).isActive = true
        row.addArrangedSubview(choose)

        let play = NSButton(title: "Odtworz", target: self, action: playAction)
        play.tag = tag
        play.bezelStyle = .rounded
        play.widthAnchor.constraint(equalToConstant: 96).isActive = true
        if let image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil) {
            play.image = image
            play.imagePosition = .imageLeading
        }
        row.addArrangedSubview(play)

        return row
    }

    private func sliderRow(slider: NSSlider, value: NSTextField) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10

        slider.widthAnchor.constraint(equalToConstant: 300).isActive = true
        value.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        value.textColor = .secondaryLabelColor
        value.widthAnchor.constraint(equalToConstant: 64).isActive = true

        row.addArrangedSubview(slider)
        row.addArrangedSubview(value)
        return row
    }

    private func numericRow(field: NSTextField, suffix: String) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        field.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        field.widthAnchor.constraint(equalToConstant: 86).isActive = true
        row.addArrangedSubview(field)

        let unit = NSTextField(labelWithString: suffix)
        unit.textColor = .secondaryLabelColor
        row.addArrangedSubview(unit)

        return row
    }

    private func configureStack(_ stack: NSStackView) {
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
    }

    private func fileLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        return label
    }

    private func loadSettings() {
        let settings = store.settings
        modeControl.selectedSegment = settings.soundMode == .single ? 0 : 1
        singlePathLabel.stringValue = displayName(settings.singleSoundPath)
        for idx in 0..<5 {
            scaledPathLabels[idx].stringValue = displayName(settings.scaledSoundPaths[idx])
        }
        volumeSlider.doubleValue = settings.soundVolume * 100.0
        lidEnabledCheckbox.state = settings.lidSoundEnabled ? .on : .off
        lidSoundLabel.stringValue = displayName(settings.lidSoundPath)
        lidThresholdSlider.doubleValue = settings.lidAngleThreshold
        lidCooldownSlider.doubleValue = Double(settings.lidSoundCooldownMilliseconds)
        lidStopMarginSlider.doubleValue = Double(settings.lidStopMarginMilliseconds)
        lidMaxPlaybackSlider.doubleValue = Double(settings.lidMaxPlaybackMilliseconds)
        sensitivitySlider.doubleValue = settings.minAmplitude
        maxScaleSlider.doubleValue = settings.maxScaleAmplitude
        cooldownField.stringValue = "\(settings.cooldownMilliseconds)"
        autostartCheckbox.state = AutostartManager.isEnabled ? .on : .off
        refreshValueLabels()
        refreshModeVisibility()
    }

    private func refreshModeVisibility() {
        singleStack.isHidden = modeControl.selectedSegment != 0
        scaledStack.isHidden = modeControl.selectedSegment != 1
    }

    private func refreshValueLabels() {
        volumeValue.stringValue = "\(Int(volumeSlider.doubleValue.rounded()))%"
        lidThresholdValue.stringValue = "\(Int(lidThresholdSlider.doubleValue.rounded())) deg"
        lidCooldownValue.stringValue = "\(Int(lidCooldownSlider.doubleValue.rounded())) ms"
        lidStopMarginValue.stringValue = "\(Int(lidStopMarginSlider.doubleValue.rounded())) ms"
        lidMaxPlaybackValue.stringValue = "\(Int(lidMaxPlaybackSlider.doubleValue.rounded())) ms"
        sensitivityValue.stringValue = String(format: "%.3fg", sensitivitySlider.doubleValue)
        maxScaleValue.stringValue = String(format: "%.2fg", maxScaleSlider.doubleValue)
    }

    private func displayName(_ path: String) -> String {
        path.isEmpty ? "Nie ustawiono" : URL(fileURLWithPath: path).lastPathComponent
    }

    private func chooseFile(completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.mp3, .mpeg4Audio, .wav, .aiff, .audio]
        if panel.runModal() == .OK, let url = panel.url {
            completion(url)
        }
    }

    @objc private func modeChanged() {
        refreshModeVisibility()
        saveSettings()
    }

    @objc private func volumeChanged() {
        refreshValueLabels()
        saveSettings()
    }

    @objc private func lidEnabledChanged() {
        saveSettings()
    }

    @objc private func lidThresholdChanged() {
        refreshValueLabels()
        saveSettings()
    }

    @objc private func lidCooldownChanged() {
        refreshValueLabels()
        saveSettings()
    }

    @objc private func lidStopMarginChanged() {
        refreshValueLabels()
        saveSettings()
    }

    @objc private func lidMaxPlaybackChanged() {
        refreshValueLabels()
        saveSettings()
    }

    @objc private func sensitivityChanged() {
        if maxScaleSlider.doubleValue <= sensitivitySlider.doubleValue {
            maxScaleSlider.doubleValue = sensitivitySlider.doubleValue + 0.02
        }
        refreshValueLabels()
        saveSettings()
    }

    @objc private func maxScaleChanged() {
        if maxScaleSlider.doubleValue <= sensitivitySlider.doubleValue {
            maxScaleSlider.doubleValue = sensitivitySlider.doubleValue + 0.02
        }
        refreshValueLabels()
        saveSettings()
    }

    @objc private func cooldownChanged() {
        saveSettings()
    }

    @objc private func autostartChanged() {
        do {
            try AutostartManager.setEnabled(autostartCheckbox.state == .on)
        } catch {
            autostartCheckbox.state = AutostartManager.isEnabled ? .on : .off
            showError("Nie udalo sie zmienic autostartu", error: error)
        }
    }

    @objc private func chooseSingleSound() {
        chooseFile { [weak self] url in
            guard let self else { return }
            var settings = store.settings
            settings.singleSoundPath = url.path
            store.save(settings)
            loadSettings()
        }
    }

    @objc private func chooseScaledSound(_ sender: NSButton) {
        chooseFile { [weak self] url in
            guard let self else { return }
            var settings = store.settings
            settings.scaledSoundPaths[sender.tag] = url.path
            store.save(settings)
            loadSettings()
        }
    }

    @objc private func chooseLidSound() {
        chooseFile { [weak self] url in
            guard let self else { return }
            var settings = store.settings
            settings.lidSoundPath = url.path
            settings.lidSoundEnabled = true
            store.save(settings)
            loadSettings()
        }
    }

    @objc private func playSingleSound() {
        let settings = store.settings
        player.play(url: URL(fileURLWithPath: settings.singleSoundPath), volume: settings.soundVolume)
    }

    @objc private func playScaledSound(_ sender: NSButton) {
        let settings = store.settings
        guard settings.scaledSoundPaths.indices.contains(sender.tag) else { return }
        player.play(url: URL(fileURLWithPath: settings.scaledSoundPaths[sender.tag]), volume: settings.soundVolume)
    }

    @objc private func playLidSound() {
        let settings = store.settings
        guard !settings.lidSoundPath.isEmpty else { return }
        player.play(url: URL(fileURLWithPath: settings.lidSoundPath), volume: settings.soundVolume)
    }

    @objc private func saveSettings() {
        var settings = store.settings
        settings.soundMode = modeControl.selectedSegment == 0 ? .single : .scaled
        settings.soundVolume = volumeSlider.doubleValue / 100.0
        settings.lidSoundEnabled = lidEnabledCheckbox.state == .on
        settings.lidAngleThreshold = lidThresholdSlider.doubleValue
        settings.lidSoundCooldownMilliseconds = Int(lidCooldownSlider.doubleValue)
        settings.lidStopMarginMilliseconds = Int(lidStopMarginSlider.doubleValue)
        settings.lidMaxPlaybackMilliseconds = Int(lidMaxPlaybackSlider.doubleValue)
        settings.minAmplitude = sensitivitySlider.doubleValue
        settings.maxScaleAmplitude = maxScaleSlider.doubleValue
        settings.cooldownMilliseconds = max(Int(cooldownField.intValue), 100)
        store.save(settings)
    }

    @objc private func closeWindow() {
        window?.close()
    }

    @objc private func slapMeasurement(_ notification: Notification) {
        guard let amplitude = notification.userInfo?["amplitude"] as? Double,
              let level = notification.userInfo?["level"] as? Int else { return }
        visualizerView.updateSlap(amplitude: amplitude, level: level)
    }

    @objc private func lidMeasurement(_ notification: Notification) {
        guard let angle = notification.userInfo?["angle"] as? Double,
              let delta = notification.userInfo?["delta"] as? Double else { return }
        visualizerView.updateLid(angle: angle, delta: delta)
    }

    private func showError(_ message: String, error: Error) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private final class SensorVisualizerView: NSView {
    private var amplitude: Double?
    private var level: Int?
    private var lidAngle: Double?
    private var lidDelta: Double?

    override var isFlipped: Bool { true }

    func updateSlap(amplitude: Double, level: Int) {
        self.amplitude = amplitude
        self.level = min(max(level, 0), 4)
        needsDisplay = true
    }

    func updateLid(angle: Double, delta: Double) {
        lidAngle = angle
        lidDelta = delta
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = bounds.insetBy(dx: 0, dy: 4)
        let background = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
        NSColor.controlBackgroundColor.setFill()
        background.fill()

        drawText("Uderzenie", at: NSPoint(x: 18, y: 16), color: .secondaryLabelColor, weight: .semibold)
        let ampText = amplitude.map { String(format: "%.4fg", $0) } ?? "brak"
        let levelText = level.map { "poziom \($0 + 1)/5" } ?? "poziom -"
        drawText("\(ampText)  \(levelText)", at: NSPoint(x: 392, y: 16), color: .secondaryLabelColor, alignment: .right)

        let barY: CGFloat = 44
        let barWidth: CGFloat = 92
        let gap: CGFloat = 8
        for idx in 0..<5 {
            let rect = NSRect(x: 18 + CGFloat(idx) * (barWidth + gap), y: barY, width: barWidth, height: 18)
            let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
            if let level, idx <= level {
                NSColor.controlAccentColor.setFill()
            } else {
                NSColor.separatorColor.withAlphaComponent(0.45).setFill()
            }
            path.fill()
        }

        drawText("Klapa", at: NSPoint(x: 18, y: 82), color: .secondaryLabelColor, weight: .semibold)
        let lidText: String
        if let lidAngle, let lidDelta {
            lidText = String(format: "%.0f deg, zmiana %.0f deg", lidAngle, lidDelta)
        } else {
            lidText = "brak"
        }
        drawText(lidText, at: NSPoint(x: 392, y: 82), color: .secondaryLabelColor, alignment: .right)
    }

    private func drawText(
        _ text: String,
        at point: NSPoint,
        color: NSColor,
        weight: NSFont.Weight = .regular,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        let rect = NSRect(x: point.x, y: point.y, width: alignment == .right ? 190 : 180, height: 18)
        text.draw(in: rect, withAttributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
    }
}
