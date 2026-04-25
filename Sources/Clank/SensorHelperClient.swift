import AppKit
import Foundation

enum SensorHelperClientError: LocalizedError {
    case missingExecutable
    case launchRejected(String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable:
            return "brak sciezki do pliku wykonywalnego"
        case .launchRejected(let message):
            return message
        }
    }
}

final class SensorHelperClient {
    var onEvent: ((SlapEvent) -> Void)?
    var onLidAngleEvent: ((LidAngleEvent) -> Void)?

    private let settingsProvider: () -> AppSettings
    private let sessionID = UUID().uuidString
    private var eventsURL: URL
    private var heartbeatURL: URL
    private var pollTimer: DispatchSourceTimer?
    private var readOffset: UInt64 = 0
    private var pending = Data()
    private var lastHeartbeatTouch = Date.distantPast

    init(settingsProvider: @escaping () -> AppSettings) {
        self.settingsProvider = settingsProvider
        let temp = FileManager.default.temporaryDirectory
        eventsURL = temp.appendingPathComponent("Clank-\(sessionID).events.jsonl")
        heartbeatURL = temp.appendingPathComponent("Clank-\(sessionID).heartbeat")
    }

    func start() throws {
        guard let executablePath = Bundle.main.executableURL?.path else {
            throw SensorHelperClientError.missingExecutable
        }

        FileManager.default.createFile(atPath: eventsURL.path, contents: nil)
        FileManager.default.createFile(atPath: heartbeatURL.path, contents: Data("alive".utf8))

        let settings = settingsProvider()
        let helperCommand = [
            executablePath.shellQuoted(),
            "--sensor-helper",
            "--events-file", eventsURL.path.shellQuoted(),
            "--heartbeat-file", heartbeatURL.path.shellQuoted(),
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
            throw SensorHelperClientError.launchRejected(message)
        }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            self?.pollEvents()
        }
        timer.resume()
        pollTimer = timer
    }

    func stop() {
        pollTimer?.cancel()
        pollTimer = nil
        try? FileManager.default.removeItem(at: heartbeatURL)
    }

    private func pollEvents() {
        touchHeartbeatIfNeeded()
        guard let handle = try? FileHandle(forReadingFrom: eventsURL) else { return }
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

    private func touchHeartbeatIfNeeded() {
        guard Date().timeIntervalSince(lastHeartbeatTouch) >= 1.0 else { return }
        lastHeartbeatTouch = Date()
        try? Data("alive".utf8).write(to: heartbeatURL, options: .atomic)
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
