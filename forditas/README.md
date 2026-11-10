# Fordítások (20 nyelv)

A program szövegei a forráskódban magyarul vannak, `tr('...')` hívásban. A többi 19 nyelv táblája a
`flutter_app/lib/i18n/lang/*.dart` fájlokban van, és ezekből a szövegfájlokból készül.

## Ha új szöveg kerül a programba
1. `python3 forditas/collect_templates.py` – frissíti a `forrasszovegek.json` listát (ábécérendben).
2. A `forditas/forditasok/<nyelv>.txt` fájlokban a sorok sorrendje megegyezik a `forrasszovegek.json`
   sorrendjével: minden sor egy fordítás. Az új szöveg fordítását a megfelelő helyre kell beszúrni.
3. `python3 forditas/gen_lang.py` – legenerálja a 19 Dart-táblát, és ellenőrzi, hogy a helyőrzők
   (`{0}`, `{1}` …) és a sortörések (`\n`) minden nyelvben megvannak-e.

Ha egy szövegnek nincs fordítása, a program az angolt, ha az sincs, a magyart mutatja.
A Yamaha-kifejezések (Intro, Main, Fill In, Break, Ending, OTS, Start/Stop) minden nyelven angolul maradnak,
ahogy a hangszer kijelzőjén is.
