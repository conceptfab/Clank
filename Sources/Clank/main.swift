import AppKit

if CommandLine.arguments.contains("--sensor-helper") {
    SensorHelperMain.run()
}

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
