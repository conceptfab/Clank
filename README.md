# Clank

Native macOS/AppKit menu bar app for accelerometer-driven sound feedback.

## Build

```bash
swift build -c release
make bundle
```

The app uses the Apple Silicon accelerometer path, so the sensor reader must run as root:

```bash
sudo .build/release/Clank
```

For a packaged menu bar app:

```bash
make bundle
sudo build/Clank.app/Contents/MacOS/Clank
```

## Sound Modes

- **Jeden dzwiek**: every detected hit plays the selected sound, regardless of measured amplitude.
- **Skala 5 stopni**: detected amplitude is mapped to five configurable sounds, from light movement to a strong hit.
