# Clank — brief dla landing page

## 1. Czym jest produkt

**Clank** to darmowa, natywna aplikacja na pasek menu macOS (Apple Silicon, macOS 13+) z jednym, absurdalnym celem: **MacBook reaguje głosem, gdy go uderzysz**. Akcelerometr wykrywa stuknięcie w obudowę, Clank odtwarza losowy okrzyk:

> *„Ow!"*, *„Ouch!"*, *„Hey, that hurts!"*, *„Ow, stop it!"*, *„What was that for?"*, *„Yowch!"*, *„That stings!"*

Drugi tryb: **zamknięcie klapy** wyzwala dźwięk trzaskających drzwi. MacBook „idzie spać" trzaskając drzwiami.

Wersja `1.0.0`, dystrybucja prywatna (dla znajomych), bez Apple Developer ID — ad-hoc signed DMG.

## 2. Pozycjonowanie i ton

- **Kategoria mentalna:** żart, gadżet, „digital pet" dla MacBooka — bliżej Tamagotchi niż utility
- **Ton:** ciepły, niegrzeczny, lekko zaczepny. Mac jest **żywą istotą**, która ma swoje granice i nie boi się o nich powiedzieć
- **NIE:** korporacyjne, productivity, „boost your workflow", emoji-spam
- **TAK:** suchy humor, personifikacja Maca, lekki sarkazm, slice-of-life

**Przykładowe hasła do gry z:**
- „Your MacBook has feelings now."
- „Stop hitting your laptop. Or don't. He'll tell you about it."
- „Finally — your Mac talks back."
- „He says ouch."

**Sub-headline w tym tonie:**
> Tiny menu bar app. Reads the accelerometer. Plays *„ow"* when you smack your MacBook. That's the whole product.

## 3. Grupa docelowa

- Geeky użytkownicy macOS, którzy mają już Rectangle, Stats, Maccy, Ice, Karabiner
- Ludzie kupujący zabawne stickery na laptopa
- Internet-native, indie-dev twitter / r/macapps audience
- Zero overlap z biznesem / enterprise

## 4. Kierunek wizualny

