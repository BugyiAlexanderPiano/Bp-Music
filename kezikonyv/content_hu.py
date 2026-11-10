# SoundNexus Pro – használati útmutató, magyar szöveg
# Jelölés: "## " alcím, "- " felsorolás, "> " tipp-doboz, "! " figyelmeztetés, **félkövér**, egyéb sor = bekezdés.
# shot: a képernyőkép neve (shots/<nyelv>_<shot>.png); video: a videó feliratai (rövid mondatok)

META = dict(
    title='SoundNexus Pro',
    subtitle='Részletes használati útmutató',
    version='1.0-s kiadás · 2026. november',
    toc='Tartalom',
    fig='ábra',
    intro_video='SoundNexus Pro – használati útmutató',
    outro_video='A teljes, részletes leírás a PDF-kézikönyvben található.',
)

SECTIONS = [
dict(id='intro', title='Mi a SoundNexus Pro?', shot='main', body='''
A SoundNexus Pro szerkesztő és élő vezérlő program **Yamaha Genos 2, Genos, Tyros 5, Tyros 4 és PSR-SX** hangszerekhez. Egy helyen kezeli a dalaidat (szöveg, akkordok, kotta), a hangszíneket, a ritmust, a rétegeket (V1–V4), az OTS-t és a regisztrációkat, és egy gombnyomással beállítja a hangszert a dalhoz.
A program két részből áll, és ez a legfontosabb szabály:
- **PC / Mac – szerkesztő:** itt történik minden tervezés és szerkesztés: dalok, kotta, gombok, színek, képek, elrendezés, sablonok, hangminták.
- **Tablet / telefon – fellépő mód:** csak használat. A mobil a PC-ről kapott csomagot játssza le, ott semmit nem lehet átírni – így a színpadon nem tud elállítódni semmi.
A munkamenet tehát mindig: **PC-n megtervezed → elküldöd a tabletre / telefonra → a mobilon fellépsz.**
> A programban 20 nyelv választható, és a PC-n előre megnézheted, hogyan fog kinézni a felület tableten és telefonon.
''', video=['A SoundNexus Pro Yamaha Genos, Tyros és PSR-SX hangszerekhez készült.',
            'A PC-n vagy Macen szerkesztesz, a tableten vagy telefonon fellépsz.',
            'A mobilon semmi nem állítódhat el: ott csak használni lehet.']),

dict(id='install', title='Telepítés', shot=None, body='''
A program a GitHub-kiadásból tölthető le (Releases → latest). Telepítő nem kell, és a rendszerbe semmit nem ír.
## Windows (szerkesztő)
- Töltsd le a **SoundNexusPro-Windows.zip** fájlt, és csomagold ki egy tetszőleges mappába (pl. Dokumentumok).
- Indítsd el a **SoundNexus Pro.exe** fájlt. Windows 10 és 11 alatt fut.
- Ha a Windows SmartScreen figyelmeztet: „További információ” → „Futtatás mindenképp”.
## Mac (szerkesztő)
- Töltsd le a **SoundNexusPro-macOS.zip** fájlt, csomagold ki, és húzd a programot az Alkalmazások mappába.
- Első indításkor: jobb klikk a programon → Megnyitás → Megnyitás. Intel és Apple Silicon gépen is fut, a 2015-ös MacBook Pro / Air is támogatott.
## Android tablet és telefon (fellépő mód)
- Másold a **SoundNexusPro-Android.apk** fájlt a készülékre, és nyisd meg.
- Engedélyezd az „ismeretlen forrásból” való telepítést, ha a rendszer rákérdez. Android 7.0 vagy újabb kell.
## iPad és iPhone
- A program iOS-re is elkészül, de a telepítéshez Apple fejlesztői fiók szükséges. Amint ez be van állítva, az iOS-változat is bekerül a kiadásba.
! A beállításaid (nyelv, megjelenési mód) és az automatikus mentés a felhasználói mappádban, a „SoundNexus Pro” alkönyvtárban vannak. A program mappája bármikor törölhető vagy áthelyezhető.
''', video=['Windows: csomagold ki a ZIP-et, és indítsd el a SoundNexus Pro.exe fájlt.',
            'Mac: első indításkor jobb klikk → Megnyitás.',
            'Android: másold a készülékre az APK fájlt, és telepítsd.']),

dict(id='settings', title='Első indítás: nyelv és megjelenési mód', shot='settings', body='''
A jobb felső sarokban lévő **fogaskerék** ikonnal (vagy a Nézet → Nyelv és megjelenési mód… menüvel) nyílik a beállítás ablak.
## Nyelv
20 nyelv közül választhatsz: magyar, angol, német, francia, spanyol, olasz, portugál, holland, lengyel, cseh, szlovák, román, horvát, szerb, szlovén, orosz, ukrán, bolgár, görög és török. A választás azonnal érvényes, és a program megjegyzi.
## Megjelenési mód
- **Automatikus:** PC-n és Macen a szerkesztő (PC mód), tableten a tablet elrendezés, telefonon a telefonos elrendezés.
- **PC:** a teljes szerkesztő, menüsorral és minden szerkesztő ablakkal.
- **Tablet:** előnézet a PC-n, pontosan úgy, ahogy a tableten megjelenik: három oszlop egymás mellett.
- **Telefon:** előnézet a PC-n: középen a dal, a hangszínek és a ritmus oldalról húzható be.
> Tablet vagy Telefon módban a PC-n is csak nézni lehet, szerkeszteni nem – pont mint a mobilon. A felső sávban lévő **„Vissza PC módba”** gombbal térsz vissza a szerkesztőhöz.
''', video=['A fogaskerék ikonnal választod ki a nyelvet és a megjelenési módot.',
            '20 nyelv közül választhatsz.',
            'Tablet és Telefon módban a PC-n előre látod a mobil felületet.']),

dict(id='main', title='A főablak felépítése', shot='main', body='''
A főablak öt részből áll:
- **Menüsor (felül):** Fájl, Szerkesztés, Nézet, Hangszer, Eszközök, Súgó. Jobbra a fogaskerék, a kapcsolat jelzője (zöld = kapcsolódva, sárga = teszt mód, piros = nincs kapcsolat) és a Kapcsolódás gomb.
- **Hangszínek (bal sáv):** csoportokba rendezett hangszín-gombok, két oszlopban. Egy gomb megnyomása elküldi a hangszínt a hangszerre.
- **Dal (középen):** a dal szövege akkordokkal, vagy a kotta, vagy mindkettő. Lapozás a nyilakkal vagy oldalra húzással.
- **Ritmus (jobb sáv):** Start / Stop, Intro, Main A–D, Fill In, Break, Ending, TAP tempó, tempó + / −.
- **Alsó vezérlősáv:** rétegek (V1–V4), One Touch Settings (OTS 1–4), regiszter bankok, tempó, szinkron gomb.
A választóvonalak egérrel húzhatók, így a sávok szélessége állítható.
## Fájl menü
- Új projekt (Ctrl+N), Megnyitás… (Ctrl+O), Mentés (Ctrl+S), Mentés másként… (Ctrl+Shift+S).
- Küldés tabletre / telefonra…, Dalszöveg importálása (.txt)…, Kilépés.
A projekt fájl kiterjesztése **.snxproj** (a régi .alsproj fájlokat is megnyitja). A program a munkát automatikusan is menti, így áramszünet után sem vész el semmi.
''', video=['Bal oldalon a hangszínek, középen a dal, jobb oldalon a ritmus.',
            'Alul a rétegek (V1–V4), az OTS és a regiszter bankok.',
            'A választóvonalak húzásával állíthatod a sávok szélességét.']),

dict(id='connect', title='Kapcsolódás a hangszerhez', shot='connect', body='''
## PC / Mac
- Kösd össze a hangszer **USB TO HOST** aljzatát a számítógéppel egy USB-kábellel (USB-B vagy USB-C), és kapcsold be a hangszert.
- Kattints a jobb felső **Kapcsolódás** gombra (vagy Hangszer → Kapcsolódás…).
- Válaszd ki a **MIDI kimenetet (a hangszer felé)** – Genos esetén pl. „Digital Keyboard-1” vagy „Genos-1” –, és ha kell, a MIDI bemenetet is.
- Ha a lista üres: ellenőrizd a kábelt és a hangszer bekapcsolását, majd kattints a **Frissítés** gombra.
## Android / iPad / iPhone
- USB: USB-C / OTG kábel vagy adapter a hangszer USB TO HOST aljzatába.
- Bluetooth: a **Bluetooth keresés** gombbal Bluetooth MIDI adaptert (vagy Bluetooth MIDI-képes hangszert) is kereshetsz.
## Teszt mód
Ha nincs hangszer csatlakoztatva, a program teszt módban fut: minden gomb működik, de a parancsok nem mennek ki. Ezt a sárga jelzés mutatja.
! Ha egy gombra az jelenik meg, hogy „Előbb kapcsolódj a hangszerhez”, a MIDI kapcsolat nincs felépítve.
''', video=['Kösd a hangszer USB TO HOST aljzatát a számítógéphez.',
            'Kapcsolódás gomb → válaszd ki a hangszer MIDI kimenetét.',
            'Mobilon USB OTG kábelt vagy Bluetooth MIDI adaptert használhatsz.']),

dict(id='voices', title='Hangszínek: a bal sáv szerkesztése', shot='voices', body='''
A **Nézet → Hangszín-panel szerkesztő…** ablakban rendezed be a bal sávot.
- **Csoportok:** pl. Zongora, Orgona, Vonósok, Gitár, Rézfúvós, Szóló. Új csoport, átnevezés, törlés; a sorrend húzással változik.
- **Hangszínek:** minden gombhoz megadod a nevet és a hangszer listájából a **Bank MSB / LSB / Program** számot (a hangszer Data List kézikönyvében találod).
- **Oszlopok:** egy, két vagy három oszlop; a gombok kinézete (szín, kép, felirat, alak) itt is állítható.
- **Alap hangszín-tár:** kész kiinduló csoportok, ha az elejéről kezdenéd.
## Mit hol változtass?
- Más hangszínt ad egy gomb → javítsd az MSB / LSB / Program számot.
- Másik részre (Right 1, Right 2, Left) menjen a hangszín → állítsd át a MIDI csatornát.
''', video=['A Hangszín-panel szerkesztőben csoportokat és gombokat hozol létre.',
            'Minden gombhoz Bank MSB, LSB és Program szám tartozik.',
            'A sorrend húzással változtatható.']),

dict(id='rhythm', title='Ritmus: a jobb sáv szerkesztése', shot='rhythm', body='''
A **Nézet → Ritmus-panel szerkesztő…** ablakban döntöd el, mely gombok legyenek a jobb sávon és milyen sorrendben.
- Választható elemek: Start / Stop, Intro A–C, Main A–D, Fill In, Break, Ending A–C, TAP tempó, Tempó + / −, Szinkron.
- **Hozzáadás:** a „Hozzáadás:” sorban választod ki az új elemet. **Eltávolítás:** az elem melletti mínusz ikonnal.
- **Sorrend:** húzással. **Oszlopok:** a sáv 1–3 oszlopos lehet.
A stílust magát **a hangszeren** választod ki; a SoundNexus Pro innen indítja, váltja a szakaszokat és állítja a tempót.
''', video=['A Ritmus-panel szerkesztőben választod ki a jobb oldali gombokat.',
            'Start, Intro, Main A–D, Fill In, Break, Ending és tempó.',
            'A stílust a hangszeren választod ki, innen vezérled.']),

dict(id='bottom', title='Alsó vezérlősáv: V1–V4, OTS, regiszter bankok', shot='bottom', body='''
A **Nézet → Alsó vezérlősáv szerkesztő…** ablakban állítod össze az alsó sáv elemeit balról jobbra.
- **Rétegek (V1–V4):** négy virtuális réteg a hangszer Song-csatornáin. Mindegyikhez hangszín, billentyűzóna, oktáv, hangerő és velocity-görbe tartozik (pl. „csak erős leütésre”).
- **One Touch Settings (OTS 1–4).**
- **Regiszter bankok:** a SoundNexus Pro saját regisztrációi, bankonként 8 hellyel.
- **Tempó, Szinkron gomb, Lakat.**
## Regisztráció mentése és behívása
- Kattints a **Mentés** gombra a sávon, majd a hely számára: a pillanatnyi beállítás oda kerül.
- Később a számra kattintva behívod. Az üres hely ezt írja: „üres. Mentéshez: Mentés, majd a szám.”
''', video=['Az alsó sávon vannak a V1–V4 rétegek, az OTS és a regiszter bankok.',
            'Mentéshez: Mentés gomb, majd a hely száma.',
            'A számra kattintva visszahívod a beállítást.']),

dict(id='slot', title='Egy réteg (V1–V4) beállítása', shot='slot', body='''
PC-n a V1–V4 gombok egyikére kattintva nyílik meg a réteg beállító ablaka:
- **Bekapcsolva:** a réteg szól-e.
- **Hangszín (Bank MSB / LSB / Program)** és **MIDI csatorna** (a hangszer Song-csatornái); a **Hangszín küldése** gombbal azonnal kipróbálhatod.
- **Billentyűzóna:** melyik hangtól melyikig szóljon (pl. csak a bal kéz alatt).
- **Oktáv**, **Hangerő**.
- **Velocity-görbe:** pl. „Csak erős leütésre” – a réteg csak akkor szólal meg, ha erősebben ütöd le a billentyűt.
> Tipp: vonós réteg a zongora alá V1-en, csak erős leütésre szóló rézfúvós V2-n – így egy kézzel két hangszínt vezérelsz.
''', video=['A V1–V4 gombra kattintva állítod be a réteget.',
            'Hangszín, billentyűzóna, oktáv, hangerő és velocity-görbe.',
            'Például: rézfúvós csak erős leütésre.']),

dict(id='song', title='Dal szerkesztése: szöveg, akkordok, kotta', shot='song', body='''
Új dal: **Szerkesztés → Új dal…**; meglévő dal: **Szerkesztés → Dal szerkesztése…** (Ctrl+E).
## Adatok
Cím, előadó, hangnem, tempó, ütemmutató, stílus neve (ezt a hangszeren választod), indító szakasz, rétegek.
## Szöveg és akkordok
Az akkordot szögletes zárójelbe írod a szótag elé, a szakaszváltást kapcsos zárójelbe, a megjegyzést # jellel:
- [G]Szöveg [D]akkordokkal
- {Main A} szakasz – innen a hangszer Main A-ra vált
- # megjegyzés – csak neked látszik
Szöveget .txt fájlból is importálhatsz (UTF-8).
## Kotta
- **MIDI importálása…:** a program beolvassa a MIDI fájlt, megkérdezi, melyik sáv a dallam, és dallam + akkord kottát készít. A ritmikai rács (nyolcad / tizenhatod) a kotta pontosságát állítja.
- A **tempó és ütemmutató átvétele** gombbal a MIDI tempója kerül a dalba.
- A teljes MIDI a dalhoz csatolódik: a tableten a **Dal lejátszása** gomb a hangszeren játssza le.
## Nézet
A dal szöveggel, kottával vagy a kettővel együtt jelenhet meg.
## Szinkron (F5)
A **Szinkron a hangszerre** egy mozdulattal elküldi a tempót, a szakaszt és a rétegeket.
> Az automatikus kottázás MP3/MP4 felvételből (hangszerek szétválasztása, hangfelismerés) a következő, B. szakaszban érkezik.
''', video=['A dalszerkesztőben adod meg a címet, a tempót és a hangnemet.',
            'Akkord: [G], szakaszváltás: {Main A}, megjegyzés: # jel.',
            'MIDI importálásával dallam + akkord kotta készül.',
            'F5: egy mozdulattal beállítja a hangszert a dalhoz.']),

dict(id='theme', title='Téma, színek, háttérkép', shot='theme', body='''
**Nézet → Téma és színek…**
- **Kész témák:** Aurora, Neon, Óceán, Napnyugta, Láva, Smaragd, Arany, Jég, Levendula, Éjkék, Szén, Bíbor.
- **Háttér:** egyszínű, átmenetes vagy **mozgó színátmenet** (beállítható egy kör ideje és az átmenet iránya; a színek körbeforgatása is).
- **Háttérkép:** saját kép feltöltése (max. 3 MB) – teljes kép, kitöltés vagy mozaik, elmosás, sötétítés, átlátszóság.
- **Kiemelőszín, panelszín, panel átlátszóság.**
**Nézet → Betűtípus és szöveg…:** betűtípus, betűméret, szövegszínek.
**Nézet → Sávok stílusa:** minden sávnak (hangszínek, dal, ritmus, alsó sáv) saját háttér, keret, sarkok kerekítése és térköz adható.
''', video=['Tizenkét kész téma közül választhatsz.',
            'Mozgó színátmenet és saját háttérkép is beállítható.',
            'Minden sávnak saját stílus adható.']),

dict(id='edit', title='Felület szerkesztése: gombok és sávok', shot='edit', body='''
**Nézet → Felület szerkesztése (gombok, sávok)**.
- **Bármely gombra kattintva** a gomb kinézete állítható: kép a gombon (feltöltéssel), felirat és színe, gombszín, méret, alak (szögletes, lekerekített, kapszula, kör), kép láthatósága (csak a kép, felirat nélkül is).
- **A sávok sarkában lévő narancs ecsettel** az egész sávot alakítod.
- **A választóvonalak** húzhatók; a **Méretek alaphelyzetbe** visszaállítja őket.
A szerkesztés végén kapcsold ki ugyanezzel a menüponttal, majd mentsd a projektet.
! Szerkeszteni csak PC módban lehet. A tablet és a telefon pontosan ezt a kinézetet kapja meg.
''', video=['Felület szerkesztése módban bármely gomb kinézete átírható.',
            'Kép, felirat, szín, méret és alak.',
            'A narancs ecsettel az egész sávot alakítod.']),

dict(id='sample', title='SoundNexus Sample Studio: hangminták vágása', shot='sample', body='''
**Eszközök → SoundNexus Sample Studio…** – csend és lecsengés levágása WAV hangmintákról, **mintapontosan**. A megmaradó minták bitre változatlanok: nincs újramintavételezés és nincs bitmélység-váltás.
- **WAV megnyitása:** egy vagy több fájl (kötegelt feldolgozás).
- **Kezdőpont küszöb, Lecsengés küszöb, Zajpadló:** mennyire legyen érzékeny a vágás.
- **Kattanásmentes lezárás:** 5–20 ms fade a végén.
- **Vágás indítása**, majd az eredmény: mennyit vágott az elejéről és a végéről, „formátum változatlan ✓”.
- **Mentés:** a program megkérdezi, hová mentse (felülírja-e vagy új fájl legyen).
! Lassú felfutású hangnál (pl. pad) hallgasd meg, nem vágott-e bele a hang elejébe.
''', video=['A Sample Studio mintapontosan vágja le a csendet és a lecsengést.',
            'A megmaradó minták bitre azonosak az eredetivel.',
            'Mentéskor megkérdezi, hová kerüljön a fájl.']),

dict(id='loop', title='SoundNexus Loop Studio: loop pontok', shot='loop', body='''
**Eszközök → SoundNexus Loop Studio…** – kattanásmentes loop pontokat keres kitartott hangmintákhoz, és beírja őket a WAV fájl **smpl** blokkjába (ezt olvassa a Yamaha Expansion Manager és a legtöbb sampler).
- Kitartott hang (vonós, pad, orgona, kórus) a legjobb.
- **Legrövidebb loop**, **Alaphang (MIDI)**, **Crossfade** (equal-power; nélküle a minták érintetlenek).
- **Loop pontok keresése** → eredmény: loop kezdete és vége (minta és ms), varrat-egyezés %, hangerő-eltérés.
- A **varrat nagyítva** mutatja a loop végét (balra) és elejét (jobbra): egyenletes átmenet = nincs kattanás.
''', video=['A Loop Studio kattanásmentes loop pontokat keres.',
            'A pontok a WAV fájl smpl blokkjába kerülnek.',
            'A varrat nagyításán ellenőrizheted az átmenetet.']),

dict(id='normalize', title='Stílus hangerő-normalizálás', shot=None, body='''
**Eszközök → Hangerő-normalizálás…** – a stílusok hangerejét egységesíti (cél: −18 LUFS).
- Add meg a stílus mért hangerejét (LUFS) és a részek jelenlegi CC7 értékeit szóközzel elválasztva.
- A **Számítás** megadja az új CC7 értékeket részenként, és ha marad különbség, azt a stílushangerőbe kell tenni.
''', video=[]),

dict(id='send', title='Küldés tabletre / telefonra', shot='send', body='''
**Fájl → Küldés tabletre / telefonra…** – a projektből fellépő csomag (.snxshow) készül: dalok, kották, MIDI-k, képek, gombok, téma, regisztrációk.
## 1. Wi-Fi (ajánlott)
- A PC és a mobil legyen **ugyanazon a Wi-Fi hálózaton**.
- PC-n: **Küldés indítása**. Megjelenik egy **6 jegyű kód**.
- Mobilon: SoundNexus Pro → **Fogadás PC-ről**. A mobil magától megkeresi a gépet; ha nem találja, írd be a PC-n kiírt címet.
- Add meg a 6 jegyű kódot → **Letöltés**. A PC kiírja, hány eszközre töltődött le.
! Ha a Windows tűzfal rákérdez, engedélyezd a „Magánhálózat” hozzáférést.
## 2. Fájlként (USB-kábel, Bluetooth, AirDrop)
- **Csomag mentése (.snxshow)**, majd másold a mobilra (Androidon a Letöltések mappába, iPhone/iPaden a Fájlok appba).
- Mobilon: Fogadás → **Megnyitás fájlból (.snxshow)**.
Az átvitel ellenőrzőösszeggel védett: sérült csomagot a mobil nem fogad el.
''', video=['Fájl → Küldés tabletre / telefonra.',
            'Wi-Fi: Küldés indítása, a mobilon Fogadás PC-ről, majd a 6 jegyű kód.',
            'Fájlként is átviheted: .snxshow csomag USB-n vagy AirDroppal.']),

dict(id='tablet', title='Fellépő mód tableten', shot='tablet', body='''
Tableten a felület három oszlop: bal oldalt a hangszínek, középen a dal, jobb oldalt a ritmus, alul a vezérlősáv. Minden gomb ugyanúgy működik, mint a PC-n, de **szerkeszteni nem lehet**.
- **Lapozás:** oldalra húzással vagy a nyilakkal; az előző / következő dal gombokkal.
- **Oldal lezárása (lakat):** a dal nem lapoz el véletlen érintéstől.
- **Dal lejátszása:** a csatolt MIDI-t a hangszeren játssza le.
- **Görgetés indítása:** a szöveg a tempó szerint görög (belső óra).
- **Fogadás PC-ről:** új csomag betöltése. A program indításkor az utoljára fogadott csomagot nyitja meg.
''', video=['Tableten három oszlop: hangszínek, dal és ritmus.',
            'A lakattal lezárod az oldalt, így nem lapoz el véletlenül.',
            'A Dal lejátszása gomb a hangszeren játssza le a MIDI-t.']),

dict(id='phone', title='Fellépő mód telefonon', shot='phone', body='''
Telefonon középen a dal látszik teljes szélességben. A **hangszínek balról, a ritmus jobbról** húzható be, vagy a felső sáv bal és jobb szélén lévő ikonnal nyitható. Az alsó sáv elemei vízszintesen görgethetők.
> A PC-n a Telefon mód pontosan ezt mutatja – küldés előtt ott ellenőrizd, elférnek-e a gombok és olvasható-e a szöveg.
''', video=['Telefonon középen a dal, a hangszínek és a ritmus oldalról húzható be.',
            'A PC Telefon módjában előre ellenőrizheted.']),

dict(id='about', title='Billentyűparancsok', shot='about', body='''
- **Ctrl+N** új projekt · **Ctrl+O** megnyitás · **Ctrl+S** mentés · **Ctrl+Shift+S** mentés másként
- **Ctrl+E** dal szerkesztése · **F5** szinkron a hangszerre
- **← / →** lapozás · **Szóköz** Start / Stop
Macen a Ctrl helyett a Cmd billentyűt használd.
''', video=['Ctrl+S mentés, Ctrl+E dal szerkesztése, F5 szinkron.',
            'Nyilak: lapozás, Szóköz: Start / Stop.']),

dict(id='where', title='Mit hol változtass? – gyors kereső', shot=None, table=[
    ('Más nyelvet szeretnék', 'Fogaskerék → Nyelv'),
    ('Látni akarom, milyen lesz tableten / telefonon', 'Fogaskerék → Megjelenési mód: Tablet / Telefon'),
    ('Rossz hangszínt ad egy gomb', 'Nézet → Hangszín-panel szerkesztő → MSB / LSB / Program'),
    ('Új hangszín-csoport kell', 'Nézet → Hangszín-panel szerkesztő → Új csoport'),
    ('Más gombok legyenek a ritmus sávon', 'Nézet → Ritmus-panel szerkesztő'),
    ('V1–V4, OTS, regiszter a sávon', 'Nézet → Alsó vezérlősáv szerkesztő'),
    ('Egy gomb képe, színe, felirata', 'Nézet → Felület szerkesztése → kattints a gombra'),
    ('Egy teljes sáv háttere, kerete', 'Nézet → Sávok stílusa, vagy a narancs ecset'),
    ('A háttér, a színek, a mozgó átmenet', 'Nézet → Téma és színek'),
    ('Betűtípus, betűméret', 'Nézet → Betűtípus és szöveg'),
    ('Dal szövege, akkordjai, tempója', 'Szerkesztés → Dal szerkesztése (Ctrl+E)'),
    ('Kotta a dalhoz', 'Dal szerkesztése → Kotta → MIDI importálása'),
    ('A hangszer nem reagál', 'Hangszer → Kapcsolódás, MIDI kimenet kiválasztása'),
    ('A változás menjen a tabletre', 'Mentés, majd Fájl → Küldés tabletre / telefonra'),
    ('Csend a WAV elején / végén', 'Eszközök → SoundNexus Sample Studio'),
    ('Loop pont a WAV-ba', 'Eszközök → SoundNexus Loop Studio'),
], body='''
A bal oszlopban, amit el akarsz érni; a jobb oszlopban, hol teheted meg.
''', video=[]),

dict(id='trouble', title='Hibaelhárítás', shot=None, body='''
## Nem található MIDI-eszköz
- Kapcsold be a hangszert, és a kábelt a hangszer **USB TO HOST** aljzatába dugd (nem az USB TO DEVICE-ba).
- Kattints a Frissítés gombra. Más USB-portot vagy kábelt is próbálj ki.
- Mobilon: OTG kábel / adapter kell; Bluetooth esetén a Bluetooth keresést használd.
## A mobil nem találja a PC-t
- Ugyanazon a Wi-Fin vagytok? (Vendéghálózaton a készülékek gyakran nem látják egymást.)
- A PC-n fut a küldés? Engedélyezted a tűzfalban a „Magánhálózat” hozzáférést?
- Írd be kézzel a PC-n kiírt címet (pl. 192.168.1.20).
## „Hibás kód” vagy „Sérült átvitel”
Ellenőrizd a 6 jegyű kódot; sérült átvitelnél egyszerűen próbáld újra.
## A kép nem tölthető fel
A kép legfeljebb 3 MB lehet – kicsinyítsd le.
## A MIDI fájl nem olvasható
Csak szabványos MIDI (.mid) fájl importálható; a Yamaha saját stílusfájljai nem.
## A projekt nem nyitható meg
Csak .snxproj (vagy régi .alsproj) fájl nyitható meg projektként; a mobilra szánt csomag .snxshow.
''', video=[]),

dict(id='plans', title='Tervezett funkciók', shot=None, body='''
Ezek a funkciók a következő kiadásokban érkeznek:
- **Automatikus kottázás MP3 / MP4 felvételből** (B. szakasz): a program a PC-n, helyben választja szét a hangszereket és ismeri fel a hangokat; előtte megkérdezi, milyen hangszerek és hány szólam van a felvételen.
- **OTS behívása MIDI-n** a modellek Data List-je alapján.
- **Regiszter bank szerkesztő** bővítése és **védelem** (aktiváló kód + a hangszer Instrument Info kódjához kötés).
- **iPad / iPhone** telepítőcsomag (Apple fejlesztői fiók után).
- A kézikönyv és a videó további 18 nyelven.
''', video=[]),
]
