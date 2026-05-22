import Foundation

enum Language: String, Codable, CaseIterable, Hashable {
    case en
    case pl

    var displayName: String {
        switch self {
        case .en: return "English"
        case .pl: return "Polski"
        }
    }
}

enum L {
    static var lang: Language {
        SettingsStore.shared.settings.language
    }

    private static func t(_ en: String, _ pl: String) -> String {
        lang == .en ? en : pl
    }

    // Menu bar
    static var lastReadingNone: String { t("Last reading: none", "Ostatni pomiar: brak") }
    static var pauseDetection: String { t("Pause detection", "Wstrzymaj detekcje") }
    static var enableDetection: String { t("Enable detection", "Wlacz detekcje") }
    static var menuSoundMode: String { t("Sound mode", "Tryb dzwiekow") }
    static var menuOneSound: String { t("1 sound", "1 dzwiek") }
    static var menuFiveSoundsByStrength: String { t("5 sounds by strength", "5 dzwiekow wedlug sily") }
    static var menuHelper: String { "Helper..." }
    static var menuReinstallHelper: String { t("Reinstall helper...", "Reinstaluj helpera...") }
    static var menuInstallHelper: String { t("Install helper...", "Zainstaluj helpera...") }
    static var menuUninstallHelper: String { t("Uninstall helper...", "Odinstaluj helpera...") }
    static var menuSettings: String { t("Settings...", "Ustawienia...") }
    static var menuSoundTest: String { t("Sound test", "Test dzwieku") }
    static var menuQuit: String { t("Quit", "Zakoncz") }

    static func clankErrorState(_ message: String) -> String {
        t("Clank: error - \(message)", "Clank: blad - \(message)")
    }
    static var clankListening: String { t("Clank: listening", "Clank: nasluchuje") }
    static var clankStopped: String { t("Clank: stopped", "Clank: zatrzymany") }
    static var helperNotInstalledShort: String { t("helper not installed", "helper niezainstalowany") }

    static func lastReadingSlap(amplitude: Double, level: Int) -> String {
        t(
            String(format: "Last reading: %.4fg, level %d/5", amplitude, level),
            String(format: "Ostatni pomiar: %.4fg, poziom %d/5", amplitude, level)
        )
    }
    static func lastReadingLid(angle: Double, delta: Double) -> String {
        t(
            String(format: "Lid angle: %.0f deg, change %.0f deg", angle, delta),
            String(format: "Kat klapy: %.0f deg, zmiana %.0f deg", angle, delta)
        )
    }

    // Alerts
    static var helperRequiredTitle: String {
        t("Clank requires the sensor helper", "Clank wymaga instalacji helpera sensora")
    }
    static var helperRequiredBody: String {
        t(
            "To read the accelerometer, Clank needs to install a background process (LaunchDaemon) once. The standard system prompt for the administrator password will appear.",
            "Aby czytac akcelerometr Clank potrzebuje jednorazowo zainstalowac proces w tle (LaunchDaemon). Pojawi sie standardowy systemowy monit o haslo administratora."
        )
    }
    static var installButton: String { t("Install", "Zainstaluj") }
    static var cancelButton: String { t("Cancel", "Anuluj") }
    static var permissionRequiredTitle: String {
        t("Clank needs administrator privileges", "Clank potrzebuje uprawnien administratora")
    }
    static func sensorHelperStartFailed(_ msg: String) -> String {
        t(
            "Failed to start sensor helper: \(msg)",
            "Nie udalo sie uruchomic helpera sensora: \(msg)"
        )
    }
    static var okButton: String { "OK" }

    static var helperInstalledTitle: String { t("Helper installed", "Helper zainstalowany") }
    static var helperInstalledBody: String {
        t("You can now enable detection.", "Mozesz teraz wlaczyc detekcje.")
    }
    static var uninstallHelperConfirmTitle: String {
        t("Uninstall the Clank helper?", "Odinstalowac helpera Clank?")
    }
    static var uninstallHelperConfirmBody: String {
        t(
            "Accelerometer detection will stop working until reinstalled. The application itself will not be removed.",
            "Detekcja akcelerometru przestanie dzialac do ponownej instalacji. Aplikacja nie zostanie odinstalowana."
        )
    }
    static var uninstallButton: String { t("Uninstall", "Odinstaluj") }
    static var helperUninstalledTitle: String { t("Helper uninstalled", "Helper odinstalowany") }

