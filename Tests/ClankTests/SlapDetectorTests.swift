import XCTest
@testable import Clank

final class SlapDetectorTests: XCTestCase {
    private func makeSettings(min: Double = 0.05, cooldown: Int = 750) -> AppSettings {
        AppSettings(
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
            minAmplitude: min,
            cooldownMilliseconds: cooldown,
            maxScaleAmplitude: 0.15,
            language: .en
        )
    }

    func test_settingsProvider_isCalledOnceUntilRefresh() {
        var calls = 0
        let detector = SlapDetector(settingsProvider: {
            calls += 1
            return self.makeSettings()
        })

        for _ in 0..<200 {
            _ = detector.process(AccelSample(x: 0, y: 0, z: 0.001))
        }
        XCTAssertEqual(calls, 1, "expected snapshot reuse, got \(calls) provider calls")

        detector.refreshSettings()
        for _ in 0..<200 {
            _ = detector.process(AccelSample(x: 0, y: 0, z: 0.001))
        }
        XCTAssertEqual(calls, 2, "expected exactly one extra call after refreshSettings()")
    }
}
