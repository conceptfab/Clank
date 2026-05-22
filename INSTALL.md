# Clank — instalacja

Clank to aplikacja na pasek menu macOS, ktora odtwarza dzwieki gdy
czujnik klapy / akcelerometr wykryje uderzenie lub ruch klapy.

**Wymagania:**
- Mac z Apple Silicon (M1 / M2 / M3 / M4 / nowsze)
- macOS 13 Ventura lub nowszy

## Instalacja krok po kroku

### 1. Otwarcie DMG i przeciagniecie aplikacji

1. Otworz `Clank-1.0.0.dmg`
2. Przeciagnij `Clank.app` do folderu `Applications`

### 2. Pierwsze uruchomienie — obejscie Gatekeepera

Aplikacja nie jest podpisana przez Apple (nie kupilismy Developer ID),
wiec macOS zablokuje pierwsze uruchomienie. Trzeba to obejsc raz:

**Opcja A — przez Findera (najprostsza):**
1. W `Applications` kliknij `Clank.app` **prawym przyciskiem** (lub Ctrl+klik)
2. Wybierz `Otworz`
3. Pojawi sie ostrzezenie — kliknij `Otworz` jeszcze raz
4. Aplikacja zostaje na bialej liscie. Kolejne uruchomienia juz beda dzialaly normalnie.

**Opcja B — przez Terminal (jezeli A nie zadziala):**
```bash
xattr -dr com.apple.quarantine /Applications/Clank.app
open /Applications/Clank.app
```

### 3. Instalacja helpera sensora (jednorazowo)

Clank potrzebuje uprawnien administratora zeby czytac akcelerometr.
Zamiast prosic o haslo za kazdym razem, instalujemy raz LaunchDaemon
ktory dziala w tle.

W DMG znajdziesz folder `scripts`. Otworz Terminal w tym katalogu
(albo przeciagnij `install-helper.sh` do Terminala) i uruchom:

```bash
./scripts/install-helper.sh /Applications/Clank.app
```

Skrypt poprosi o haslo administratora **raz**. Po wykonaniu:
- helper dziala w tle jako system daemon
- Clank.app moze go uzywac bez sudo
- daemon uruchamia sie automatycznie po restarcie Maca

### 4. Sprawdzenie ze wszystko dziala

1. Otworz `Clank.app` z `Applications`
2. W pasku menu (gora ekranu) powinna pojawic sie ikona Clank
3. Kliknij ikone — w menu rozwinie sie status: `Clank: nasluchuje`
4. Stuknij lekko w obudowe Maca — powinien zagrac dzwiek

Jezeli widzisz `Clank: blad - Helper sensora nie jest zainstalowany`,
wroc do kroku 3.

## Odinstalowanie

```bash
# 1. Helper
./scripts/uninstall-helper.sh

# 2. Aplikacja
rm -rf /Applications/Clank.app
rm -rf ~/Library/Application\ Support/Clank
```

## Diagnostyka

**Helper nie startuje:**
```bash
sudo launchctl print system/dev.conceptfab.clank.sensor-helper | head -20
tail -50 /var/log/clank-helper.log
```

**Sprawdz czy daemon dziala:**
```bash
sudo launchctl list | grep clank
```

Powinno wypisac PID + label `dev.conceptfab.clank.sensor-helper`.

**Brak ikony w pasku menu po uruchomieniu:**
Sprawdz Activity Monitor czy proces `Clank` zyje. Jezeli nie,
otworz Konsole.app, filtruj `Clank` — bedzie tam log bledu.

## Znane ograniczenia (wersja test-friend)

- aplikacja jest Apple Silicon only (Intel Maki nie maja tego akcelerometru)
- parametry detekcji (`Min amplitude`, `Cooldown`) w ustawieniach
  **nie wplywaja** na aktywny helper w tej wersji; sa fixed w plist daemona.
  Zmiana wymaga edycji `/Library/LaunchDaemons/dev.conceptfab.clank.sensor-helper.plist`
  + `sudo launchctl bootout system/... && sudo launchctl bootstrap system/...`.
- aplikacja nie jest podpisana przez Apple — przy kazdym restarcie macOS
  moze pokazac ostrzezenie, jezeli atrybut quarantine zostal odnowiony
  (zazwyczaj nie powraca). W razie potrzeby powtorz `xattr -dr com.apple.quarantine`.
- brak auto-update — nowe wersje trzeba pobrac recznie.
