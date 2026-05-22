# Clank — brief ilustracyjny

Brief dla modelu generatywnego (Midjourney v6.1+ / DALL-E 3 / Firefly 3 / Nano Banana / Imagen 3). Każdy asset zawiera gotowy prompt do wklejenia + parametry.

---

## 1. Universal style anchors

**Czytaj to przed każdym promptem — to są wspólne reguły dla wszystkich assetów.**

### Styl artystyczny
- **Modern flat illustration** z lekkim cieniowaniem (soft drop shadow, NIE skeuomorfizm)
- Inspiracje: **Stripe illustrations**, **Linear's mascot work**, **Notion early illustrations**, **Slack's character moments**, sketchnoty **Adam JK**
- **Hand-drawn personality** — kontury lekko nierówne, jakby narysowane grubą kredką / brush penem, NIE wektorowo-cyrklowo idealne
- **NIE:** Corporate Memphis, 3D render, isometric, pixel art, anime, photorealistic, watercolor

### Paleta (sztywna — model ma tego trzymać)
- Tło `#FAF7F2` (off-white, ciepłe)
- Akcent OUCH `#FF3B30` (komiksowa czerwień)
- Akcent CTA `#F5B544` (miód / mustard)
- Tekst i kontury `#1A1A1A` (prawie-czarny)
- Cień MacBooka `#E8E0D4` (warm beige shadow)
- Akcent dodatkowy (rzadko): `#3B9DFF` (cool blue) — tylko dla wskaźników akcelerometru

### Shape language
- Zaokrąglone rogi wszędzie (`12-20px` ekwiwalent)
- Linie konturu **2-3px**, ciemne `#1A1A1A`, lekko niejednorodne
- Speech bubbles / dymki komiksowe jako recurring motif
- Drobne hand-drawn ozdoby: kropki, gwiazdki impactu, motion lines

### Mascot canonical look
**MacBook z twarzą** (na ekranie LUB na obudowie pod ekranem — do walidacji wariantów):
- Open clamshell MacBook (15-cal, srebrny `#D8D8D8` chassis)
- Dwa duże okrągłe oczy `#1A1A1A` z białym highlight
- Mała oval usta — kształt zależny od emocji (O = ouch, ~~ = niezadowolenie, zZ = śpi)
- Bez nosa, bez brwi (cleaner look). Brwi opcjonalnie tylko dla ekstra emocji
- Jabłko Apple **NIE pokazywać** (problemy z trademarkiem — zastąpić abstrakcyjnym kółkiem albo pominąć)

### Negative prompt (uniwersalny — wklej do każdego promptu jeśli model wspiera)
```
3d render, photorealistic, gradient, neon, dark background, blurry,
corporate memphis style, isometric, glassmorphism, lens flare,
pixel art, anime, watercolor, busy background, multiple characters,
text artifacts, watermark, logo, apple logo, branded macbook,
real apple computer, signature
```

---

## 2. Asset list (priorytet → opcjonalne)

| # | Asset | Aspect | Use case | Priorytet |
|---|---|---|---|---|
| A1 | Hero illustration | 4:3 lub 16:10 | Above the fold | **MUST** |
| A2 | OG / social card | 1200×630 (1.91:1) | Twitter / OG meta | **MUST** |
| A3 | „How it works" — 3 step icons | 1:1 × 3 | Sekcja 2 | **MUST** |
| A4 | Smack mode card | 4:3 | Sekcja 3a | **MUST** |
| A5 | Lid mode card | 4:3 | Sekcja 3b | **MUST** |
| A6 | App icon / favicon | 1:1, 1024px | Brand / favicon | SHOULD |
| A7 | Mascot expression sheet | 1:1 × 6 | Reuse w UI / dokumentacji | NICE-TO-HAVE |
| A8 | 404 / error mascot | 1:1 | 404 page | NICE-TO-HAVE |

---

## A1 — Hero illustration

**Cel:** Sercem hero. Komunikuje całość produktu w 1 sekundę.

