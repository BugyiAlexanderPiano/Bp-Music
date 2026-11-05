// core/src/als_core_api.cpp — a C interfész megvalósítása a Session köré
#include "als/als_core_api.h"

#include "als/dsp.hpp"
#include "als/session.hpp"
#include "als/wav_io.hpp"

#include <atomic>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <string>

namespace {
std::mutex g_mutex;
std::unique_ptr<als::Session> g_session;
std::atomic<als_realtime_cb> g_rtCb{nullptr};

int copyOut(const std::string& s, char* buf, int32_t len) {
  if (buf && len > 0) {
    const size_t n = std::min<size_t>(s.size(), size_t(len - 1));
    std::memcpy(buf, s.data(), n);
    buf[n] = '\0';
  }
  return int(s.size() + 1);
}

template <class F> int32_t withSession(F f) {
  std::lock_guard<std::mutex> g(g_mutex);
  if (!g_session) return -1;
  f(*g_session);
  return 0;
}
} // namespace

extern "C" {

int32_t als_list_ports(char* buf, int32_t buflen) {
  std::string s;
#ifdef ALS_WITH_RTMIDI
  try {
    const auto p = als::listRtMidiPorts();
    for (const auto& n : p.inputs)  s += "IN:" + n + "\n";
    for (const auto& n : p.outputs) s += "OUT:" + n + "\n";
  } catch (...) {}
#endif
  return copyOut(s, buf, buflen);
}

int32_t als_open(int32_t inPort, int32_t outPort, int32_t useConsole) {
  std::lock_guard<std::mutex> g(g_mutex);
  try {
    std::unique_ptr<als::MidiTransport> t;
#ifdef ALS_WITH_RTMIDI
    if (!useConsole) t = als::makeRtMidiTransport(inPort, outPort);
#else
    (void)inPort; (void)outPort; (void)useConsole;
#endif
    if (!t) t = als::makeConsoleTransport();
    g_session = std::make_unique<als::Session>(std::move(t), als::yamaha::ModelProfile{});
    g_session->setRealtimeListener([](uint8_t st, uint64_t ts) {
      if (auto cb = g_rtCb.load()) cb(st, int64_t(ts));
    });
    return 0;
  } catch (...) {
    g_session.reset();
    return -2;
  }
}

void als_close(void) { std::lock_guard<std::mutex> g(g_mutex); g_session.reset(); }
void als_set_realtime_callback(als_realtime_cb cb) { g_rtCb.store(cb); }
int64_t als_now_us(void) { return int64_t(als::nowUs()); }

int32_t als_style_start(void) { return withSession([](als::Session& s) { s.styleStart(); }); }
int32_t als_style_stop(void)  { return withSession([](als::Session& s) { s.styleStop(); }); }
int32_t als_section(int32_t code) {
  return withSession([&](als::Session& s) { s.section(als::yamaha::Section(uint8_t(code))); });
}
int32_t als_tempo(double bpm) {
  if (bpm < 5 || bpm > 500) return -3;
  return withSession([&](als::Session& s) { s.tempo(bpm); });
}

int32_t als_set_zone(int32_t slot, int32_t enabled, int32_t low, int32_t high, int32_t velLow,
                     int32_t velHigh, int32_t transpose, float curve, int32_t outCh) {
  als::Zone z;
  z.enabled = enabled != 0;
  z.low = uint8_t(low); z.high = uint8_t(high);
  z.velLow = uint8_t(velLow); z.velHigh = uint8_t(velHigh);
  z.transpose = int8_t(transpose); z.velCurve = curve; z.outChannel = uint8_t(outCh & 0x0F);
  return withSession([&](als::Session& s) { s.layers().setZone(slot, z); });
}

int32_t als_trim_wav(const char* inPath, const char* outPath, char* report, int32_t len) {
  als::WavData w; std::string err;
  if (!als::readWav(inPath, w, &err)) { copyOut("{\"error\":\"" + err + "\"}", report, len); return -1; }
  const auto r = als::dsp::trim(w.pcm, w.channels, w.sampleRate);
  if (r.silentFile) { copyOut("{\"error\":\"csak csend\"}", report, len); return -2; }
  if (!als::writeWav(outPath, w, &err)) { copyOut("{\"error\":\"" + err + "\"}", report, len); return -3; }
  char json[256];
  std::snprintf(json, sizeof json,
                "{\"cutHeadMs\":%.3f,\"cutTailMs\":%.3f,\"peakDb\":%.2f,\"needsReview\":%s}",
                r.cutHeadMs, r.cutTailMs, r.peakDb, r.needsReview ? "true" : "false");
  copyOut(json, report, len);
  return 0;
}

} // extern "C"
