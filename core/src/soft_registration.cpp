// core/src/soft_registration.cpp — 2. modul: Soft Registration hívása
#include "als/soft_registration.hpp"

namespace als {
using namespace yamaha;

// Megj.: a stílus kiválasztása MIDI-n csak ott lehetséges, ahol a profil
// natív regisztráció-hívást jelez; egyébként a stílus a hangszer
// regisztrációjából jön, az app a többit küldi.
void recall(const SoftRegistration& r, const ModelProfile& p, MidiTransport& out) {
  Bytes pkt;
  auto add = [&](const Bytes& b) { pkt.insert(pkt.end(), b.begin(), b.end()); };

  add(tempo(r.bpm));
  for (const auto& s : r.slots) {
    if (!s.enabled) continue;
    add(voiceSelect(s.channel, s.voice));
    add(cc(s.channel, 7,  s.volume));
    add(cc(s.channel, 10, s.pan));
    add(cc(s.channel, 91, s.reverb));
    add(cc(s.channel, 93, s.chorus));
  }
  if (r.startSection && p.supportsSectionSysex)
    add(sectionSelect(*r.startSection));

  // 300 µs szünet az üzenetek között, hogy a hangszer bemeneti puffere ne teljen be
  out.sendBurst(pkt, /*interMessageGapUs=*/300);
}

} // namespace als
