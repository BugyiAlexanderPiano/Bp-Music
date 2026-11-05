// core/include/als/soft_registration.hpp — 2. modul (deklarációk)
#pragma once
#include "als/midi_transport.hpp"
#include "als/yamaha_proto.hpp"

#include <array>
#include <optional>

namespace als {

struct LayerSlot {
  bool enabled = false;
  uint8_t channel = 0;
  yamaha::VoiceRef voice{};
  uint8_t volume = 100, pan = 64, reverb = 40, chorus = 0;
};

struct SoftRegistration {
  double bpm = 120.0;
  std::optional<yamaha::Section> startSection;
  std::array<LayerSlot, 8> slots;  // 0–3 natív (Left, R1, R2, R3), 4–7 virtuális (V1–V4)
};

// Egyetlen időzített csomagban elküldi a teljes beállítást.
void recall(const SoftRegistration& r, const yamaha::ModelProfile& p, MidiTransport& out);

} // namespace als
