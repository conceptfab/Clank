import XCTest
@testable import Clank

final class SmokeTests: XCTestCase {
    func test_soundResolver_levelClampsBelowMin() {
        let settings = AppSettings(
            soundMode: .scaled,
            singleSoundPath: "",
            scaledSoundPaths: Array(repeating: "", count: 5),
            soundVolume: 1.0,
            lidSoundEnabled: false,
            lidSoundPath: "",
            lidAngleThreshold: 4.0,
            lidSoundCooldownMilliseconds: 1200,
            minAmplitude: 0.05,
            cooldownMilliseconds: 750,
            maxScaleAmplitude: 0.15
        )
        let resolver = SoundResolver(settings: settings)
        XCTAssertEqual(resolver.level(for: 0.0), 0)
        XCTAssertEqual(resolver.level(for: 0.05), 0)
        XCTAssertEqual(resolver.level(for: 0.149), 4)
        XCTAssertEqual(resolver.level(for: 1.0), 4)
    }
}
