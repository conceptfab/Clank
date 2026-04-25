import XCTest
@testable import Clank

final class AudioPlayerTests: XCTestCase {
    private func bundledSound() -> URL? {
        SettingsStore.bundledPainSounds().first
    }

    func test_preload_thenPlay_reusesSameAVAudioPlayer() throws {
        guard let url = bundledSound() else {
            throw XCTSkip("no bundled audio in test runtime")
        }
        let player = AudioPlayer()
        player.preload([url])

        let firstID = ObjectIdentifier(try XCTUnwrap(player.cachedPlayer(for: url)))
        player.play(url: url, volume: 0.0)
        let secondID = ObjectIdentifier(try XCTUnwrap(player.cachedPlayer(for: url)))

        XCTAssertEqual(firstID, secondID, "play should reuse the preloaded AVAudioPlayer")
    }

    func test_preload_evictsURLsNoLongerInList() throws {
        let sounds = SettingsStore.bundledPainSounds()
        guard sounds.count >= 2 else {
            throw XCTSkip("need two bundled sounds")
        }
        let player = AudioPlayer()
        player.preload([sounds[0], sounds[1]])
        XCTAssertNotNil(player.cachedPlayer(for: sounds[0]))
        XCTAssertNotNil(player.cachedPlayer(for: sounds[1]))

        player.preload([sounds[1]])
        XCTAssertNil(player.cachedPlayer(for: sounds[0]))
        XCTAssertNotNil(player.cachedPlayer(for: sounds[1]))
    }
}