    // Settings window
    static var preferencesSubtitle: String { t("Preferences", "Ustawienia") }
    static var tabSettings: String { t("Settings", "Ustawienia") }
    static var tabAbout: String { t("About", "O aplikacji") }
    static var tabSounds: String { t("Sounds", "Dzwieki") }
    static var tabLid: String { t("Lid", "Klapa") }
    static var tabDetection: String { t("Detection", "Detekcja") }
    static var changesSaveAutomatically: String {
        t("Changes are saved automatically.", "Zmiany zapisuja sie automatycznie.")
    }
    static var doneButton: String { t("Done", "Gotowe") }

    static var sectionMode: String { t("Mode", "Tryb") }
    static var labelSoundMode: String { t("Sound mode", "Tryb dzwiekow") }
    static var modeOneSoundShort: String { t("1 sound", "1 dzwiek") }
    static var modeFiveSoundsShort: String { t("5 sounds", "5 dzwiekow") }
    static func levelLabel(_ index: Int) -> String { t("Level \(index)", "Poziom \(index)") }

    static var sectionSoundReactions: String { t("Sound reactions", "Reakcje dzwiekowe") }
    static var sectionSoundReactionsFooter: String {
        t("Choose how Clank responds and how loud the reactions should be.",
          "Wybierz sposob reakcji Clank i glosnosc dzwiekow.")
    }
    static var sectionAudioFiles: String { t("Audio files", "Pliki audio") }
    static var labelSoundFile: String { t("Sound", "Dzwiek") }
    static var sectionPlayback: String { t("Playback", "Odtwarzanie") }
    static var labelVolume: String { t("Volume", "Glosnosc") }

    static var sectionSensors: String { t("Sensors", "Sensory") }
    static var sectionSensorsFooter: String {
        t("Tuning affects slap detection and the optional lid movement reaction.",
          "Strojenie dotyczy wykrywania uderzen i opcjonalnej reakcji na ruch klapy.")
    }
    static var sectionLid: String { t("Lid", "Klapa") }
    static var labelAction: String { t("Action", "Akcja") }
    static var labelPlayOnLidMove: String {
        t("Play sound on lid movement", "Odtwarzaj dzwiek przy ruchu klapy")
    }
    static var labelLidSound: String { t("Lid sound", "Dzwiek klapy") }
    static var labelFile: String { t("File", "Plik") }
    static var labelMovementThreshold: String { t("Movement threshold", "Prog ruchu") }
    static var labelCooldown: String { "Cooldown" }
    static var labelSlapCooldown: String { t("Slap cooldown", "Cooldown uderzen") }
    static var labelLidCooldown: String { t("Lid cooldown", "Cooldown klapy") }
    static var labelStopMargin: String { t("Stop margin", "Margines stopu") }
    static var labelMaxLength: String { t("Max length", "Max dlugosc") }
    static var sectionAdvancedTiming: String { t("Advanced timing", "Zaawansowane czasy") }

    static var sectionSlapMeasurement: String { t("Slap measurement", "Pomiar uderzen") }
    static var labelMinSensitivity: String { t("Min sensitivity", "Czulosc minimum") }
    static var labelUpperScale: String { t("Upper scale threshold", "Gorny prog skali") }
    static var sectionReadingPreview: String { t("Reading preview", "Podglad odczytow") }

    static var sectionApplication: String { t("Application", "Aplikacja") }
    static var labelAutostart: String { "Autostart" }
    static var labelLaunchAtLogin: String {
        t("Launch Clank at login", "Uruchamiaj Clank przy logowaniu")
    }
    static var labelLanguage: String { t("Language", "Jezyk") }

    static var chooseButton: String { t("Choose...", "Wybierz...") }
    static var playButton: String { t("Play", "Odtworz") }
    static var notSet: String { t("Not set", "Nie ustawiono") }
    static var failedAutostartTitle: String {
        t("Failed to change autostart", "Nie udalo sie zmienic autostartu")
    }

