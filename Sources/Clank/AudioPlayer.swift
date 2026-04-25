import AVFoundation
import Foundation

final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var cache: [URL: AVAudioPlayer] = [:]

    func preload(_ urls: [URL]) {
        let unique = Set(urls)
        for url in unique where cache[url] == nil {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.delegate = self
                player.prepareToPlay()
                cache[url] = player
            } catch {
                NSLog("Clank: preload failed for \(url.path): \(error.localizedDescription)")
            }
        }
        for key in cache.keys where !unique.contains(key) {
            cache.removeValue(forKey: key)
        }
    }

    func play(url: URL, volume: Double = 1.0) {
        let player: AVAudioPlayer
        if let cached = cache[url] {
            player = cached
        } else {
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player.delegate = self
                player.prepareToPlay()
                cache[url] = player
            } catch {
                NSLog("Clank: cannot play \(url.path): \(error.localizedDescription)")
                return
            }
        }
        player.volume = Float(min(max(volume, 0.0), 1.0))
        if player.isPlaying {
            player.currentTime = 0
        }
        player.play()
    }

    func cachedPlayer(for url: URL) -> AVAudioPlayer? {
        cache[url]
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Keep the cached instance; AVAudioPlayer is reusable after finishing.
    }
}
