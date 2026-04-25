import Foundation

struct AccelSample {
    let x: Double
    let y: Double
    let z: Double
}

struct SlapEvent {
    let amplitude: Double
    let level: Int
    let date: Date
}

struct LidAngleEvent {
    let angle: Double
    let delta: Double
    let date: Date
}

final class SlapDetector {
    private let settingsProvider: () -> AppSettings
    private var cachedSettings: AppSettings

    private var hpReady = false
    private var previousRaw = AccelSample(x: 0, y: 0, z: 0)
    private var previousOut = AccelSample(x: 0, y: 0, z: 0)
    private var sta = 0.0
    private var lta = 1e-10
    private var cusumPos = 0.0
    private var cusumNeg = 0.0
    private var cusumMean = 0.0
    private var peakBuffer: [Double] = []
    private var lastEvent = Date.distantPast
    private var sampleCount = 0

    init(settingsProvider: @escaping () -> AppSettings) {
        self.settingsProvider = settingsProvider
        self.cachedSettings = settingsProvider()
    }

    func refreshSettings() { cachedSettings = settingsProvider() }

    func process(_ sample: AccelSample, at date: Date = Date()) -> SlapEvent? {
        sampleCount += 1

        guard hpReady else {
            hpReady = true
            previousRaw = sample
            return nil
        }

        let alpha = 0.95
        let hx = alpha * (previousOut.x + sample.x - previousRaw.x)
        let hy = alpha * (previousOut.y + sample.y - previousRaw.y)
        let hz = alpha * (previousOut.z + sample.z - previousRaw.z)
        previousRaw = sample
        previousOut = AccelSample(x: hx, y: hy, z: hz)

        let amplitude = sqrt(hx * hx + hy * hy + hz * hz)
        updateBaselines(amplitude)

        let settings = cachedSettings
        let elapsed = date.timeIntervalSince(lastEvent) * 1000.0
        guard elapsed >= Double(settings.cooldownMilliseconds) else { return nil }
        guard amplitude >= settings.minAmplitude else { return nil }

        if shouldTrigger(amplitude) {
            lastEvent = date
            let level = SoundResolver(settings: settings).level(for: amplitude)
            return SlapEvent(amplitude: amplitude, level: level, date: date)
        }

        return nil
    }

    private func updateBaselines(_ amplitude: Double) {
        let energy = amplitude * amplitude
        sta += (energy - sta) / 15.0
        lta += (energy - lta) / 500.0

        cusumMean += 0.0001 * (amplitude - cusumMean)
        cusumPos = max(0, cusumPos + amplitude - cusumMean - 0.0005)
        cusumNeg = max(0, cusumNeg - amplitude + cusumMean - 0.0005)

        peakBuffer.append(amplitude)
        if peakBuffer.count > 200 {
            peakBuffer.removeFirst(peakBuffer.count - 200)
        }
    }

    private func shouldTrigger(_ amplitude: Double) -> Bool {
        let ratio = sta / (lta + 1e-30)
        if ratio > 2.5 {
            return true
        }

        if cusumPos > 0.01 || cusumNeg > 0.01 {
            cusumPos = 0
            cusumNeg = 0
            return true
        }

        guard sampleCount % 10 == 0, peakBuffer.count >= 50 else {
            return amplitude > 0.12
        }

        let sorted = peakBuffer.sorted()
        let median = sorted[sorted.count / 2]
        let deviations = sorted.map { abs($0 - median) }.sorted()
        let mad = deviations[deviations.count / 2]
        let sigma = 1.4826 * mad + 1e-30
        return abs(amplitude - median) / sigma > 2.0
    }
}
