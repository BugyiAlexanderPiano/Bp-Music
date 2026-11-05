// core/include/als/layer_engine.hpp — 3. modul: Virtual Layer Engine
#pragma once
#include "als/midi_transport.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>

namespace als {

struct Zone {
  bool    enabled   = false;
  uint8_t low = 0,  high = 127;         // billentyűtartomány
  uint8_t velLow = 1, velHigh = 127;    // velocity-tartomány
  int8_t  transpose = 0;                // félhang
  float   velCurve  = 1.0f;             // <1 lágyabb, >1 keményebb
  uint8_t outChannel = 8;               // szabad Song-csatorna (0-alapú)
  bool    fwdSustain = true, fwdPitch = true, fwdMod = true;
};

class VirtualLayerEngine {
public:
  static constexpr int kSlots = 4;

  VirtualLayerEngine(MidiTransport& out, uint8_t inChannel)
      : out_(out), inCh_(inChannel) {}

  // UI szálból: előbb elengedi a zóna szóló hangjait, csak aztán cserél
  void setZone(int i, const Zone& z) {
    if (i < 0 || i >= kSlots) return;
    SpinGuard g(lock_);
    releaseAll(i, 0);
    zones_[i] = z;
  }

  // MIDI bemeneti szálból (valós idejű: nincs allokáció, nincs I/O-várakozás)
  void onMidi(const uint8_t* m, size_t n, uint64_t ts) {
    if (n < 2) return;
    const uint8_t st = m[0] & 0xF0, ch = m[0] & 0x0F;
    if (ch != inCh_) return;
    SpinGuard g(lock_);
    if (st == 0x90 && n >= 3 && m[2] > 0)              noteOn(m[1], m[2], ts);
    else if (st == 0x80 || (st == 0x90 && n >= 3))    noteOff(m[1], ts);
    else if (st == 0xB0 || st == 0xE0 || st == 0xD0)  forward(m, n, ts);
  }

private:
  void noteOn(uint8_t note, uint8_t vel, uint64_t ts) {
    for (int i = 0; i < kSlots; ++i) {
      const Zone& z = zones_[i];
      if (!z.enabled || note < z.low || note > z.high ||
          vel < z.velLow || vel > z.velHigh) continue;
      const int outNote = int(note) + z.transpose;
      if (outNote < 0 || outNote > 127) continue;
      const float shaped = std::pow(vel / 127.0f, z.velCurve);
      const uint8_t outVel = uint8_t(std::clamp(int(shaped * 127.0f + 0.5f), 1, 127));
      active_[i][note] = uint8_t(outNote) | 0x80;     // 0x80 = aktív jelző
      const uint8_t msg[3] = {uint8_t(0x90 | z.outChannel), uint8_t(outNote), outVel};
      out_.send(msg, 3, ts);
    }
  }

  void noteOff(uint8_t note, uint64_t ts) {
    for (int i = 0; i < kSlots; ++i) noteOffSlot(i, note, ts);
  }

  void noteOffSlot(int i, int note, uint64_t ts) {
    uint8_t& a = active_[i][note];
    if (!(a & 0x80)) return;                          // ezen a slotton nem szól
    const uint8_t msg[3] = {uint8_t(0x80 | zones_[i].outChannel), uint8_t(a & 0x7F), 0x40};
    out_.send(msg, 3, ts);
    a = 0;
  }

  void forward(const uint8_t* m, size_t n, uint64_t ts) {
    const uint8_t st = m[0] & 0xF0;
    for (const Zone& z : zones_) {
      if (!z.enabled) continue;
      if (st == 0xB0 && m[1] == 64 && !z.fwdSustain) continue;
      if (st == 0xB0 && m[1] == 1  && !z.fwdMod)     continue;
      if (st == 0xE0 && !z.fwdPitch)                 continue;
      const uint8_t msg[3] = {uint8_t(st | z.outChannel), m[1], n > 2 ? m[2] : uint8_t(0)};
      out_.send(msg, std::min<size_t>(n, 3), ts);
    }
  }

  void releaseAll(int i, uint64_t ts) {
    bool any = false;
    for (int note = 0; note < 128; ++note) {
      if (active_[i][note] & 0x80) any = true;
      noteOffSlot(i, note, ts);
    }
    if (any || zones_[i].enabled) {
      const uint8_t sustainOff[3] = {uint8_t(0xB0 | zones_[i].outChannel), 64, 0};
      out_.send(sustainOff, 3, ts);
    }
  }

  struct SpinGuard {
    std::atomic_flag& f;
    explicit SpinGuard(std::atomic_flag& fl) : f(fl) {
      while (f.test_and_set(std::memory_order_acquire)) {}
    }
    ~SpinGuard() { f.clear(std::memory_order_release); }
  };

  MidiTransport& out_;
  uint8_t inCh_;
  std::array<Zone, kSlots> zones_{};
  std::array<std::array<uint8_t, 128>, kSlots> active_{};  // bemeneti hang → kimenő hang
  std::atomic_flag lock_ = ATOMIC_FLAG_INIT;
};

} // namespace als