**Kompozycja:**
- Centralnie: MacBook z twarzą, otwarty pod kątem ~110°, lekka 3/4 perspektywa
- Wyraz: zaskoczony / urażony — usta w kształcie `O`, brwi delikatnie uniesione
- Z prawej strony: ludzka ręka (cartoon, schematyczna) palcem wskazującym **właśnie dotknęła** obudowy — krótkie linie ruchu (motion lines) wokół palca
- Nad MacBookiem: duży komiksowy dymek z onomatopeją **„OW!"** w czerwieni `#FF3B30`, bold display font, lekko krzywy/odręczny
- Małe dekoracyjne dymki rozsiane dookoła z innymi okrzykami: *„ouch"*, *„hey!"*, *„yowch"* — mniejsze, w `#1A1A1A`
- Pod MacBookiem: subtelny soft shadow `#E8E0D4`
- Tło: solid `#FAF7F2`, nic więcej

**Prompt (Midjourney / Firefly):**
```
flat illustration of an anthropomorphic open laptop with a surprised face,
two large round black eyes with white highlights, small oval "O"-shaped
mouth, silver chassis, viewed at three-quarter angle, a cartoon human
finger tapping the laptop's lid from the right side with short motion
lines, big comic-style speech bubble above with bold red text "OW!",
a few small secondary speech bubbles around saying "ouch", "hey!",
"yowch" in black, warm off-white background #FAF7F2, soft warm
beige shadow under laptop, hand-drawn outlines with slightly uneven
2-3px black strokes, modern flat illustration style inspired by
Stripe and Linear, NO 3D, NO gradient, NO apple logo, friendly
playful mood, centered composition --ar 4:3 --style raw
```

**Parametry:**
- MJ: `--ar 4:3 --style raw --stylize 250`
- DALL-E 3: użyj `1792x1024` (HD)
- Iteracje: minimum 4 wariacje, wybierz tę z najczystszym tłem i najczytelniejszym dymkiem

---

## A2 — OG / social card

**Cel:** Klikalność w Twitter / iMessage / Slack preview. Działa też jako fallback hero.

**Kompozycja:**
- Wersja **uproszczona** hero — z lewej strony MacBook (mniejszy, ~40% kadru), z prawej duży dymek „OW!" + sub „Your Mac says ouch."
- Tekst „Clank" w lewym górnym rogu jako wordmark (jeśli model nie radzi z tekstem — zostaw miejsce, dorzucisz CSS-em w finalnej wersji)
- Aspect **1.91:1** (1200×630)

**Prompt:**
```
horizontal social media banner, left half: anthropomorphic flat
illustration of a laptop with surprised face and "O" mouth, silver
body, right half: oversized comic speech bubble with bold red text
"OW!" filling the space, warm off-white background #FAF7F2,
hand-drawn 2-3px black outlines, modern flat illustration style,
playful mood, generous empty space for text overlay, no 3D,
no gradient, no apple logo --ar 1.91:1 --style raw
```

---

## A3 — „How it works" 3 step icons

**Cel:** Trzy małe ikony w jednym rzędzie, mocno spójne wizualnie.

**Wymagania:**
- Każda jest **stand-alone**, działa na białym tle
- Ten sam styl konturu, ta sama paleta, ten sam scale postaci
- Spójna kompozycja: postać MacBooka w **tej samej pozie** centralnie w każdej, zmienia się tylko emocja + element wokół

**Krok 1 — „Smack" (palec stuka)**
```
square flat illustration icon, anthropomorphic laptop with neutral
calm face, two round eyes, small straight line mouth, a cartoon finger
descending from above about to tap the laptop chassis, three small
motion arrows around the finger, warm off-white background,
hand-drawn black outlines, no 3D, no gradient --ar 1:1
```

**Krok 2 — „He notices" (akcelerometr)**
```
square flat illustration icon, anthropomorphic laptop with eyes wide
open and raised eyebrows, surprised expression, three small wave lines
radiating outward from the laptop chassis indicating vibration
detection, tiny circular sensor icon with crosshair, warm off-white
background, hand-drawn black outlines, no 3D --ar 1:1
```

**Krok 3 — „He complains" (dźwięk)**
```
square flat illustration icon, anthropomorphic laptop with open "O"
mouth shouting, small comic speech bubble with red text "ow!", small
sound wave arcs emanating from the laptop, slightly tilted body to
suggest motion, warm off-white background, hand-drawn black outlines,
no 3D, no gradient --ar 1:1
```

**KRYTYCZNE:** Wygeneruj trzy razem w jednym promptzie albo użyj funkcji „character reference" (MJ `--cref` / Firefly Style Reference). Spójność jest ważniejsza niż detal.

---

## A4 — Smack mode card

