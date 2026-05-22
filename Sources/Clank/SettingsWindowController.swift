import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class SettingsWindowController: NSWindowController {
    private let model = SettingsWindowModel()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clank"
        window.subtitle = L.preferencesSubtitle
        window.toolbarStyle = .unifiedCompact
        window.titlebarAppearsTransparent = true
        window.center()
        super.init(window: window)

        model.closeWindow = { [weak window] in
            window?.close()
        }
        model.updateWindowSubtitle = { [weak window] in
            window?.subtitle = L.preferencesSubtitle
        }
        window.contentView = NSHostingView(rootView: SettingsWindowView(model: model))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class SettingsWindowModel: ObservableObject {
    @Published var settings: AppSettings
    @Published var slapAmplitude: Double?
    @Published var slapLevel: Int?
    @Published var lidAngle: Double?
    @Published var lidDelta: Double?
    @Published var errorMessage: String?

    var closeWindow: (() -> Void)?
    var updateWindowSubtitle: (() -> Void)?

    private let store: SettingsStore
    private let player = AudioPlayer()
    private var isSaving = false

    init(store: SettingsStore = .shared) {
        self.store = store
        settings = store.settings

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsStoreChanged),
            name: SettingsStore.changedNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(slapMeasurement(_:)),
            name: .clankSlapMeasurement,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(lidMeasurement(_:)),
            name: .clankLidMeasurement,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var singleSoundName: String {
        displayName(settings.singleSoundPath)
    }

    var lidSoundName: String {
        displayName(settings.lidSoundPath)
    }

    func scaledSoundName(at index: Int) -> String {
        guard settings.scaledSoundPaths.indices.contains(index) else { return L.notSet }
        return displayName(settings.scaledSoundPaths[index])
    }

    func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { value in
                self.settings[keyPath: keyPath] = value
                self.save()
            }
        )
    }

    func chooseSingleSound() {
        chooseAudioFile { url in
            settings.singleSoundPath = url.path
            save()
        }
    }

    func chooseScaledSound(index: Int) {
        chooseAudioFile { url in
            guard settings.scaledSoundPaths.indices.contains(index) else { return }
            settings.scaledSoundPaths[index] = url.path
            save()
        }
    }

    func chooseLidSound() {
        chooseAudioFile { url in
            settings.lidSoundPath = url.path
            settings.lidSoundEnabled = true
            save()
        }
    }

    func playSingleSound() {
        play(path: settings.singleSoundPath)
    }

    func playScaledSound(index: Int) {
        guard settings.scaledSoundPaths.indices.contains(index) else { return }
        play(path: settings.scaledSoundPaths[index])
    }

    func playLidSound() {
        play(path: settings.lidSoundPath)
    }

    func setAutostart(_ enabled: Bool) {
        do {
            try AutostartManager.setEnabled(enabled)
        } catch {
            errorMessage = error.localizedDescription
            objectWillChange.send()
        }
    }

    func save() {
        if settings.maxScaleAmplitude <= settings.minAmplitude {
            settings.maxScaleAmplitude = settings.minAmplitude + 0.02
        }

        isSaving = true
        store.save(settings)
        isSaving = false
        updateWindowSubtitle?()
    }

    private func chooseAudioFile(completion: (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.mp3, .mpeg4Audio, .wav, .aiff, .audio]
        if panel.runModal() == .OK, let url = panel.url {
            completion(url)
        }
    }

    private func play(path: String) {
        guard !path.isEmpty else { return }
        player.play(url: URL(fileURLWithPath: path), volume: settings.soundVolume)
    }

    private func displayName(_ path: String) -> String {
        path.isEmpty ? L.notSet : URL(fileURLWithPath: path).lastPathComponent
    }

    @objc private func settingsStoreChanged() {
        guard !isSaving else { return }
        settings = store.settings
        updateWindowSubtitle?()
    }

    @objc private func slapMeasurement(_ notification: Notification) {
        guard let amplitude = notification.userInfo?["amplitude"] as? Double,
              let level = notification.userInfo?["level"] as? Int else { return }
        slapAmplitude = amplitude
        slapLevel = min(max(level, 0), 4)
    }

    @objc private func lidMeasurement(_ notification: Notification) {
        guard let angle = notification.userInfo?["angle"] as? Double,
              let delta = notification.userInfo?["delta"] as? Double else { return }
        lidAngle = angle
        lidDelta = delta
    }
}

