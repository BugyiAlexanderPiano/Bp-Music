// app/main.cpp — ALS parancssori program: a C++ mag moduljainak összekötése és tesztelése
//
// Használat:
//   als_cli demo                       hangszer nélküli bemutató (konzolra írja a MIDI-t)
//   als_cli ports                      MIDI portok listája (RtMidi build esetén)
//   als_cli live <in> <out>            élő mód a hangszerrel: Soft Registration + 4 virtuális réteg
//   als_cli trim <be.wav> <ki.wav>     sample-vágás riporttal
//   als_cli normalize <mért_LUFS> <CC7> [CC7 ...]   stílusrészek CC7-értékének normalizálása
#include "als/dsp.hpp"
#include "als/session.hpp"
#include "als/wav_io.hpp"

#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

#ifdef _WIN32
#  ifndef NOMINMAX
#    define NOMINMAX
#  endif
#  include <windows.h>
#  include <shellapi.h>
// Windowson az argv a régi kódlapon érkezik; az ékezetes WAV-utakhoz UTF-8-ra alakítjuk
static std::vector<std::string> utf8Args() {
  std::vector<std::string> out;
  int n = 0;
  LPWSTR* w = CommandLineToArgvW(GetCommandLineW(), &n);
  for (int i = 0; w && i < n; ++i) {
    const int len = WideCharToMultiByte(CP_UTF8, 0, w[i], -1, nullptr, 0, nullptr, nullptr);
    std::string s(size_t(len), '\0');
    WideCharToMultiByte(CP_UTF8, 0, w[i], -1, &s[0], len, nullptr, nullptr);
    if (!s.empty()) s.pop_back();
    out.push_back(std::move(s));
  }
  if (w) LocalFree(w);
  return out;
}
#endif

using namespace als;
using yamaha::Section;

// ---------------------------------------------------------------------------
// Minta-regisztráció: R1 + 2 virtuális réteg. A Bank/Program számok csak példák;
// a valódi értékek a modellprofil hangszín-táblájából jönnek.
static SoftRegistration sampleRegistration(const yamaha::ModelProfile& p) {
  SoftRegistration r;
  r.bpm = 96.0;
  r.startSection = Section::MainA;
  r.slots[1] = {true, p.nativePartRxChannels.at(1), {104, 0, 1, "Grand Piano"}, 100, 64, 40, 0};   // R1
  r.slots[4] = {true, p.freeSongChannels.at(0), {0, 0, 48, "Strings (V1)"}, 70, 64, 60, 10};       // V1
  r.slots[5] = {true, p.freeSongChannels.at(1), {0, 0, 52, "Choir (V2)"}, 60, 64, 70, 0};          // V2
  return r;
}

// A virtuális rétegek zónái a regisztrációhoz illesztve
static void applyZones(Session& s) {
  Zone strings;                       // V1: vonós réteg a C3 feletti tartományra, lágyabb velocity
  strings.enabled = true; strings.low = 60; strings.high = 108;
  strings.velCurve = 0.8f; strings.outChannel = s.profile().freeSongChannels.at(0);
  s.layers().setZone(0, strings);

  Zone choir;                         // V2: kórus csak erős leütésre (velocity 90 felett), egy oktávval lejjebb
  choir.enabled = true; choir.low = 60; choir.high = 96; choir.velLow = 90;
  choir.transpose = -12; choir.outChannel = s.profile().freeSongChannels.at(1);
  s.layers().setZone(1, choir);
}

// ---------------------------------------------------------------------------
static int cmdDemo() {
  Session s(makeConsoleTransport(), yamaha::ModelProfile{});

  int clocks = 0;
  s.setRealtimeListener([&](uint8_t st, uint64_t) {
    if (st == 0xF8) ++clocks;
    if (st == 0xFA) std::puts("  [Smart Reader] Start → görgetés indul");
    if (st == 0xFC) std::puts("  [Smart Reader] Stop");
  });

  std::puts("1) Soft Registration hívása (tempo, hangszínek, hangerők, Main A):");
  s.recall(sampleRegistration(s.profile()));

  std::puts("\n2) Virtuális zónák beállítása (V1 vonós, V2 kórus):");
  applyZones(s);

  std::puts("\n3) Billentyű a hangszerről: C4 (60) velocity 100 → R1 helyben szól, V1 + V2 az appból:");
  const uint8_t on[3] = {0x90, 60, 100};
  s.dispatch(on, 3, nowUs());

  std::puts("\n4) Ugyanaz a billentyű felengedve:");
  const uint8_t off[3] = {0x80, 60, 0};
  s.dispatch(off, 3, nowUs());

  std::puts("\n5) Gyenge leütés (velocity 60): csak V1, a kórus nem szólal meg:");
  const uint8_t soft[3] = {0x90, 64, 60};
  s.dispatch(soft, 3, nowUs());
  const uint8_t softOff[3] = {0x90, 64, 0};
  s.dispatch(softOff, 3, nowUs());

  std::puts("\n6) Stílus start, MIDI Clock a hangszertől (1 ütem = 96 impulzus), szakaszváltás:");
  s.styleStart();
  const uint8_t start = 0xFA, clock = 0xF8, stop = 0xFC;
  s.dispatch(&start, 1, nowUs());
  for (int i = 0; i < 96; ++i) s.dispatch(&clock, 1, nowUs());
  std::printf("  [Smart Reader] %d clock impulzus = %.1f ütem 4/4-ben\n", clocks, clocks / 96.0);
  s.section(Section::MainB);
  s.dispatch(&stop, 1, nowUs());
  s.styleStop();
  return 0;
}

