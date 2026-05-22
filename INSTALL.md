# Clank — instalacja

Clank to aplikacja na pasek menu macOS, ktora odtwarza dzwieki gdy
czujnik klapy / akcelerometr wykryje uderzenie lub ruch klapy.

**Wymagania:**
- Mac z Apple Silicon (M1 / M2 / M3 / M4 / nowsze)
- macOS 13 Ventura lub nowszy

## Instalacja — 3 kroki

### 1. Przeciagnij `Clank.app` do `Applications`

W otwartym oknie DMG przeciagnij ikone `Clank.app` na skrot `Applications`.

### 2. Pierwsze uruchomienie — obejscie Gatekeepera

Aplikacja nie jest podpisana przez Apple (test prywatny), wiec macOS
zablokuje pierwsze uruchomienie. Trzeba to obejsc raz:

**Wariant A — prawym przyciskiem (najprostszy):**
1. W `Applications` kliknij `Clank.app` **prawym przyciskiem** (lub Ctrl+klik)
2. Wybierz `Otworz`
3. Pojawi sie ostrzezenie — kliknij `Otworz` ponownie
4. Aplikacja zostaje na bialej liscie systemu, kolejne uruchomienia juz beda dzialaly normalnie.

**Wariant B — przez Terminal (jezeli A nie zadziala):**
```bash
xattr -dr com.apple.quarantine /Applications/Clank.app
open /Applications/Clank.app
```

### 3. Zainstaluj helpera (jeden klik)

Przy pierwszym uruchomieniu Clank pokaze okno:

> **Clank wymaga instalacji helpera sensora**
> Aby czytac akcelerometr Clank potrzebuje jednorazowo zainstalowac proces w tle (LaunchDaemon).

Kliknij `Zainstaluj`. Pojawi sie standardowy systemowy monit o haslo
administratora — wpisz haslo Maca i potwierdz.

Po chwili w pasku menu (gora ekranu) pojawi sie ikona Clank. Kliknij ja
— status powinien byc `Clank: nasluchuje`.

Stuknij lekko w obudowe Maca — powinien zagrac dzwiek. Otworz/zamknij klape
(jezeli wlaczyles dzwiek klapy w ustawieniach) — powinien zagrac dzwiek klapy.

## Odinstalowanie helpera

Z menu Clank w pasku menu wybierz: `Helper... > Odinstaluj helpera...`.
Aplikacja poprosi o potwierdzenie i haslo administratora.

## Odinstalowanie aplikacji

```bash
# Najpierw odinstaluj helpera (przez menu Clank, patrz wyzej).
# Potem usun aplikacje i jej dane:
rm -rf /Applications/Clank.app
rm -rf ~/Library/Application\ Support/Clank
```

## Diagnostyka

**Helper nie dziala:**
```bash
sudo launchctl print system/dev.conceptfab.clank.sensor-helper | head -20
tail -50 /var/log/clank-helper.log
```

**Wymusz reinstalacje helpera:**
W menu Clank: `Helper... > Reinstaluj helpera...`

**Brak ikony w pasku menu:**
Sprawdz Activity Monitor czy proces `Clank` zyje. Jezeli nie, otworz Konsole.app,
filtruj `Clank` — bedzie tam log bledu.

## Znane ograniczenia (wersja test-friend)

- Apple Silicon only (Intel Maki nie maja tego akcelerometru)
- parametry detekcji (`Min amplitude`, `Cooldown`) w oknie ustawien **nie
  wplywaja** na aktywny helper w tej wersji; sa hardcoded w plist daemona.
  Zmiana wymaga rownoczesnej edycji plist + bootout/bootstrap daemona.
- aplikacja nie jest podpisana przez Apple — przy kazdym restarcie macOS moze
  pokazac ostrzezenie, jezeli atrybut quarantine zostal odnowiony (zwykle nie).
  W razie potrzeby powtorz `xattr -dr com.apple.quarantine`.
- brak auto-update — nowe wersje pobierasz recznie.