    static var aboutTagline: String {
        t("A tiny menu bar app that lets your Mac complain.",
          "Mala aplikacja menu bar, dzieki ktorej Mac moze ponarzekac.")
    }
    static var aboutVersion: String { t("Version", "Wersja") }
    static var aboutAuthor: String { t("Author", "Autor") }
    static var aboutAuthorName: String { "conceptfab.com" }
    static var aboutWebsite: String { t("Website", "Strona") }
    static var aboutWebsiteName: String { "clank.conceptfab.com" }
    static var aboutIcons: String { t("Icons", "Ikony") }
    static var aboutIconsCredit: String { "MW Coffee" }
    static var aboutSupport: String { "Buy Me a Coffee" }
    static var aboutHelper: String { "Helper" }
    static var aboutHelperInstalled: String { t("Installed", "Zainstalowany") }
    static var aboutHelperNotInstalled: String { t("Not installed", "Niezainstalowany") }
    static var aboutPlatform: String { t("Platform", "Platforma") }
    static var aboutPlatformValue: String { t("Apple Silicon Mac, macOS 13+", "Apple Silicon Mac, macOS 13+") }
    static var aboutBody: String {
        t("Clank listens for little knocks and lid movement using a local helper. No analytics, no network, just a dramatic Mac.",
          "Clank nasluchuje malych stukniec i ruchu klapy przez lokalnego helpera. Bez analityki, bez sieci, po prostu dramatyczny Mac.")
    }

    // Visualizer
    static var visualSlap: String { t("Slap", "Uderzenie") }
    static var visualLid: String { t("Lid", "Klapa") }
    static var visualNone: String { t("none", "brak") }
    static func visualLevel(_ level: Int) -> String {
        t("level \(level)/5", "poziom \(level)/5")
    }
    static var visualLevelEmpty: String { t("level -", "poziom -") }
    static func visualLidDetail(angle: Double, delta: Double) -> String {
        t(
            String(format: "%.0f deg, change %.0f deg", angle, delta),
            String(format: "%.0f deg, zmiana %.0f deg", angle, delta)
        )
    }

    // Errors (LocalizedError)
    static var errBinaryNotFound: String {
        t("Cannot determine the path of the Clank.app binary.",
          "Nie mozna ustalic sciezki binarki Clank.app.")
    }
    static var errTemplateNotFound: String {
        t("LaunchDaemon plist template is missing from the app bundle.",
          "Brak szablonu LaunchDaemon plist w zasobach aplikacji.")
    }
    static var errScriptCreationFailed: String {
        t("Failed to create the installation script.",
          "Nie udalo sie utworzyc skryptu instalacyjnego.")
    }
    static var errUserCancelled: String {
        t("Installation cancelled by the user.",
          "Instalacja anulowana przez uzytkownika.")
    }
    static func errInstallFailed(_ message: String) -> String {
        t("Helper installation failed: \(message)",
          "Instalacja helpera nie powiodla sie: \(message)")
    }
    static var errDaemonNotInstalled: String {
        t("The sensor helper is not installed. Install it from the menu and try again.",
          "Helper sensora nie jest zainstalowany. Uruchom scripts/install-helper.sh i sprobuj ponownie.")
    }
    static func errEventsFileMissing(_ path: String) -> String {
        t("Helper events file is missing (\(path)). Check that the LaunchDaemon is running: sudo launchctl list | grep clank",
          "Brak pliku zdarzen helpera (\(path)). Sprawdz czy LaunchDaemon dziala: sudo launchctl list | grep clank")
    }
    static var errRequiresRoot: String {
        t("missing root privileges", "brak uprawnien root")
    }
    static var errNoAccelerometer: String {
        t("AppleSPUHIDDevice accelerometer not found",
          "nie znaleziono akcelerometru AppleSPUHIDDevice")
    }
    static var errNoSensors: String {
        t("AppleSPUHIDDevice sensors not found",
          "nie znaleziono sensorow AppleSPUHIDDevice")
    }
    static var errAppBundleUnavailable: String {
        t("Cannot determine the path of Clank.app.",
          "Nie mozna ustalic sciezki aplikacji .app.")
    }
    static func errCode(_ code: Int) -> String {
        t("code \(code)", "kod \(code)")
    }
}
