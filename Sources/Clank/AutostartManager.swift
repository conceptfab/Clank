import Foundation

enum AutostartManagerError: LocalizedError {
    case appBundleUnavailable

    var errorDescription: String? {
        switch self {
        case .appBundleUnavailable:
            return L.errAppBundleUnavailable
        }
    }
}

enum AutostartManager {
    private static let label = "dev.conceptfab.clank.autostart"

    private static var launchAgentsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }

    private static var plistURL: URL {
        launchAgentsDirectory.appendingPathComponent("\(label).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func setEnabled(_ enabled: Bool) throws {
        enabled ? try enable() : try disable()
    }

    private static func enable() throws {
        let appURL = Bundle.main.bundleURL
        guard appURL.pathExtension == "app" else {
            throw AutostartManagerError.appBundleUnavailable
        }

        try FileManager.default.createDirectory(
            at: launchAgentsDirectory,
            withIntermediateDirectories: true
        )

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [
                "/usr/bin/open",
                appURL.path
            ],
            "RunAtLoad": true
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL, options: .atomic)
    }

    private static func disable() throws {
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
    }
}
