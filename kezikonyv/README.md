# Használati útmutató (PDF + feliratos videó)

- `content_hu.py`, `content_en.py` – a kézikönyv szövege és a videó feliratai (egy fájl nyelvenként).
- `build_pdf.py` – PDF készítése (HTML → Chrome), `build_video.py` – 1920×1080-as feliratos MP4.
- A képernyőképeket a Windows-build készíti minden ablakról, magyarul és angolul (`shots/<nyelv>_<ablak>.png`);
  a build naplójából a `fetch_shots.py` állítja vissza őket.

Új nyelv: másold le a `content_en.py`-t `content_<kód>.py` néven, fordítsd le, a buildben add hozzá a nyelvet
a képernyőkép-lépés `foreach ($lang in ...)` listájához, majd futtasd: `python3 build_pdf.py <kód>` és `python3 build_video.py <kód>`.
