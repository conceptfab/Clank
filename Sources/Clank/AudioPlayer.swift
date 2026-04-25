import AVFoundation
import Foundation

final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var players: [AVAudioPlayer] = []

    func play(url: URL, volume: Double = 1.0) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = Float(min(max(volume, 0.0), 1.0))
            player.prepareToPlay()
            players.append(player)
            player.play()
        } catch {
            NSLog("Clank: cannot play \(url.path): \(error.localizedDescription)")
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        players.removeAll { $0 === player }
    }
}
