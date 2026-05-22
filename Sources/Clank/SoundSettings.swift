import Foundation

enum SoundMode: String, Codable {
    case single
    case scaled
}

struct AppSettings: Codable {
    var soundMode: SoundMode
    var singleSoundPath: String
    var scaledSoundPaths: [String]
    var soundVolume: Double
    var lidSoundEnabled: Bool
    var lidSoundPath: String
    var lidAngleThreshold: Double
    var lidSoundCooldownMilliseconds: Int
    var lidStopMarginMilliseconds: Int
    var lidMaxPlaybackMilliseconds: Int
    var minAmplitude: Double
    var cooldownMilliseconds: Int
    var maxScaleAmplitude: Double

    init(
        soundMode: SoundMode,
        singleSoundPath: String,
        scaledSoundPaths: [String],
        soundVolume: Double,
        lidSoundEnabled: Bool,
        lidSoundPath: String,
        lidAngleThreshold: Double,
        lidSoundCooldownMilliseconds: Int,
        lidStopMarginMilliseconds: Int,
        lidMaxPlaybackMilliseconds: Int,
        minAmplitude: Double,
        cooldownMilliseconds: Int,
        maxScaleAmplitude: Double
    ) {
        self.soundMode = soundMode
        self.singleSoundPath = singleSoundPath
        self.scaledSoundPaths = scaledSoundPaths
        self.soundVolume = soundVolume
        self.lidSoundEnabled = lidSoundEnabled
        self.lidSoundPath = lidSoundPath
        self.lidAngleThreshold = lidAngleThreshold
        self.lidSoundCooldownMilliseconds = lidSoundCooldownMilliseconds
        self.lidStopMarginMilliseconds = lidStopMarginMilliseconds
        self.lidMaxPlaybackMilliseconds = lidMaxPlaybackMilliseconds
        self.minAmplitude = minAmplitude
        self.cooldownMilliseconds = cooldownMilliseconds
        self.maxScaleAmplitude = maxScaleAmplitude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        soundMode = try container.decode(SoundMode.self, forKey: .soundMode)
        singleSoundPath = try container.decode(String.self, forKey: .singleSoundPath)
        scaledSoundPaths = try container.decode([String].self, forKey: .scaledSoundPaths)
        soundVolume = try container.decodeIfPresent(Double.self, forKey: .soundVolume) ?? 1.0
        lidSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .lidSoundEnabled) ?? false
        lidSoundPath = try container.decodeIfPresent(String.self, forKey: .lidSoundPath) ?? ""
        lidAngleThreshold = try container.decodeIfPresent(Double.self, forKey: .lidAngleThreshold) ?? 4.0
        lidSoundCooldownMilliseconds = try container.decodeIfPresent(Int.self, forKey: .lidSoundCooldownMilliseconds) ?? 1200
        lidStopMarginMilliseconds = try container.decodeIfPresent(Int.self, forKey: .lidStopMarginMilliseconds) ?? 2000
        lidMaxPlaybackMilliseconds = try container.decodeIfPresent(Int.self, forKey: .lidMaxPlaybackMilliseconds) ?? 2000
        minAmplitude = try container.decode(Double.self, forKey: .minAmplitude)
        cooldownMilliseconds = try container.decode(Int.self, forKey: .cooldownMilliseconds)
        maxScaleAmplitude = try container.decode(Double.self, forKey: .maxScaleAmplitude)
    }
}

final class SettingsStore {
    static let shared = SettingsStore()
    static let changedNotification = Notification.Name("SettingsStoreChanged")

    private let defaultsKey = "Clank.Settings.v1"
    private static let defaultMaxScaleAmplitude = 0.15

    private(set) var settings: AppSettings

