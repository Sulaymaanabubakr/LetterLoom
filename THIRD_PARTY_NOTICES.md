# Third-party notices

The MIT License in `LICENSE` applies to LetterLoom's original source code only. The following materials are included under separate terms or attribution requirements.

## ENABLE1 word list

`assets/dictionary/enable1.txt` is the ENABLE1 (Enhanced North American Benchmark LExicon) word list. ENABLE is attributed to Alan Beale and M. Cooper and is commonly identified as public domain. This data is used for offline word validation and computer-player search.

The repository preserves the word list as a separate data asset rather than relicensing it under MIT. The checked-in file matches the 172,823-line copy in the upstream repository below (SHA-256: `3f16130220645692ed49c7134e24a18504c2ca55b3c012f7290e3e77c63b1a89`).

References:

- [ENABLE description and attribution](https://www.bytefusion.com/products/op/dm/enable.htm)
- [ENABLE public-domain reference](https://puzzlecottage.com/data/)
- [Exact upstream `enable1.txt` copy](https://github.com/dolph/dictionary/blob/master/enable1.txt)
- [Raw upstream file](https://raw.githubusercontent.com/dolph/dictionary/master/enable1.txt)

## Music

The bundled M4A files in `assets/audio/` are credited in the app's About screen as Kevin MacLeod recordings:

- `menu_music.m4a`: “Midsummer Sky” — Kevin MacLeod.
- `game_music.m4a`: “Sapphire Isle” — Kevin MacLeod.

The tracks are identified as licensed under the Creative Commons Attribution 4.0 International License (CC BY 4.0). Attribution must remain available in the app and in distributions that include these files.

References:

- [Kevin MacLeod music FAQ and attribution guidance](https://music.kevin.macleod.incompetech.com/music/royalty-free/faq.html)
- [Gymnopédie No. 1 track page](https://incompetech.com/music/royalty-free/index.html?Search=Search&isrc=USUAN1100787)
- [Kalimba Relaxation Music track page](https://incompetech.com/music/royalty-free/index.html?Search=Search&isrc=USUAN1900039)
- [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/)

## Fonts

LetterLoom uses the Lora and Inter families through the `google_fonts` Flutter package. These fonts are distributed under the SIL Open Font License, version 1.1, by their respective authors. The font package and its dependency metadata remain separately licensed.

- [Google Fonts licensing](https://developers.google.com/fonts/faq)
- [SIL Open Font License 1.1](https://openfontlicense.org/)

## Software dependencies

Flutter, Dart, Riverpod, Supabase, Firebase, `google_fonts`, `audioplayers`, Next.js, React, TypeScript, and their transitive dependencies retain their own licenses. Direct dependency declarations are in `pubspec.yaml` and `website/package.json`; resolved website license metadata is recorded in `website/package-lock.json`.

## Project artwork and branding

The LetterLoom name, logo, UI artwork, platform icons, feature graphic, and store screenshots are not covered by the MIT source-code license unless explicitly stated by the copyright holder. Do not reuse them as if they were MIT-licensed code.
