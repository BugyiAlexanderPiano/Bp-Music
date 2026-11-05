// core/include/als/yamaha_proto.hpp — 1. modul: Yamaha üzenetépítő és modellprofil
// A SysEx-értékeket a véglegesítés előtt minden modell Data List-jével össze kell vetni.
#pragma once
#include <cstdint>
#include <string>
#include <vector>

namespace als::yamaha {

using Bytes = std::vector<uint8_t>;

enum class Section : uint8_t {          // modellprofil felülírhatja
  IntroA = 0x00, IntroB = 0x01, IntroC = 0x02,
  MainA  = 0x08, MainB  = 0x09, MainC  = 0x0A, MainD = 0x0B,
  FillAA = 0x10, FillBB = 0x11, FillCC = 0x12, FillDD = 0x13,
  Break  = 0x18,
  EndingA = 0x20, EndingB = 0x21, EndingC = 0x22
};

struct VoiceRef { uint8_t msb = 0, lsb = 0, program = 0; std::string name; };

struct ModelProfile {                   // később models/<id>.json-ból töltve
  std::string id = "genos2";
  uint8_t nativeParts = 4;              // Left, R1, R2, R3
  uint8_t otsCount = 4;
  uint8_t rightOneTxChannel = 0;        // 0-alapú: 0 = MIDI ch1
  std::vector<uint8_t> nativePartRxChannels{0, 1, 2, 3};
  std::vector<uint8_t> freeSongChannels{8, 9, 10, 11};   // ch9–12
  bool supportsSectionSysex    = true;
  bool supportsNativeRegRecall = false;
};

inline Bytes identityRequest() { return {0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7}; }
inline Bytes styleStart() { return {0xF0, 0x43, 0x60, 0x7A, 0xF7}; }
inline Bytes styleStop()  { return {0xF0, 0x43, 0x60, 0x7D, 0xF7}; }

inline Bytes sectionSelect(Section s, bool on = true) {
  return {0xF0, 0x43, 0x7E, 0x00, static_cast<uint8_t>(s),
          static_cast<uint8_t>(on ? 0x7F : 0x00), 0xF7};
}

// Tempo: mikroszekundum / negyed, 4 × 7 bit, legmagasabb helyiérték elöl
inline Bytes tempo(double bpm) {
  const uint32_t us = static_cast<uint32_t>(60'000'000.0 / bpm + 0.5);
  return {0xF0, 0x43, 0x7E, 0x01,
          uint8_t((us >> 21) & 0x7F), uint8_t((us >> 14) & 0x7F),
          uint8_t((us >> 7) & 0x7F),  uint8_t(us & 0x7F), 0xF7};
}

inline Bytes cc(uint8_t ch, uint8_t num, uint8_t val) {
  return {uint8_t(0xB0 | ch), num, val};
}

inline Bytes voiceSelect(uint8_t ch, const VoiceRef& v) {
  return {uint8_t(0xB0 | ch), 0x00, v.msb,      // Bank MSB
          uint8_t(0xB0 | ch), 0x20, v.lsb,      // Bank LSB
          uint8_t(0xC0 | ch), v.program};       // Program Change
}

} // namespace als::yamaha
