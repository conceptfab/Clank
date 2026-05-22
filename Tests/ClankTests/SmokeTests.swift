import XCTest
@testable import Clank

final class SmokeTests: XCTestCase {
    func test_soundResolver_levelClampsToZeroBelowMin() {
        let resolver = SoundResolver(settings: makeSettings())
        XCTAssertEqual(resolver.level(for: 0.0), 0)
        XCTAssertEqual(resolver.level(for: 0.05), 0)
    }

    func test_soundResolver_levelClampsToFourAboveMax() {
        let resolver = SoundResolver(settings: makeSettings())
        XCTAssertEqual(resolver.level(for: 0.149), 4)
        XCTAssertEqual(resolver.level(for: 0.15), 4)
        XCTAssertEqual(resolver.level(for: 1.0), 4)
    }

    private func makeSettings() -> AppSettings {
        AppSettings(
            soundMode: .scaled,
            singleSoundPath: "",
            scaledSoundPaths: Array(repeating: "", count: 5),
            soundVolume: 1.0,
            lidSoundEnabled: false,
            lidSoundPath: "",
            lidAngleThreshold: 4.0,
            lidSoundCooldownMilliseconds: 1200,
            lidStopMarginMilliseconds: 2000,
            lidMaxPlaybackMilliseconds: 2000,
            minAmplitude: 0.05,
            cooldownMilliseconds: 750,
            maxScaleAmplitude: 0.15,
            language: .en
        )
    }
}
