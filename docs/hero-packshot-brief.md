# Clank — brief: realistyczny hero packshot

Brief dla modelu generatywnego (Midjourney v6.1+ / Flux.1 Pro / Imagen 3 / Nano Banana / Adobe Firefly 3 z reference image).

Cel: **przełożyć kawaii illustration referencyjną na fotorealistyczny packshot MacBooka** dla sekcji hero. Zachować ten sam dowcip i kompozycję, ale jako rzeczywiste zdjęcie laptopa z domalowanymi (post-procesowo) elementami graficznymi (twarz na ekranie, dymki, ślad uderzenia).

---

## 1. Source reference

Bazą jest istniejąca kawaii ilustracja (`/docs/illustration-brief.md` → A1). Z niej zachowujemy:

- **Pozę MacBooka:** otwarty pod kątem ~110°, frontalnie lub minimalnie ¾ od lewej
- **Wyraz twarzy:** zaciśnięte oczy (`>_<`), otwarte krzyczące usta z różowym językiem, kropla potu, rumieńce na obudowie pod ekranem
- **Speech bubbles:** czerwony „OW!" (duży, dominujący, prawy górny róg), żółty „Ouch!" (lewy), mały „Yowch!" (lewy dół)
- **Sound effect:** „BONK" jako mały, czerwony, komiksowy tekst (gdzieś przy prawej krawędzi ekranu, w miejscu uderzenia)
- **Tło:** ciepłe kremowe `#FAF7F2` / `#F4ECDD`, gładkie, studyjne, NIE białe
- **Star burst:** mała żółta gwiazdka impactu nad lewym górnym rogiem ekranu

## 2. Co jest "realistic"

Sam **MacBook = fotorealistyczny packshot** w stylu Apple marketing photography:

- 15" lub 14" MacBook (proporcje, nie konkretny model) w **kolorze Space Gray / Silver**
- **Brak logo Apple** (zastąp gładką, neutralną aluminiową powierzchnią — w post-processingu można dorobić abstrakcyjne okrągłe wgłębienie albo zostawić czysty metal)
- Realistyczne refleksy na aluminium, subtelne odbicie keyboardu/ekranu na powierzchni stołu pod laptopem
- Ekran **wyłączony i ciemny** (czarne lustro IPS) — to na nim domalowana będzie kawaii twarz, więc model ma wygenerować laptop z **pustym, czarnym, matowym ekranem** gotowym pod overlay
- Studio lighting: soft, **dwa źródła światła** (key light z lewej góry, fill z prawej), miękkie cienie z lekkim warm tone
- Głębia ostrości: lekka, MacBook ostry w całości, tło delikatnie zmiękczone

## 3. Elementy "cartoon overlay" (na realistycznym packshocie)

Te elementy są **rysowane i nakładane na fotorealistyczne tło** — model ma je wygenerować jako część jednego obrazu (NIE jako oddzielną warstwę):

| Element | Styl | Pozycja |
|---|---|---|
| Twarz `>_<` z otwartymi ustami | Hand-drawn, czarne 3-4px kontury, lekko nierówne, różowy język | Centralnie na ekranie MacBooka |
| Rumieńce (cheek blush) | Półprzezroczyste różowe owale `#FFB5B5` | Po obu stronach obudowy pod ekranem (na deck/palm rest) |
| Sweat drop | Cartoon teardrop, niebieski `#7EC4E8` z highlight | Po prawej stronie ekranu, blisko górnej krawędzi |
| Speech bubble „OW!" | Czerwony `#E63946`, biały bold sans-serif text, komiksowy ogonek | Prawy górny róg kadru, częściowo nakłada się na MacBooka |
| Speech bubble „Ouch!" | Żółto-musztardowy `#F5B544`, czarny text | Lewa strona, nad/przy MacBooku |
| Speech bubble „Yowch!" | Off-white / kremowy z czarnym konturem, czarny text | Lewy dolny róg |
| Sound effect „BONK" | Mały, czerwony, hand-lettered, lekko skośny | Prawa krawędź ekranu, w miejscu trafienia |
| Star burst | Żółta 5-ramienna gwiazda `#F5B544`, mała | Nad lewym górnym rogiem ekranu |
| Mała dłoń (opcjonalnie) | Cartoon, jasnoróżowa skóra, trzymająca „OW!" bubble | Pod „OW!" bubble (jak na referencji) |

**Kluczowe:** kontrast między **fotorealistycznym laptopem** a **rysowanymi naklejkami/dymkami** jest CELOWY — to jest core estetyki. Jak realistyczna naklejka na realistycznym laptopie, ale naklejki są ekspresyjne i rysowane.

## 4. Master prompt (Midjourney v6.1 / Flux.1 Pro)

```
photorealistic product photography of an open laptop computer
(15-inch, space gray aluminum, generic non-branded chassis, no logo,
no apple emblem), shot from slight three-quarter front angle, lid
open at 110 degrees, screen completely black and matte, soft studio
lighting with warm key light from upper left and fill from right,
subtle reflection on the table surface, sitting on a smooth warm
cream background #FAF7F2, shallow depth of field --- composited
overlay: a hand-drawn cartoon face painted on the black screen with
tightly squinted eyes ">_<" style, wide open shouting mouth with
visible pink tongue, two semi-transparent pink blush ovals on the
laptop's lower deck below the keyboard, a small cartoon blue teardrop
near the top right of the screen --- comic-style stickers floating
around the laptop: large bold red speech bubble in upper right
saying "OW!" in white sans-serif, smaller mustard-yellow speech
bubble on the left saying "Ouch!", tiny cream speech bubble bottom
left saying "Yowch!", small red hand-lettered "BONK" sound effect
near the right edge of the screen, tiny yellow five-point star above
the upper left screen corner --- hybrid style: photorealistic laptop
with hand-drawn cartoon overlay elements, warm playful mood,
centered composition, generous negative space around laptop
--ar 4:3 --style raw --stylize 200
```

