import Darwin
import Foundation
import IOKit
import IOKit.hid

enum AccelerometerMonitorError: LocalizedError {
    case requiresRoot
    case noAccelerometer
    case noSensors
    case iokit(String)

    var errorDescription: String? {
        switch self {
        case .requiresRoot:
            return "brak uprawnien root"
        case .noAccelerometer:
            return "nie znaleziono akcelerometru AppleSPUHIDDevice"
        case .noSensors:
            return "nie znaleziono sensorow AppleSPUHIDDevice"
        case .iokit(let message):
            return message
        }
    }
}

final class AccelerometerMonitor {
    var onEvent: ((SlapEvent) -> Void)?
    var onLidAngleEvent: ((LidAngleEvent) -> Void)?

    private let reportBufferSize = 4096
    private let imuReportLength = 22
    private let imuDecimation = 8
    private let imuDataOffset = 6
    private let accelScale = 65536.0
    private let pageVendor = 0xFF00
    private let pageSensor = 0x0020
    private let usageAccelerometer = 3
    private let usageLid = 138
    private let lidReportLength = 3

    private let detector: SlapDetector
    private var thread: Thread?
    private var isRunning = false
    private var registrations: [HIDRegistration] = []
    private var decimation = 0
    private var lastLidAngle: Double?

    init(settingsProvider: @escaping () -> AppSettings = { SettingsStore.shared.settings }) {
        detector = SlapDetector(settingsProvider: settingsProvider)
    }

    func start() throws {
        guard !isRunning else { return }
        guard geteuid() == 0 else { throw AccelerometerMonitorError.requiresRoot }

        isRunning = true
        var startupError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        thread = Thread { [weak self] in
            guard let self else { return }
            do {
                try self.run(semaphore: semaphore)
            } catch {
                startupError = error
                semaphore.signal()
            }
        }
        thread?.name = "Clank Accelerometer"
        thread?.start()

        semaphore.wait()

        if let startupError {
            isRunning = false
            throw startupError
        }
    }

    func stop() {
        isRunning = false
    }

    private func run(semaphore: DispatchSemaphore) throws {
        try wakeSPUDrivers()
        try registerSensors()
        semaphore.signal()

        while isRunning {
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.5, true)
        }