**Kompozycja:**
- Centralnie MacBook z twarzą podobny do hero, ale w **action pose** — drobno przechylony, w trakcie reakcji
- Wokół niego **chmura dymków** z 7-10 różnymi okrzykami: *Ow • Ouch • Hey • Yowch • That stings • What was that • Hey!*
- Każdy dymek nieco inny rozmiar i kąt — wrażenie kakofonii

**Prompt:**
```
flat illustration of an anthropomorphic laptop with surprised
shouting face, slightly tilted body suggesting recent impact, multiple
comic speech bubbles of varying sizes floating around the laptop with
hand-lettered text "ow", "ouch", "hey!", "yowch", "what was that",
"that stings", "hey hey hey", red and black text on white bubbles,
warm off-white background #FAF7F2, hand-drawn 2-3px black outlines,
playful chaotic but balanced composition, no 3D, no gradient,
no apple logo --ar 4:3 --style raw
```

---

## A5 — Lid mode card

**Kompozycja:**
- MacBook w trakcie **zamykania klapy** — ekran pod kątem ~30° (w połowie drogi do zamknięcia)
- Twarz na obudowie z wyrazem „przestraszonego / senego" (półprzymknięte oczy, mały `~` mouth)
- **Wizualna metafora:** zamiast klapy laptopa — uchylone drewniane drzwi z klamką, lekko rozmyte motion lines pokazujące zatrzaśnięcie
- Mały dymek z onomatopeją **„SLAM!"** lub **„WHAM!"** w czerwieni
- Opcjonalnie: małe `Zz` w kącie sugerujące „idzie spać"

**Prompt:**
```
flat illustration of a half-closed anthropomorphic laptop, lid at
30-degree angle being closed, the laptop lid creatively styled as
a wooden door with a brass knob blending into the screen edge,
laptop face on the base shows sleepy half-closed eyes and a small
wavy mouth, motion lines around the closing lid indicating slam,
comic speech bubble with bold text "SLAM!" in red, tiny "Zz" sleep
icon in corner, warm off-white background, hand-drawn black outlines,
playful mood, no 3D, no gradient, no apple logo --ar 4:3 --style raw
```

---

## A6 — App icon / favicon

**Cel:** macOS dock icon + favicon. **Musi czytać się w 16×16**.

**Wymagania:**
- macOS app icon: **squircle** (zaokrąglony kwadrat z grubymi rogami zgodny z Big Sur+ HIG)
- Centralna grafika: **tylko twarz MacBooka** (zbliżenie), bez całego korpusu — przy 16px detal całego MacBooka znika
- Twarz „surprised" — duże oczy + `O` mouth, ta sama paleta
- Tło ikony: gradient nie, **solid color** — proponuję mustard `#F5B544` (rzuca się w doku) ALBO off-white `#FAF7F2` z czarnym konturem (czystsza opcja)
- Brak tekstu

**Prompt:**
```
macOS app icon design, squircle shape with rounded corners following
Big Sur design guidelines, centered close-up illustration of a simple
cute face with two large round black eyes, white highlights, small
oval surprised "O"-shaped mouth, hand-drawn 3px black outlines, solid
mustard yellow background #F5B544, no text, no logo, flat
illustration, no 3D, no gradient, clean readable at small sizes
--ar 1:1
```

**Eksport po wygenerowaniu:**
- `1024×1024` PNG (App Store / source)
- `512×512`, `256`, `128`, `64`, `32`, `16` PNG dla `.icns`
- `favicon.ico` (16+32+48) + `apple-touch-icon.png` (180×180)

---

## A7 — Mascot expression sheet (NICE-TO-HAVE)

**Cel:** Reuse w UI, dokumentacji, error states. 6 wariantów twarzy w jednym arkuszu, ten sam MacBook, różne emocje.

**Stany:**
1. **Neutral** — eyes open, straight mouth (status: listening)
2. **Surprised** — eyes wide, `O` mouth (status: ouch)
3. **Angry** — narrow eyes, brows down, jagged mouth (status: stop it)
4. **Sleepy** — half-closed eyes, `~` mouth (status: lid closed)
5. **Dizzy** — spiral eyes, wavy mouth (status: error)
6. **Happy** — eyes closed crescents, smile (status: working fine)

**Prompt:**
```
character expression sheet, six identical anthropomorphic laptops
in a 3x2 grid, same silver chassis and pose, only facial expressions
change: 1) neutral calm, 2) surprised with O mouth, 3) angry frowning,
4) sleepy with closed eyes, 5) dizzy with spiral eyes, 6) happy with
closed crescent eyes and smile, warm off-white background, hand-drawn
2-3px black outlines, modern flat illustration style, consistent
character design across all six, no 3D, no gradient, no apple logo
--ar 3:2 --style raw
```