static int cmdPorts() {
#ifdef ALS_WITH_RTMIDI
  const auto p = listRtMidiPorts();
  std::puts("Bemenetek:");
  for (size_t i = 0; i < p.inputs.size(); ++i) std::printf("  [%zu] %s\n", i, p.inputs[i].c_str());
  std::puts("Kimenetek:");
  for (size_t i = 0; i < p.outputs.size(); ++i) std::printf("  [%zu] %s\n", i, p.outputs[i].c_str());
  return 0;
#else
  std::puts("Ez a build RtMidi nélkül készült (ALS_WITH_RTMIDI=OFF).");
  return 1;
#endif
}

static int cmdLive(int inPort, int outPort) {
#ifdef ALS_WITH_RTMIDI
  Session s(makeRtMidiTransport(inPort, outPort), yamaha::ModelProfile{});
  int clocks = 0;
  s.setRealtimeListener([&](uint8_t st, uint64_t) {
    if (st == 0xFA) clocks = 0;
    if (st == 0xF8 && ++clocks % 96 == 0) std::printf("\r  ütem: %d   ", clocks / 96), std::fflush(stdout);
  });
  s.identify();
  s.recall(sampleRegistration(s.profile()));
  applyZones(s);
  std::puts("Élő mód: játssz a hangszeren. A hangszer MIDI Transmit beállításában a Right 1 rész\n"
            "legyen az 1-es csatornán. Kilépés: Enter.");
  std::string line; std::getline(std::cin, line);
  return 0;
#else
  (void)inPort; (void)outPort;
  std::puts("Ez a build RtMidi nélkül készült (ALS_WITH_RTMIDI=OFF).");
  return 1;
#endif
}

static int cmdTrim(const std::string& in, const std::string& out) {
  WavData w; std::string err;
  if (!readWav(in, w, &err)) { std::fprintf(stderr, "Hiba: %s\n", err.c_str()); return 1; }
  const auto r = dsp::trim(w.pcm, w.channels, w.sampleRate);
  if (r.silentFile) { std::puts("A fájl csak csendet tartalmaz, nincs mit vágni."); return 2; }
  if (!writeWav(out, w, &err)) { std::fprintf(stderr, "Hiba: %s\n", err.c_str()); return 1; }
  std::printf("Levágva az elejéről: %.3f ms\nLevágva a végéről:   %.3f ms\nCsúcsszint: %.2f dBFS\n%s\n",
              r.cutHeadMs, r.cutTailMs, r.peakDb,
              r.needsReview ? "FIGYELEM: kézi ellenőrzés javasolt (lassú felfutás vagy nincs nullátmenet)"
                            : "Rendben.");
  return 0;
}

static int cmdNormalize(int argc, char** argv) {
  const double measured = std::atof(argv[2]);
  std::vector<dsp::PartLevel> parts;
  for (int i = 3; i < argc; ++i) parts.push_back({uint8_t(8 + parts.size()), uint8_t(std::atoi(argv[i]))});
  const auto r = dsp::normalizeStyle(parts, measured);
  std::printf("Cél: -18 LUFS, mért: %.1f LUFS → alkalmazott: %+.2f dB, maradék: %+.2f dB\n",
              measured, r.appliedDb, r.residualDb);
  for (size_t i = 0; i < r.parts.size(); ++i)
    std::printf("  rész %zu (ch%d): CC7 %d → %d\n", i + 1, r.parts[i].channel + 1, int(parts[i].cc7), int(r.parts[i].cc7));
  return 0;
}

int main(int argc, char** argv) {
#ifdef _WIN32
  static std::vector<std::string> wargs = utf8Args();
  static std::vector<char*> wptrs;
  if (!wargs.empty()) {
    for (auto& a : wargs) wptrs.push_back(&a[0]);
    argc = int(wptrs.size());
    argv = wptrs.data();
  }
#endif
  const std::string cmd = argc > 1 ? argv[1] : "demo";
  try {
    if (cmd == "demo")                    return cmdDemo();
    if (cmd == "ports")                   return cmdPorts();
    if (cmd == "live" && argc >= 4)       return cmdLive(std::atoi(argv[2]), std::atoi(argv[3]));
    if (cmd == "trim" && argc >= 4)       return cmdTrim(argv[2], argv[3]);
    if (cmd == "normalize" && argc >= 4)  return cmdNormalize(argc, argv);
  } catch (const std::exception& e) {
    std::fprintf(stderr, "Hiba: %s\n", e.what());
    return 1;
  }
  std::puts("Használat: als_cli demo | ports | live <in> <out> | trim <be.wav> <ki.wav> | normalize <LUFS> <CC7>...");
  return 1;
}
