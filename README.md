# Clank

A tiny free macOS menu-bar app that makes your MacBook react when you touch it.
Clank listens for small knocks and lid movement, then plays short sound effects
through your speakers.

Website: [clank.conceptfab.com](https://clank.conceptfab.com/)

Current version: `1.0.1`

## What It Does

- Plays one of 10 short voice reactions when you tap or smack the laptop.
- Plays a door-slam sound when lid movement is detected.
- Lives quietly in the macOS menu bar, with no Dock icon.
- Lets you pause reactions whenever you need silence.
- Includes sensitivity, cooldown, and playback controls.
- Supports custom audio files.
- Uses a local helper to read sensor events.

## Requirements

- Apple Silicon Mac
- macOS 13 Ventura or newer
- Administrator password once, during sensor helper installation

## Download

Download the latest build from the GitHub releases page:

[Download Clank](https://github.com/conceptfab/clank/releases/latest)

The app is currently unsigned. On first launch, macOS Gatekeeper may show a
warning. Right-click `Clank.app`, choose `Open`, and confirm once. See the
[install guide](INSTALL.md) for the full walkthrough.

## Install

1. Download the DMG from the latest release.
2. Drag `Clank.app` to `Applications`.
3. Launch Clank.
4. Click `Install` when Clank asks to install the sensor helper.
5. After the native macOS administrator prompt, Clank appears in the menu bar.

No terminal command is needed for normal installation.

## Modes

### Smack Mode

Tap or smack the MacBook chassis and Clank picks one of the bundled voice lines:
`Ow`, `Ouch`, `Owwie`, `Hey that hurts`, `Ow stop it`, `What was that for`,
`Ow ow ow`, `Hey`, `Yowch`, or `That stings`.

### Lid Mode

Move or close the lid and Clank can play a short door-slam sample. Useful?
Questionable. Funny? Yes.

## Privacy

Clank is deliberately boring here:

- No analytics
- No tracking
- No newsletter
- No paid tier
- No network requirement for the app itself

Sensor reading happens locally through the helper installed on your Mac.

## Development

This is a Swift Package Manager macOS app.

```sh
swift build
swift test
```

To build a local test app bundle:

```sh
scripts/build-test-app.sh
```

## Links

- Website: [clank.conceptfab.com](https://clank.conceptfab.com/)
- Author: [conceptfab.com](https://conceptfab.com/)
- Source: [github.com/conceptfab/clank](https://github.com/conceptfab/clank)
- Install guide: [INSTALL.md](INSTALL.md)
- Support: [Buy Me a Coffee](https://www.buymeacoffee.com/conceptfab)

## License

Clank is released under the [MIT License](LICENSE).
