// core/src/wav_io.cpp
#include "als/wav_io.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>

namespace als {

static uint32_t rd32(const uint8_t* p) { return uint32_t(p[0]) | uint32_t(p[1]) << 8 | uint32_t(p[2]) << 16 | uint32_t(p[3]) << 24; }
static uint16_t rd16(const uint8_t* p) { return uint16_t(p[0] | p[1] << 8); }

bool readWav(const std::string& path, WavData& out, std::string* err) {
  auto fail = [&](const char* m) { if (err) *err = m; return false; };
  std::ifstream f(std::filesystem::u8path(path), std::ios::binary);   // UTF-8 út (ékezetes mappák Windowson)
  if (!f) return fail("A fájl nem nyitható meg");
  std::vector<uint8_t> b((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
  if (b.size() < 12 || std::memcmp(b.data(), "RIFF", 4) || std::memcmp(b.data() + 8, "WAVE", 4))
    return fail("Nem RIFF/WAVE fájl");

  uint16_t fmtTag = 0; bool haveFmt = false;
  size_t pos = 12;
  while (pos + 8 <= b.size()) {
    const uint32_t size = rd32(&b[pos + 4]);
    const uint8_t* body = &b[pos + 8];
    const size_t avail = std::min<size_t>(size, b.size() - pos - 8);
    if (!std::memcmp(&b[pos], "fmt ", 4) && avail >= 16) {
      fmtTag = rd16(body);
      out.channels = rd16(body + 2);
      out.sampleRate = int(rd32(body + 4));
      out.bitsPerSample = rd16(body + 14);
      if (fmtTag == 0xFFFE && avail >= 26) fmtTag = rd16(body + 24);   // EXTENSIBLE: alformátum
      out.isFloat = (fmtTag == 3);
      haveFmt = true;
    } else if (!std::memcmp(&b[pos], "data", 4)) {
      if (!haveFmt) return fail("Hiányzó fmt blokk");
      if (out.channels <= 0) return fail("Érvénytelen csatornaszám");
      if (fmtTag != 1 && fmtTag != 3) return fail("Csak PCM és float WAV támogatott");
      const int bps = out.bitsPerSample / 8;
      const size_t n = avail / bps;
      out.pcm.resize(n);
      for (size_t i = 0; i < n; ++i) {
        const uint8_t* s = body + i * bps;
        if (out.isFloat && bps == 4) { float v; std::memcpy(&v, s, 4); out.pcm[i] = v; }
        else if (bps == 2) out.pcm[i] = int16_t(rd16(s)) / 32768.0f;
        else if (bps == 3) { int32_t v = int32_t(uint32_t(s[0]) << 8 | uint32_t(s[1]) << 16 | uint32_t(s[2]) << 24) >> 8; out.pcm[i] = v / 8388608.0f; }
        else if (bps == 4) out.pcm[i] = float(int32_t(rd32(s)) / 2147483648.0);
        else return fail("Nem támogatott bitmélység");
      }
      return true;
    }
    pos += 8 + size + (size & 1);                    // páratlan blokk: kitöltő bájt
  }
  return fail("Hiányzó data blokk");
}

bool writeWav(const std::string& path, const WavData& w, std::string* err) {
  std::ofstream f(std::filesystem::u8path(path), std::ios::binary);
  if (!f) { if (err) *err = "A kimeneti fájl nem írható"; return false; }
  const int bps = w.bitsPerSample / 8;
  const uint32_t dataSize = uint32_t(w.pcm.size() * bps);
  auto w32 = [&](uint32_t v) { const uint8_t x[4] = {uint8_t(v), uint8_t(v >> 8), uint8_t(v >> 16), uint8_t(v >> 24)}; f.write((const char*)x, 4); };
  auto w16 = [&](uint16_t v) { const uint8_t x[2] = {uint8_t(v), uint8_t(v >> 8)}; f.write((const char*)x, 2); };
  f.write("RIFF", 4); w32(36 + dataSize); f.write("WAVE", 4);
  f.write("fmt ", 4); w32(16); w16(w.isFloat ? 3 : 1); w16(uint16_t(w.channels));
  w32(uint32_t(w.sampleRate)); w32(uint32_t(w.sampleRate * w.channels * bps));
  w16(uint16_t(w.channels * bps)); w16(uint16_t(w.bitsPerSample));
  f.write("data", 4); w32(dataSize);
  for (float v : w.pcm) {
    const float c = std::clamp(v, -1.0f, 1.0f);
    if (w.isFloat) { f.write((const char*)&v, 4); }
    else if (bps == 2) w16(uint16_t(int16_t(std::lround(c * 32767.0f))));
    else if (bps == 3) { const int32_t s = int32_t(std::lround(c * 8388607.0)); const uint8_t x[3] = {uint8_t(s), uint8_t(s >> 8), uint8_t(s >> 16)}; f.write((const char*)x, 3); }
    else w32(uint32_t(int32_t(std::lround(c * 2147483647.0))));
  }
  return bool(f);
}

} // namespace als