**Reference set (małe macOS menu-bar apps z charakterem):**
- [rectangleapp.com](https://rectangleapp.com) — minimalizm, jasne tło, jeden ekran
- [maccy.app](https://maccy.app) — clean, jeden duży screenshot
- [climateapp.uk](https://climate.lol) / [bunchapp.co](https://bunchapp.co) — bardziej character-driven
- [shottr.cc](https://shottr.cc) — playful color, retro vibe

**Mood:**
- **Cartoony, ale ostry** — nie disney, raczej *Adventure Time* / *Cyanide & Happiness* lekkość
- Duża maskotka: **stylizowany MacBook z oczami i ustami** (otwarte zamkniete „Ow!" w dymku). Może być po prostu okrągły face na laptopie
- Można zagrać w *„speech bubble overload"* — kilka małych dymków z różnymi okrzykami rozrzuconych po hero section

**Kolory (propozycja, do walidacji):**
- **Tło:** off-white `#FAF7F2` lub gentle peach `#FFE9D6` (ciepłe, nie chłodne tech-grey)
- **Akcent #1 (UWAGA / OUCH):** czerwień komiksowa `#FF3B30` (zbieżne z macOS red, działa na „ouch")
- **Akcent #2:** mustard / honey `#F5B544` dla CTA i highlightów
- **Tekst:** prawie-czarny `#1A1A1A`, nigdy `#000`
- **NIE:** gradienty SaaS, glassmorphism, dark mode hero

**Typografia:**
- Headline: **Geist Sans** lub **Inter** bold/black weight, ewentualnie coś z charakterem jak **Söhne** / **Neue Haas Grotesk Display**
- Akcenty / dymki: **rounded display** — np. **Fraunces** italic, lub komiksowa **Bagel Fat One** dla onomatopei („OW!", „OUCH!")
- Body: ten sam co headline, light weight

**Shape language:**
- Zaokrąglone rogi `12-20px`
- Speech bubbles (dymki komiksowe) jako recurring motyw
- Drobne sketch-style strzałki / podkreślenia ręczne (hand-drawn underlines)
- ZERO 3D, ZERO blur, ZERO neonu

## 5. Struktura strony (above the fold + 4 sekcje)

### Hero
- **Headline:** „Your Mac says ouch."
- **Sub:** „Smack your MacBook. He yelps. That's it. That's the app."
- **Visual:** Stylizowany MacBook z twarzą, ręka z palcem stukająca w obudowę, dymek z „OW!"
- **CTA:** `Download Clank 1.0` (button) + drobny link `View on GitHub`
- **Disclaimer pod CTA (małym fontem):** „Free. Apple Silicon. macOS 13+. Unsigned — instructions inside."

### Sekcja 2: „How it works" (3 kroki, ikony + krótki tekst)
1. **Smack.** „Tap your MacBook anywhere on the chassis."
2. **He notices.** „The accelerometer feels it."
3. **He complains.** „One of 10 voice lines plays. Loudly."

Wariant: animowany loop pokazujący rękę stukającą + dymek pojawiający się + ikonkę dźwięku.

### Sekcja 3: „Two modes"
Dwie karty obok siebie:

**A) Smack mode** — „10 angry voice lines, randomized."
- Lista przykładów: *Ow • Ouch • Hey that hurts • Ow stop it • What was that for • Yowch • That stings*

**B) Lid mode** — „Closes the lid? Slams the door."
- Krótki tekst, ikonka drzwi + ikonka klapy MacBooka

### Sekcja 4: „It lives in your menu bar"
- Screenshot paska menu macOS z ikoną Clank rozwiniętą w menu (status: „Clank: nasluchuje" → przetłumaczyć na „Clank: listening"; oryginalne UI jest po polsku, **na landing użyć angielskiej wersji UI w screenshotach** — wymaga przygotowania mockupu)
- Bullet list:
  - „Doesn't appear in the Dock."
  - „Pause anytime."
  - „Sensitivity sliders if he's too loud."
  - „Bring your own sounds."

### Sekcja 5: „Install" (krótko, z linkiem do pełnego INSTALL.md)
- 3 kroki w jednej linii: `Download DMG → Drag to Applications → Run helper script (once)`
- **Honest disclaimer box:** „Clank isn't signed by Apple — Gatekeeper will warn you on first launch. Right-click → Open. Full instructions [here](INSTALL.md)."

### Footer
- „Made by ConceptFab. macOS Apple Silicon only. v1.0.0."
- Link: GitHub, License (MIT), Email
- **NIE:** Twitter ikony 50 sztuk, newsletter signup, „Made with love"

## 6. Tone-of-voice — przykładowe mikrokopie

| Element | Copy |
|---|---|
| 404 / error | „Ow. Page not found." |
| Empty state | „Nothing happened. Try smacking your laptop." |
| Tooltip nad ikoną | „He's listening." |
| Download button | „Get Clank →" |
| Secondary CTA | „See the code" |
| Cookie banner (jeśli) | Nie ma. Strona statyczna. |

## 7. Interakcje (opcjonalnie, jeśli budżet pozwala)

- **Hover na hero MacBook → emituje dźwięk + dymek** (Web Audio API, jeden z 10 plików `.mp3`)
- **Kursor stuka w MacBooka → losowy okrzyk** (max 1 na 2s, żeby nie zalać)
- **Easter egg:** trzykrotne kliknięcie w logo Clank → MacBook „mdleje" (animacja przewrócenia)
- **Reduced motion:** wszystko statyczne, tylko CSS hover

## 8. Constraints i wymagania techniczne

- **Stack landing page:** statyczna strona — single HTML + CSS + odrobina vanilla JS. Bez Reacta, bez Next.js, bez build steppa. Hosting na GitHub Pages albo Cloudflare Pages
- **Domena:** TBD (sugestia: `clank.app`, `clank.lol`, `getclank.com` — do walidacji dostępności)
- **Performance budget:** <100KB JS, <500KB total page weight (bez audio). Audio lazy, on user gesture
- **A11y:** WCAG AA. Dźwięki przyciszone do max -10dB, autoplay zakazany, focus states widoczne
- **SEO:** opengraph z hero image (MacBook + dymek), Twitter card large
- **Brak:** analytics trackerów, fontów Google (samohostuj), cookies, popupów

## 9. Co dostarczyć

1. **`index.html`** — semantyczny HTML, prawdziwe `<section>`, `<button>`, alt-text
2. **`style.css`** — single file, custom properties dla kolorów/spacingu
3. **`script.js`** — interakcje audio, intersection observer dla animacji wejścia, nic więcej
4. **Assety:** hero illustration (SVG > PNG), 1 screenshot paska menu (PNG @2x), favicon + apple-touch-icon
5. **OG image** 1200×630 — MacBook z dymkiem „OW!"
6. **`README` w repo strony** — jak deployować

## 10. Co NA PEWNO wycina się z tej strony

- Sekcja „Testimonials" (apka jest dla znajomych, 0 reviews)
- „As seen on Product Hunt"
- Newsletter
- Pricing (jest darmowy — wystarczy słowo „Free" w hero)
- Comparison table z konkurencją (nie ma konkurencji, to żart)
- Feature comparison Pro/Free
- Video demo dłuższe niż 8 sekund
- FAQ ze >5 pytaniami

## 11. Jednozdaniowy brief dla designera

> Zbuduj jednoekranowy, ciepły landing dla menu-barowej żartowej apki na Maca, która krzyczy „ow!" gdy ją uderzysz — w stylu Rectangle / Maccy, ale z komiksowym charakterem (dymki, maskotka MacBooka z twarzą, akcent czerwień + miód, off-white tło), bez SaaS-owego entuzjazmu, z honest disclaimerem o braku podpisu Apple.