---

## A8 — 404 mascot

**Kompozycja:**
- MacBook **leżący na boku** (przewrócony), spiralne oczy (dizzy)
- Mały dymek z napisem „404" lub „ow." w czerwieni
- Pod nim odręczny tekst „page not found" (jeśli model nie radzi z tekstem — zostaw miejsce)

**Prompt:**
```
flat illustration of a knocked-over anthropomorphic laptop lying on
its side, dizzy spiral eyes, small wavy mouth, a single comic speech
bubble with red text "ow.", a few small stars circling around the
laptop indicating disorientation, warm off-white background,
hand-drawn black outlines, modern flat illustration style, sympathetic
mood, no 3D, no gradient, no apple logo --ar 1:1 --style raw
```

---

## 3. Pipeline po wygenerowaniu

1. **Background removal** — wszystkie assety muszą mieć transparent background dla landingu (użyj `remove.bg` albo Photoshop Select Subject)
2. **SVG conversion (opcjonalne, ale zalecane)** — przepuść finalne PNG przez Vectorizer.AI dla A3 i A6, dla A1 zostaw PNG @2x
3. **Optymalizacja** — wszystkie PNG przez TinyPNG / Squoosh do <100KB każdy, SVG przez SVGO
4. **Naming convention dla repo:**
   ```
   /assets/illustrations/
     hero.png            # A1 @2x
     hero@1x.png
     og-card.png         # A2 1200x630
     step-1-smack.svg    # A3.1
     step-2-notice.svg   # A3.2
     step-3-complain.svg # A3.3
     mode-smack.png
     mode-lid.png
     icon-1024.png       # A6 source
     favicon.ico
     mascot-404.svg
   ```

---

## 4. Model recommendation

**Per asset — co najlepiej wygeneruje co:**

| Asset | Rekomendowany model | Dlaczego |
|---|---|---|
| A1, A2, A4, A5 | **Midjourney v6.1** + `--style raw` | Najlepsza spójność stylu „hand-drawn flat", świetny w dymkach |
| A3 (icons) | **Midjourney + `--cref`** (character reference) z A1 | Spójność postaci jest tutaj kluczowa |
| A6 (app icon) | **Firefly 3** lub **Imagen 3** | Lepsze respektowanie sztywnej palety i squircle shape |
| A7 (expression sheet) | **Nano Banana** lub **GPT-4o image** | Najlepiej trzyma „same character różne emocje" |
| A8 | dowolny | Prosty asset |

**Tekst w dymkach:** Wszystkie modele kuleją w tekście. **Plan B:** wygeneruj dymek pusty, tekst dorysuj w Figmie / SVG-em. To i tak będzie wyglądać lepiej.

---

## 5. Validation checklist (przed akceptacją assetu)

- [ ] Paleta zgodna z brief (off-white tło, czerwień `#FF3B30`, miód `#F5B544`)
- [ ] Kontury są ręcznie nierówne, NIE wektorowo idealne
- [ ] Brak logotypu Apple, brak jabłka na MacBooku
- [ ] Brak elementów z innych palet (zielenie, fiolety, gradienty)
- [ ] Postać MacBooka czytelna w 200px szerokości (test scale)
- [ ] Wyraz twarzy zgadza się z intencją sekcji
- [ ] Tło nie ma artefaktów, jest jednolite
- [ ] Tekst w dymkach jest czytelny LUB zastąpiony placeholderem
- [ ] Aspect ratio zgodny ze specyfikacją asset listy

---

## 6. Jednozdaniowy brief dla modelu (TL;DR)

> Wygeneruj serię modern flat illustration assetów dla landing page małej macOS menu-bar apki: zantropomorfizowany srebrny laptop z prostą twarzą (duże okrągłe oczy + wyraziste usta), komiksowe dymki z onomatopejami w stylu „OW!", paleta off-white `#FAF7F2` + komiksowa czerwień `#FF3B30` + akcent miodu `#F5B544`, hand-drawn 2-3px czarne kontury lekko nierówne, styl Stripe/Linear illustrations, BEZ 3D, BEZ gradientów, BEZ logotypu Apple, BEZ Memphis style — ciepły, playful, indie character.
