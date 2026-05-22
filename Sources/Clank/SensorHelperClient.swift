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
