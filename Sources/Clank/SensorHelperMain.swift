import Foundation

enum SensorHelperMain {
    static func run() -> Never {
        let options = parseArguments()
        guard let eventsPath = options["events-file"],
              let heartbeatPath = options["heartbeat-file"] else {
            FileHandle.standardError.write(Data("missing helper paths\n".utf8))
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

        do {
            try monitor.start()
        } catch {
            FileHandle.standardError.write(Data("sensor start failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: heartbeatPath),
                  let modified = attrs[.modificationDate] as? Date else {
                monitor.stop()
                exit(0)
            }
            if Date().timeIntervalSince(modified) > 3.0 {
                monitor.stop()
                exit(0)
            }
        }
        timer.resume()

        dispatchMain()
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
