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