        registrations.removeAll()
    }

    private func wakeSPUDrivers() throws {
        guard let matching = IOServiceMatching("AppleSPUHIDDriver") else {
            throw AccelerometerMonitorError.iokit("IOServiceMatching AppleSPUHIDDriver failed")
        }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else {
            throw AccelerometerMonitorError.iokit("IOServiceGetMatchingServices AppleSPUHIDDriver returned \(result)")
        }
        defer { IOObjectRelease(iterator) }

        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }

            setRegistryInt32(service, key: "SensorPropertyReportingState", value: 1)
            setRegistryInt32(service, key: "SensorPropertyPowerState", value: 1)
            setRegistryInt32(service, key: "ReportInterval", value: 1000)
        }
    }

    private func registerSensors() throws {
        guard let matching = IOServiceMatching("AppleSPUHIDDevice") else {
            throw AccelerometerMonitorError.iokit("IOServiceMatching AppleSPUHIDDevice failed")
        }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else {
            throw AccelerometerMonitorError.iokit("IOServiceGetMatchingServices AppleSPUHIDDevice returned \(result)")
        }
        defer { IOObjectRelease(iterator) }

        var found = false
        var foundAccelerometer = false
        var foundLid = false
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }

            let usagePage = registryInt(service, key: "PrimaryUsagePage")
            let usage = registryInt(service, key: "PrimaryUsage")
            let kind: SensorKind
            if usagePage == pageVendor && usage == usageAccelerometer {
                kind = .accelerometer
            } else if usagePage == pageSensor && usage == usageLid {
                kind = .lid
            } else {
                continue
            }

            guard let device = IOHIDDeviceCreate(kCFAllocatorDefault, service) else { continue }
            let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
            guard openResult == kIOReturnSuccess else { continue }

            let registration = HIDRegistration(device: device, bufferSize: reportBufferSize, kind: kind, monitor: self)
            registrations.append(registration)

            let context = Unmanaged.passUnretained(registration.callbackContext).toOpaque()
            IOHIDDeviceRegisterInputReportCallback(
                device,
                registration.buffer,
                reportBufferSize,
                AccelerometerMonitor.inputCallback,
                context
            )
            IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            found = true
            if kind == .accelerometer {
                foundAccelerometer = true
            }
            if kind == .lid {
                foundLid = true
            }
        }

        if !found {
            throw AccelerometerMonitorError.noSensors
        }
        if !foundAccelerometer {
            throw AccelerometerMonitorError.noAccelerometer
        }
        FileHandle.standardError.write(Data("registered sensors: accelerometer=\(foundAccelerometer) lid=\(foundLid)\n".utf8))
    }

    private func handleReport(_ report: UnsafeMutablePointer<UInt8>?, length: CFIndex, kind: SensorKind) {
        guard let report else { return }
        if kind == .lid {
            guard length >= lidReportLength else { return }
            handleLidReport(report, length: length)
            return
        }
        guard kind == .accelerometer else { return }
        guard length == imuReportLength else { return }

        decimation += 1
        guard decimation >= imuDecimation else { return }
        decimation = 0

        let data = UnsafeBufferPointer(start: report, count: Int(length))
        let rawX = readInt32LE(data, offset: imuDataOffset)
        let rawY = readInt32LE(data, offset: imuDataOffset + 4)
        let rawZ = readInt32LE(data, offset: imuDataOffset + 8)

        let sample = AccelSample(
            x: Double(rawX) / accelScale,
            y: Double(rawY) / accelScale,
            z: Double(rawZ) / accelScale
        )

        if let event = detector.process(sample) {
            DispatchQueue.main.async { [weak self] in
                self?.onEvent?(event)
            }
        }
    }

    private func handleLidReport(_ report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        let data = UnsafeBufferPointer(start: report, count: Int(length))
        guard data[0] == 1 else { return }

        let raw = UInt16(data[1]) | (UInt16(data[2]) << 8)
        let angle = Double(raw & 0x01FF)

        guard let previous = lastLidAngle else {
            lastLidAngle = angle
            return
        }

        lastLidAngle = angle
        let delta = abs(angle - previous)
        guard delta >= 2.0 else { return }

        let event = LidAngleEvent(angle: angle, delta: delta, date: Date())
        DispatchQueue.main.async { [weak self] in
            self?.onLidAngleEvent?(event)
        }
    }

    private func readInt32LE(_ bytes: UnsafeBufferPointer<UInt8>, offset: Int) -> Int32 {
        let b0 = UInt32(bytes[offset])
        let b1 = UInt32(bytes[offset + 1]) << 8
        let b2 = UInt32(bytes[offset + 2]) << 16
        let b3 = UInt32(bytes[offset + 3]) << 24
        return Int32(bitPattern: b0 | b1 | b2 | b3)
    }

    private func setRegistryInt32(_ service: io_service_t, key: String, value: Int32) {
        IORegistryEntrySetCFProperty(service, key as CFString, NSNumber(value: value))
    }

    private func registryInt(_ service: io_service_t, key: String) -> Int {
        guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? NSNumber else {
            return 0
        }
        return value.intValue
    }

    private static let inputCallback: IOHIDReportCallback = { context, _, _, _, _, report, reportLength in
        guard let context else { return }
        let callbackContext = Unmanaged<HIDCallbackContext>.fromOpaque(context).takeUnretainedValue()
        callbackContext.monitor?.handleReport(report, length: reportLength, kind: callbackContext.kind)
    }
}

private enum SensorKind {
    case accelerometer
    case lid
}

private final class HIDCallbackContext {
    weak var monitor: AccelerometerMonitor?
    let kind: SensorKind

    init(monitor: AccelerometerMonitor, kind: SensorKind) {
        self.monitor = monitor
        self.kind = kind
    }
}

private final class HIDRegistration {
    let device: IOHIDDevice
    let buffer: UnsafeMutablePointer<UInt8>
    let bufferSize: Int
    let kind: SensorKind
    let callbackContext: HIDCallbackContext

    init(device: IOHIDDevice, bufferSize: Int, kind: SensorKind, monitor: AccelerometerMonitor) {
        self.device = device
        self.bufferSize = bufferSize
        self.kind = kind
        callbackContext = HIDCallbackContext(monitor: monitor, kind: kind)
        buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        buffer.initialize(repeating: 0, count: bufferSize)
    }

    deinit {
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        buffer.deinitialize(count: bufferSize)
        buffer.deallocate()
    }
}
