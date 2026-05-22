<claude-mem-context>
# Memory Context

# [Clank] recent context, 2026-05-22 7:43pm GMT+2

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision 🚨security_alert 🔐security_note
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 50 obs (13,629t read) | 262,342t work | 95% savings

### May 22, 2026
S1779 Create `page` folder in the Clank project (May 22 at 6:04 PM)
S1780 Merge feat/lid-stop-cutoff into main, push to GitHub, and clean up branches for Clank distribution readiness (May 22 at 6:07 PM)
S1781 Create `page/` folder and populate it with the Clank "Wild" landing page from the Anthropic design handoff bundle (May 22 at 6:07 PM)
S1782 Deliver only the Wild theme — user confirmed to keep just `page/wild.html`, skip Classic and Dark variants (May 22 at 6:11 PM)
S1783 Fix remaining 1.4 MB references in wild.html and commit all landing page work to git (May 22 at 6:13 PM)
5400 6:18p 🔴 Hero DOWNLOAD button updated: size corrected to 3.2MB and link pointed to GitHub releases
5401 " 🟣 Voice chip buttons wired to real audio files via `data-sound` attributes
5402 " 🔴 Install step 3 corrected — removed false `setup.sh` terminal command, replaced with native prompt flow
5403 " ✅ App icon copied to `page/favicon.png` for landing page use
5404 " 🟣 Favicon and Open Graph meta tags added to wild.html
5405 6:19p 🔴 Feature list items in Menu Bar section got explicit ink color and bolder weight
S1784 Nav logo upgrade: replace "CL" text badge with real app icon image in wild.html nav (May 22 at 6:25 PM)
S1785 Rename page/wild.html → page/index.html for static site root serving (May 22 at 6:25 PM)
S1786 Enable squeaky lid option (skrzypienie klapy / lidSoundEnabled) by default in Clank macOS app (May 22 at 6:26 PM)
5406 7:15p 🔵 Clank Project Structure and FTP Tool Availability
5407 " ✅ Squeaky Lid Option Enabled by Default
5408 " 🔵 Complete File Tree for Clank Website Deployment
5409 " 🔵 Squeaky Lid / Creak Feature Files in Clank Project
5410 " 🔵 Existing scripts/ Directory in Clank Project
5411 " 🔵 lidSoundEnabled Defaults to false in Two Places in SoundSettings.swift
5412 " 🔴 lidSoundEnabled Decoder Fallback Changed from false to true
5413 " ✅ lidSoundEnabled Now Defaults to true for Fresh Installs
5414 7:16p ✅ Clank Build Verified After lidSoundEnabled Default Change
5415 " 🟣 FTP Deploy Script Created: scripts/deploy-page.sh
S1787 Create FTP deploy script for Clank website using credentials from .env_ftp (May 22 at 7:16 PM)
5416 " 🔵 Deploy Script Dry-Run Succeeded — FTP Username is Email Address
5417 7:18p 🔵 No Polish Unicode Characters in Swift Source Files
5418 " 🔵 Clank UI Strings Are Polish Without Diacritics
5420 " 🔵 Complete Inventory of Polish UI Strings in Clank
5419 " 🔵 ftp.conceptfab.com Does Not Exist — Correct FTP Host is conceptfab.com
5421 " 🔵 Confirmed FTP Host: conceptfab.com Port 21 Open
5422 " 🔴 Fixed Default FTP Host in deploy-page.sh
5423 7:20p 🔵 ftp.home.pl is a Valid FTP Server But on Different IP
5424 " 🔵 ftp.home.pl Rejects Credentials — 530 Access Denied on All Files
5425 " 🔵 Server IP 185.110.51.69 Hosted by IQ.PL / hostido.net.pl
5426 " 🔵 Account-Specific FTP Hostname Found: host372606.hostido.net.pl
5427 " 🔵 530 Access Denied on All Hostido Hosts — TLS May Be Required
5428 " 🟣 Added FTPS/TLS and --debug Mode to deploy-page.sh
5429 7:21p 🔵 Polish Strings Also Present in HelperInstaller.swift, SensorHelperClient.swift, and AccelerometerMonitor.swift
5430 " 🟣 deploy-page.sh: Debug Logging, Password Redaction, and TLS-Aware curl Invocation
5431 " 🔵 Polish Error Strings Implemented via LocalizedError Protocol in Three Enums
5432 " 🔵 FTP Debug Log: TLS Works, But Password is Wrong — 530 Login Incorrect
5433 " 🔵 FTP Password Parses Correctly — 20 Chars, All Printable ASCII, No Encoding Artifacts
5434 7:22p ⚖️ TLS_MODE Default Changed to reqd — FTPS Enforced by Default
S1788 Create FTP deploy script for Clank website — script complete, blocked on incorrect password in .env_ftp (May 22 at 7:22 PM)
5435 " 🟣 Localization.swift Created with Full EN/PL Bilingual String System
5436 " 🟣 language Field Added to AppSettings Struct
5437 " ✅ language Field Added to AppSettings Codable Decoder with English Default
5438 7:23p ✅ loadDefaults() Updated with language: .en to Complete AppSettings Language Integration
5439 " 🔄 HelperInstallerError Migrated to L Localisation System
5440 " 🔄 SensorHelperClientError and AccelerometerMonitorError Migrated to L System
5441 " 🔄 AccelerometerMonitorError Migrated to L Localisation System
5442 " 🟣 Menu Rebuilds on Settings Change to Support Live Language Switching
5443 " 🔄 AppDelegate rebuildMenu() Fully Migrated to L Localisation System
5444 7:24p 🔄 stateTitle() and refreshMenuState() Migrated to L System in AppDelegate
5445 " 🔄 AppDelegate Alert and Helper Error Strings Migrated to L System
5446 " 🔄 showPermissionAlert and Slap Event Status String Migrated to L System
5447 " 🔄 Lid Event Status String Migrated; Only Helper Install/Uninstall Dialogs Remain in AppDelegate
5448 7:25p 🔄 Helper Install/Uninstall Dialogs Migrated; AppDelegate Nearly Complete
5449 " 🟣 FTP Deployment Script for Frontend + PHP API

Access 262k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>