**Negative prompt:**
```
apple logo, branded laptop, real apple computer, macbook logo,
fingerprint, dust, scratches, cluttered background, dark mood,
neon, gradient sky, 3d cartoon, anime face, photorealistic face on
screen, real human face, glowing screen, screen content, wallpaper,
ui elements, keyboard backlight, multiple laptops, person, hand
holding laptop, watermark, signature, text overlay other than
specified bubbles
```

## 5. Parametry per model

| Model | Setup |
|---|---|
| **Midjourney v6.1** | `--ar 4:3 --style raw --stylize 200 --weird 0` + reference image z `--iw 1.5` |
| **Flux.1 Pro** | aspect `4:3`, guidance `3.5`, steps `50`, użyj **image-to-image** z referencją (strength `0.65` żeby zachować kompozycję) |
| **Imagen 3** | mode `photo`, aspect `4:3`, dodaj `with hand-drawn cartoon sticker overlay style` |
| **Nano Banana / Gemini** | wklej referencję, prompt: *"recreate this composition but make the laptop a photorealistic product shot while keeping the cartoon face and speech bubbles as hand-drawn overlays"* |
| **Adobe Firefly 3** | Generate similar → upload referencję → wybierz `Photo` → dodaj structure reference (~50% strength) |

**Rekomendacja #1:** Użyj **Flux.1 Pro + reference image (image-to-image)** lub **Nano Banana** — zachowanie kompozycji referencji + style transfer to ich mocna strona.

**Rekomendacja #2 (plan B):** Wygeneruj sam packshot z czystym czarnym ekranem osobno (Midjourney/Flux), potem dorób overlay w **Figma / Photoshop** ręcznie. Daje to 100% kontroli nad tekstem w dymkach (modele zawsze kuleją z tekstem).

## 6. Wariacje do wygenerowania

Wygeneruj **4-6 wariantów**, różnicując:

1. **Kąt:** front-on vs. ¾ vs. lekko z góry (top-down 15°)
2. **Kolor MacBooka:** silver (jaśniejszy, czystszy) vs. space gray (bardziej premium)
3. **Intensywność overlay:** all-in (wszystkie naklejki) vs. minimalist (tylko twarz + 1 dymek „OW!")
4. **Tło:** plain cream vs. cream z subtelną teksturą papieru / linen
5. **Crop:** tight (MacBook wypełnia 70% kadru) vs. wide (MacBook 40%, dużo negative space na text overlay w landingu)

## 7. Integracja z landing page

**Hero layout — co potrzebne od ilustracji:**

- **Lewy 40% kadru:** clean, prawie pusty (off-white tło) → tam wjeżdża **headline + sub + CTA** w HTML/CSS
- **Prawe 60% kadru:** MacBook + naklejki, z „OW!" bubble jako focal point w prawym górnym
- Asset eksportowany jako **PNG @2x i @1x** (`2400×1800` i `1200×900`)
- **Transparent background fallback:** drugi export bez tła `#FAF7F2` (model wymaskuj background w post — `remove.bg` lub Photoshop), żeby można było zastąpić sekcję hero gradientem CSS jeśli design ewoluuje

## 8. Validation checklist

- [ ] MacBook wygląda jak **fotorealistyczny produkt**, NIE jak 3D render
- [ ] Aluminium ma realistyczne refleksy i subtelne micro-scratches level studio shot
- [ ] Ekran jest **całkowicie czarny i matowy** (gotowy pod face overlay) LUB face overlay jest już naniesiony i ma styl **rysowany** (NIE photorealistic face)
- [ ] BRAK logo Apple, BRAK literek na keyboardzie typu „MacBook Pro" w czytelnej formie
- [ ] Dymki są w specyfikowanej palecie (`#E63946` czerwony, `#F5B544` żółty, kremowy)
- [ ] Tekst w dymkach jest czytelny LUB zastąpiony placeholderem (wstawiony potem w Figma)
- [ ] Kontrast realistic-vs-cartoon działa — naklejki wyglądają jak **applique na zdjęciu**, nie jak część fotki
- [ ] Tło jest jednolite warm cream, BEZ teksu, BEZ artefaktów, BEZ innych obiektów
- [ ] Kompozycja zostawia ~40% negative space po lewej na overlay tekstowy hero
- [ ] Asset czyta się w 1200px szerokości na desktop hero i w 600px na mobile

## 9. TL;DR (jednozdaniowy brief)

> Wygeneruj fotorealistyczny packshot 15-calowego srebrnego/space-gray MacBooka (bez logo Apple) z czarnym matowym ekranem, w studio lighting na ciepłym kremowym tle `#FAF7F2`, z domalowanymi hand-drawn cartoon overlayami: twarz `>_<` z otwartymi krzyczącymi ustami i językiem na ekranie, różowe rumieńce na obudowie, niebieska kropla potu, oraz trzy komiksowe dymki („OW!" duży czerwony w prawym górnym, „Ouch!" żółty po lewej, „Yowch!" kremowy w lewym dolnym) plus mały czerwony „BONK" przy krawędzi ekranu — hybrid style fotorealizm + rysowane naklejki, mood: ciepły, zaczepny, indie product photography.