private struct SettingsWindowView: View {
    @ObservedObject var model: SettingsWindowModel

    var body: some View {
        TabView {
            settingsTab
                .tabItem {
                    Label(L.tabSettings, systemImage: "slider.horizontal.3")
                }

            AboutClankView()
                .tabItem {
                    Label(L.tabAbout, systemImage: "info.circle")
                }
        }
        .frame(minWidth: 620, idealWidth: 660, minHeight: 560, idealHeight: 620)
        .alert(L.failedAutostartTitle, isPresented: errorPresented) {
            Button(L.okButton, role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    model.errorMessage = nil
                }
            }
        )
    }

    private var settingsTab: some View {
        Form {
            soundsSection
            sensorsSection
            appSection
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            footer
        }
        .padding(.top, 8)
    }

    private var soundsSection: some View {
        Section {
            Picker(L.labelSoundMode, selection: model.binding(\.soundMode)) {
                Text(L.modeOneSoundShort).tag(SoundMode.single)
                Text(L.menuFiveSoundsByStrength).tag(SoundMode.scaled)
            }
            .pickerStyle(.segmented)

            if model.settings.soundMode == .single {
                SoundFileRow(
                    title: L.labelSoundFile,
                    fileName: model.singleSoundName,
                    choose: model.chooseSingleSound,
                    play: model.playSingleSound
                )
            } else {
                ForEach(0..<5, id: \.self) { index in
                    SoundFileRow(
                        title: L.levelLabel(index + 1),
                        fileName: model.scaledSoundName(at: index),
                        choose: { model.chooseScaledSound(index: index) },
                        play: { model.playScaledSound(index: index) }
                    )
                }
            }

            LabeledContent(L.labelVolume) {
                HStack {
                    Slider(value: model.binding(\.soundVolume), in: 0...1)
                    Text(model.settings.soundVolume, format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
            }
        } header: {
            Label(L.sectionSoundReactions, systemImage: "speaker.wave.2")
        } footer: {
            Text(L.sectionSoundReactionsFooter)
        }
    }

    private var sensorsSection: some View {
        Section {
            Toggle(L.labelPlayOnLidMove, isOn: model.binding(\.lidSoundEnabled))

            SoundFileRow(
                title: L.labelLidSound,
                fileName: model.lidSoundName,
                choose: model.chooseLidSound,
                play: model.playLidSound
            )
            .disabled(!model.settings.lidSoundEnabled)

            LabeledSlider(
                title: L.labelMinSensitivity,
                value: model.binding(\.minAmplitude),
                range: 0.005...0.30,
                displayValue: String(format: "%.3fg", model.settings.minAmplitude)
            )

            LabeledSlider(
                title: L.labelUpperScale,
                value: model.binding(\.maxScaleAmplitude),
                range: 0.06...0.50,
                displayValue: String(format: "%.2fg", model.settings.maxScaleAmplitude)
            )

            LabeledSlider(
                title: L.labelMovementThreshold,
                value: model.binding(\.lidAngleThreshold),
                range: 1...45,
                displayValue: String(format: "%.0f deg", model.settings.lidAngleThreshold)
            )
            .disabled(!model.settings.lidSoundEnabled)

            DisclosureGroup(L.sectionAdvancedTiming) {
                LabeledSlider(
                    title: L.labelSlapCooldown,
                    value: intBinding(\.cooldownMilliseconds),
                    range: 100...5000,
                    displayValue: "\(model.settings.cooldownMilliseconds) ms"
                )

                LabeledSlider(
                    title: L.labelLidCooldown,
                    value: intBinding(\.lidSoundCooldownMilliseconds),
                    range: 100...5000,
                    displayValue: "\(model.settings.lidSoundCooldownMilliseconds) ms"
                )

                LabeledSlider(
                    title: L.labelStopMargin,
                    value: intBinding(\.lidStopMarginMilliseconds),
                    range: 50...2000,
                    displayValue: "\(model.settings.lidStopMarginMilliseconds) ms"
                )

                LabeledSlider(
                    title: L.labelMaxLength,
                    value: intBinding(\.lidMaxPlaybackMilliseconds),
                    range: 500...5000,
                    displayValue: "\(model.settings.lidMaxPlaybackMilliseconds) ms"
                )
            }

            SensorPreview(
                amplitude: model.slapAmplitude,
                level: model.slapLevel,
                lidAngle: model.lidAngle,
                lidDelta: model.lidDelta
            )
        } header: {
            Label(L.sectionSensors, systemImage: "waveform.path.ecg")
        } footer: {
            Text(L.sectionSensorsFooter)
        }
    }

    private var appSection: some View {
        Section {
            Toggle(
                L.labelLaunchAtLogin,
                isOn: Binding(
                    get: { AutostartManager.isEnabled },
                    set: model.setAutostart
                )
            )

            Picker(L.labelLanguage, selection: model.binding(\.language)) {
                ForEach(Language.allCases, id: \.self) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Label(L.sectionApplication, systemImage: "app.badge")
        }
    }

    private var footer: some View {
        HStack {
            Text(L.changesSaveAutomatically)
                .foregroundStyle(.secondary)
            Spacer()
            Button(L.doneButton) {
                model.closeWindow?()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func intBinding(_ keyPath: WritableKeyPath<AppSettings, Int>) -> Binding<Double> {
        Binding(
            get: { Double(model.settings[keyPath: keyPath]) },
            set: { value in
                model.settings[keyPath: keyPath] = Int(value.rounded())
                model.save()
            }
        )
    }
}

private struct SoundFileRow: View {
    let title: String
    let fileName: String
    let choose: () -> Void
    let play: () -> Void

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                Text(fileName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(L.chooseButton, action: choose)

                Button(action: play) {
                    Label(L.playButton, systemImage: "play.fill")
                }
                .disabled(fileName == L.notSet)
            }
        }
    }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let displayValue: String

    var body: some View {
        LabeledContent(title) {
            HStack {
                Slider(value: $value, in: range)
                Text(displayValue)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 68, alignment: .trailing)
            }
        }
    }
}

private struct SensorPreview: View {
    let amplitude: Double?
    let level: Int?
    let lidAngle: Double?
    let lidDelta: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(L.sectionReadingPreview, systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline)
                Spacer()
                Text(readingSummary)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(index <= (level ?? -1) ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(height: 12)
                }
            }
            .accessibilityLabel(L.visualSlap)
            .accessibilityValue(level.map { L.visualLevel($0 + 1) } ?? L.visualLevelEmpty)

            HStack {
                Text(L.visualLid)
                Spacer()
                Text(lidSummary)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var readingSummary: String {
        let ampText = amplitude.map { String(format: "%.4fg", $0) } ?? L.visualNone
        let levelText = level.map { L.visualLevel($0 + 1) } ?? L.visualLevelEmpty
        return "\(ampText)  \(levelText)"
    }

    private var lidSummary: String {
        guard let lidAngle, let lidDelta else { return L.visualNone }
        return L.visualLidDetail(angle: lidAngle, delta: lidDelta)
    }
}

private struct AboutClankView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)

            appIcon
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Clank")
                    .font(.largeTitle)
                    .bold()
                Text(L.aboutTagline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                AboutRow(title: L.aboutVersion, value: versionString)
                AboutLinkRow(title: L.aboutAuthor, label: L.aboutAuthorName, url: URL(string: "https://conceptfab.com")!)
                AboutLinkRow(title: L.aboutWebsite, label: L.aboutWebsiteName, url: URL(string: "https://clank.conceptfab.com")!)
                AboutRow(title: L.aboutIcons, value: L.aboutIconsCredit)
                AboutRow(title: L.aboutHelper, value: HelperInstaller.isInstalled ? L.aboutHelperInstalled : L.aboutHelperNotInstalled)
                AboutRow(title: L.aboutPlatform, value: L.aboutPlatformValue)
            }
            .padding(.top, 8)
            .frame(maxWidth: 360)

            Text(L.aboutBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Link(destination: URL(string: "https://www.buymeacoffee.com/conceptfab")!) {
                buyMeCoffeeButton
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.aboutSupport)
            .padding(.top, 4)

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appIcon: some View {
        Group {
            if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "laptopcomputer")
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    private var buyMeCoffeeButton: some View {
        Group {
            if let url = Bundle.module.url(forResource: "buy-me-a-coffee", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 217, height: 60)
            } else {
                Label(L.aboutSupport, systemImage: "cup.and.saucer.fill")
                    .frame(minWidth: 180)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(.yellow, in: Capsule())
                    .foregroundStyle(.black)
            }
        }
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.1"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct AboutRow: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title) {
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AboutLinkRow: View {
    let title: String
    let label: String
    let url: URL

    var body: some View {
        LabeledContent(title) {
            Link(label, destination: url)
        }
    }
}
