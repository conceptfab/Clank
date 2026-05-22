import AppKit
import Foundation

enum HelperInstallerError: LocalizedError {
    case binaryNotFound
    case templateNotFound
    case scriptCreationFailed
    case userCancelled
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return L.errBinaryNotFound
        case .templateNotFound:
            return L.errTemplateNotFound
        case .scriptCreationFailed:
            return L.errScriptCreationFailed
        case .userCancelled:
            return L.errUserCancelled
        case .installFailed(let message):
            return L.errInstallFailed(message)
        }
    }
}

enum HelperInstaller {
    static let plistInstallPath = "/Library/LaunchDaemons/dev.conceptfab.clank.sensor-helper.plist"
    static let helperBinaryInstallPath = "/usr/local/libexec/clank-sensor-helper"
    static let daemonLabel = "dev.conceptfab.clank.sensor-helper"

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistInstallPath)
            && FileManager.default.fileExists(atPath: helperBinaryInstallPath)
    }

    static func install() throws {
        guard let sourceBinaryURL = Bundle.main.executableURL else {
            throw HelperInstallerError.binaryNotFound
        }
        guard let templateURL = Bundle.module.url(forResource: "dev.conceptfab.clank.sensor-helper.plist", withExtension: "template") else {
            throw HelperInstallerError.templateNotFound
        }

        let template = try String(contentsOf: templateURL, encoding: .utf8)
        let processed = template.replacingOccurrences(of: "__HELPER_BINARY__", with: helperBinaryInstallPath)

        let tempPlist = FileManager.default.temporaryDirectory
            .appendingPathComponent("clank-helper-\(UUID().uuidString).plist")
        try processed.write(to: tempPlist, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempPlist) }

        let bash = """
        set -e
        mkdir -p /usr/local/libexec
        cp \(sourceBinaryURL.path.shellQuoted()) \(helperBinaryInstallPath.shellQuoted())
        chown root:wheel \(helperBinaryInstallPath.shellQuoted())
        chmod 755 \(helperBinaryInstallPath.shellQuoted())
        cp \(tempPlist.path.shellQuoted()) \(plistInstallPath.shellQuoted())
        chown root:wheel \(plistInstallPath.shellQuoted())
        chmod 644 \(plistInstallPath.shellQuoted())
        if /bin/launchctl print system/\(daemonLabel) >/dev/null 2>&1; then
            /bin/launchctl bootout system/\(daemonLabel) || true
        fi
        /bin/launchctl bootstrap system \(plistInstallPath.shellQuoted())
        /bin/launchctl enable system/\(daemonLabel)
        """

        try runWithAdminPrivileges(bash: bash)
    }

    static func uninstall() throws {
        let bash = """
        if /bin/launchctl print system/\(daemonLabel) >/dev/null 2>&1; then
            /bin/launchctl bootout system/\(daemonLabel) || true
        fi
        rm -f \(plistInstallPath.shellQuoted())
        rm -f \(helperBinaryInstallPath.shellQuoted())
        rm -f /tmp/clank-helper.events /tmp/clank-helper.heartbeat /var/log/clank-helper.log
        """

        try runWithAdminPrivileges(bash: bash)
    }

    private static func runWithAdminPrivileges(bash: String) throws {
        let appleScriptSource = "do shell script \(bash.appleScriptQuoted()) with administrator privileges"

        guard let script = NSAppleScript(source: appleScriptSource) else {
            throw HelperInstallerError.scriptCreationFailed
        }

        var errorInfo: NSDictionary?
        _ = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
            if code == -128 {
                throw HelperInstallerError.userCancelled
            }
            let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? L.errCode(code)
            throw HelperInstallerError.installFailed(message)
        }
    }
}