    private init() {
        settings = Self.loadDefaults()
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = Self.normalized(decoded)
        }
        persist()
    }

    func save(_ newSettings: AppSettings) {
        settings = Self.normalized(newSettings)
        persist()
        NotificationCenter.default.post(name: Self.changedNotification, object: self)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private static func loadDefaults() -> AppSettings {
        let pain = bundledPainSounds()
        let single = pain.first?.path ?? ""
        let scaled = (0..<5).map { index in
            guard pain.indices.contains(index) else { return single }
            return pain[index].path
        }
        let lid = bundledLidSounds().first?.path ?? ""

        return AppSettings(
            soundMode: .single,
            singleSoundPath: single,
            scaledSoundPaths: scaled,
            soundVolume: 1.0,
            lidSoundEnabled: false,
            lidSoundPath: lid,
            lidAngleThreshold: 4.0,
            lidSoundCooldownMilliseconds: 1200,
            lidStopMarginMilliseconds: 2000,
            lidMaxPlaybackMilliseconds: 2000,
            minAmplitude: 0.05,
            cooldownMilliseconds: 750,
            maxScaleAmplitude: defaultMaxScaleAmplitude
        )
    }

    private static func normalized(_ settings: AppSettings) -> AppSettings {
        var copy = settings
        let defaults = loadDefaults()
        if copy.scaledSoundPaths.count < 5 {
            copy.scaledSoundPaths += defaults.scaledSoundPaths.dropFirst(copy.scaledSoundPaths.count)
        } else if copy.scaledSoundPaths.count > 5 {
            copy.scaledSoundPaths = Array(copy.scaledSoundPaths.prefix(5))
        }

        if !fileExists(copy.singleSoundPath) {
            copy.singleSoundPath = defaults.singleSoundPath
        }
        for idx in copy.scaledSoundPaths.indices {
            if !fileExists(copy.scaledSoundPaths[idx]), defaults.scaledSoundPaths.indices.contains(idx) {
                copy.scaledSoundPaths[idx] = defaults.scaledSoundPaths[idx]
            }
        }
        if !fileExists(copy.lidSoundPath) {
            copy.lidSoundPath = defaults.lidSoundPath
            if copy.lidSoundPath.isEmpty {
                copy.lidSoundEnabled = false
            }
        }

        copy.soundVolume = min(max(copy.soundVolume, 0.0), 1.0)
        copy.lidAngleThreshold = min(max(copy.lidAngleThreshold, 1.0), 45.0)
        copy.lidSoundCooldownMilliseconds = min(max(copy.lidSoundCooldownMilliseconds, 100), 5000)
        copy.lidStopMarginMilliseconds = min(max(copy.lidStopMarginMilliseconds, 50), 2000)
        copy.lidMaxPlaybackMilliseconds = min(max(copy.lidMaxPlaybackMilliseconds, 500), 5000)
        copy.minAmplitude = min(max(copy.minAmplitude, 0.001), 1.0)
        if copy.maxScaleAmplitude >= 0.75 {
            copy.maxScaleAmplitude = defaultMaxScaleAmplitude
        }
        copy.maxScaleAmplitude = min(max(copy.maxScaleAmplitude, copy.minAmplitude + 0.001), 2.0)
        copy.cooldownMilliseconds = max(copy.cooldownMilliseconds, 100)
        return copy
    }

    private static func fileExists(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    static func bundledPainSounds() -> [URL] {
        (Bundle.module.urls(forResourcesWithExtension: "mp3", subdirectory: "audio/pain") ?? [])
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    static func bundledLidSounds() -> [URL] {
        let m4a = Bundle.module.urls(forResourcesWithExtension: "m4a", subdirectory: "audio/lid") ?? []
        let mp3 = Bundle.module.urls(forResourcesWithExtension: "mp3", subdirectory: "audio/lid") ?? []
        return (m4a + mp3).sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }
}

struct SoundResolver {
    let settings: AppSettings

    func soundURL(for amplitude: Double) -> URL? {
        switch settings.soundMode {
        case .single:
            return existingURL(settings.singleSoundPath) ?? SettingsStore.bundledPainSounds().first
        case .scaled:
            let idx = level(for: amplitude)
            if settings.scaledSoundPaths.indices.contains(idx),
               let url = existingURL(settings.scaledSoundPaths[idx]) {
                return url
            }
            let bundled = SettingsStore.bundledPainSounds()
            guard bundled.indices.contains(idx) else { return bundled.first }
            return bundled[idx]
        }
    }

    func level(for amplitude: Double) -> Int {
        guard settings.maxScaleAmplitude > settings.minAmplitude else { return 0 }
        let normalized = (amplitude - settings.minAmplitude) / (settings.maxScaleAmplitude - settings.minAmplitude)
        return min(4, max(0, Int(floor(normalized * 5.0))))
    }

    private func existingURL(_ path: String) -> URL? {
        guard !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
