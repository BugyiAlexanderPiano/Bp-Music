# ALS – Yamaha Arranger Live Suite (projektváz)

## Letöltés

**[Releases → latest](https://github.com/BugyiAlexanderPiano/Bp-Music/releases/tag/latest)**

| Fájl | Rendszer | Indítás |
| --- | --- | --- |
| `ALS-Program-Windows.zip` | Windows 10/11 | Kicsomagolás után az `ALS` mappában az **`ALS.exe`** |
| `ALS-Program-macOS.zip` | macOS 12 Monterey vagy újabb (Intel és Apple Silicon; a 2015-ös MacBook Pro/Air is) | Első indításkor: jobb klikk az **ALS** alkalmazásra → Megnyitás → Megnyitás |

### A PC-s szerkesztő (1. szakasz) funkciói

- **Menüsor:** Fájl (Új, Megnyitás, Mentés, Mentés másként, dalszöveg import), Szerkesztés, Nézet, Hangszer, Eszközök, Súgó
- **Projektfájl:** `.alsproj` – dalok, regiszter bankok, rétegek, téma és elrendezés egy fájlban; automatikus mentés
- **Téma:** egyszínű vagy átmenetes (2–4 színű) háttér, beépített színválasztó, kész témák, panel-átlátszóság és sarokkerekítés
- **Dalszöveg:** betűtípus- és színválasztás, akkordok a szöveg fölött, fejlécben hangnem / tempó / ütem / stílus
- **Dal-szerkesztő:** `[G]szöveg [D]akkordokkal`, `{Main A}` szakaszjelölők, élő előnézet, transzponálás, dalhoz kötött regisztráció
- **Szinkron a hangszerre (F5):** tempó, indító szakasz, rétegek és hangszínek egy kattintással
- **Bal panel:** hangszíncsoportok, kattintásra nyíló alkategóriák; húzd-és-ejtsd a V1–V4 helyekre
- **Alsó sáv:** V1–V4 rétegek, One Touch Settings, tempó (TAP), regiszter bankok (bankonként 8 hely)
- **Lapozás:** dalok között húzással vagy nyilakkal; a lakat gomb lezárja az oldalt
- **Elrendezés-szerkesztés** (Nézet menü): panelek átméretezése húzással, oldalcsere, panelek ki/be

### Következő szakaszok

2. Tabletes / telefonos fellépő mód (Android, iPad, iPhone) és átvitel a PC-ről (Wi-Fi, USB)
3. Regiszter bank szerkesztő, aktiváló kód és Instrument Info alapú másolásvédelem

Az `ALS-Windows.zip` a parancssori segédeszköz (fejlesztéshez, teszteléshez).

A csomagot minden feltöltés után a GitHub Actions készíti el (`.github/workflows/windows-build.yml`).

A 7 modul két rétegben áll össze:

- **C++ mag (1–5. modul)** → `als_core` statikus könyvtár. Ezt linkeli a `als_cli` parancssori program (`app/main.cpp`) és a Flutter alkalmazás DLL-je (`als_core_ffi`).
- **Flutter felület (6–7. modul)** → Dart kód, amely a magot `dart:ffi`-n keresztül hívja.

## Könyvtárszerkezet

```
als/
├─ CMakeLists.txt
├─ app/main.cpp                      parancssori program: demo, ports, live, trim, normalize
├─ core/
│  ├─ include/als/
│  │  ├─ midi_transport.hpp          ÚJ: közös MIDI interfész (a modulok erre építenek)
│  │  ├─ yamaha_proto.hpp            1. modul
│  │  ├─ soft_registration.hpp       2. modul (deklarációk)
│  │  ├─ layer_engine.hpp            3. modul
│  │  ├─ dsp.hpp                     4–5. modul (deklarációk)
│  │  ├─ wav_io.hpp                  ÚJ: WAV olvasás/írás a vágóhoz
│  │  ├─ session.hpp                 ÚJ: a modulokat összekötő központ
│  │  └─ als_core_api.h              ÚJ: C interfész a Flutternek
│  └─ src/
│     ├─ midi_transport.cpp, rtmidi_transport.cpp, wav_io.cpp, als_core_api.cpp
│     ├─ soft_registration.cpp       2. modul
│     └─ dsp/sample_trimmer.cpp      4. modul
│        dsp/style_normalizer.cpp    5. modul
└─ flutter_app/
   ├─ pubspec.yaml
   └─ lib/
      ├─ main.dart                   felület váza: 4 sáv, a modulok bekötése
      ├─ ffi/als_core.dart           a C++ mag Dart-kötése
      ├─ reader/teleprompter_controller.dart   6. modul
      └─ sync/sync_client.dart                 7. modul
```

A dokumentum kódvázlataihoz képest két változtatás van: a 2. és az 5. modul struktúrái fejlécfájlba (`.hpp`) kerültek, hogy több fájlból is elérhetők legyenek, és a vázlatokban csak hivatkozott `MidiTransport` interfész most valóban létezik.

## Hogyan hívják egymást a modulok

```
              ┌───────────────────── Session (session.hpp) ─────────────────────┐
Hangszer ─MIDI─► MidiTransport ─► dispatch() ─┬─► VirtualLayerEngine (3) ─► MidiTransport ─► Hangszer
                                              └─► realtime listener (F8/FA/FC)
                                                       │  C API: als_set_realtime_callback
                                                       ▼
                                           TeleprompterController (6, Dart)

UI / CLI ─► Session::recall() ─► recall() (2) ─► yamaha_proto (1) ─► MidiTransport ─► Hangszer
UI / CLI ─► styleStart / section / tempo ─► yamaha_proto (1) ─► MidiTransport

Studio  ─► readWav ─► dsp::trim (4) ─► writeWav
Studio  ─► LUFS-mérés ─► dsp::normalizeStyle (5) ─► CC7-ek a stílusba / Soft Registrationbe

Tablet  ─► SyncClient.pull (7) ─HTTPS─► PC szinkronszerver   (tisztán Dart, a mag nem kell hozzá)
```

1. A `Session` birtokolja a transzportot, a modellprofilt és a `VirtualLayerEngine`-t.
2. A transzport minden bejövő üzenetet a `Session::dispatch()`-nek ad: a real-time üzenetek (Clock, Start, Stop) a Smart Readerhez mennek, a hangjegyek és kontrollerek a rétegmotorhoz.
3. A rétegmotor ugyanazon a transzporton küldi vissza a virtuális réteg hangjait a hangszer Song-csatornáira.
4. A felület (CLI vagy Flutter) csak a `Session` metódusait hívja; a Flutter ezt a C API-n (`als_core_api.h`) keresztül teszi.

## Windows: egy kattintással (ingyenes)

Kattints duplán az `ALS_Inditas.bat` fájlra. Első indításkor letölti az ingyenes, telepítés nélküli w64devkit fordítót (`tools\` mappába) és az RtMidi forrást (`third_party\`), lefordítja a programot (`bin\als_cli.exe`), utána menüt mutat. A további indítások már azonnaliak. Egy WAV fájlt a `.bat` ikonjára húzva azonnal levágja (`..._vagott.wav`). A teljes mappa törölhető, a rendszerben semmi nem marad.

## Fordítás (CMake-kel, fejlesztőknek)

Szükséges: CMake 3.16+, C++17 fordító (Visual Studio 2019+, Xcode, GCC/Clang).

```bash
# Hangszer nélküli próba (nincs külső függőség)
cmake -S . -B build -DALS_WITH_RTMIDI=OFF
cmake --build build --config Release
./build/als_cli demo

# Valódi USB-MIDI kapcsolattal (az RtMidi-t a CMake automatikusan letölti a GitHubról)
cmake -S . -B build
cmake --build build --config Release
./build/als_cli ports
./build/als_cli live 0 0          # bemeneti és kimeneti port száma a listából
```

Platformonkénti megjegyzések:

- **Windows 10/11**: Visual Studio „Desktop development with C++”. A Genos/Tyros USB-MIDI-hez a Yamaha USB-MIDI Driver telepítése ajánlott.
- **macOS**: `xcode-select --install`, utána a fenti parancsok.
- **Linux (fejlesztéshez)**: RtMidi-hez `sudo apt install libasound2-dev`.
- **Android**: az `als_core_ffi` könyvtár NDK-val fordul (Flutter `android/app/build.gradle` → `externalNativeBuild { cmake { path "../../CMakeLists.txt" } }`, `-DALS_WITH_RTMIDI=OFF`). Androidon az USB/BLE MIDI-t az `android.media.midi` kezeli; ehhez egy Androidos `MidiTransport` megvalósítás kell még (Kotlin → JNI → `deliver()`).
- **Windows 7 / XP (Legacy)**: a `v141_xp` toolsettel fordítható a mag. Hogy az RtMidi 6 XP-n fut-e, ellenőrizni kell; ha nem, egy saját WinMM-transzport (kb. 100 sor) a megoldás.

## Parancsok

| Parancs | Mit csinál |
| --- | --- |
| `als_cli demo` | Hangszer nélkül végigjátssza a modulok együttműködését, a MIDI-t hexában kiírja |
| `als_cli ports` | MIDI portok listája |
| `als_cli live <in> <out>` | Élő mód: Soft Registration + 2 virtuális réteg, ütemszámláló a MIDI Clockból |
| `als_cli trim be.wav ki.wav` | Sample-vágás riporttal |
| `als_cli normalize -22.5 100 90 110` | Mért LUFS és a részek CC7-értékei alapján új CC7-ek |

## Flutter alkalmazás

```bash
cd flutter_app
flutter create --platforms=windows,macos,android .   # platformmappák létrehozása
flutter pub get
# a lefordított als_core_ffi könyvtárat másold a futtatható mellé (Windows: build/windows/.../Release/)
flutter run
```

## Hangszeres beállítás az élő módhoz

- A hangszer **MIDI Transmit** beállításában a Right 1 rész küldjön az 1-es csatornán (a `ModelProfile::rightOneTxChannel` ezt várja).
- A 9–12-es csatorna fogadása a Song részekre legyen állítva (`freeSongChannels`).
- A SysEx- és a Bank/Program-értékek a profilban példák: élesítés előtt a modell Data List-jéből kell véglegesíteni őket.
