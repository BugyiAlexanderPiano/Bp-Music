// core/include/als/midi_transport.hpp
// Közös MIDI-transzport interfész: USB, BLE, RTP-MIDI és a teszt-konzol is ezt valósítja meg.
#pragma once
#include <cstddef>
#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace als {

// Bejövő MIDI üzenet: bájtok, hossz, időbélyeg (µs)
using MidiCallback = std::function<void(const uint8_t*, size_t, uint64_t)>;

class MidiTransport {
public:
  virtual ~MidiTransport() = default;

  // Egyetlen MIDI üzenet küldése (valós idejű szálból is hívható)
  virtual void send(const uint8_t* msg, size_t n, uint64_t ts) = 0;

  // Több egymás utáni üzenet egy bájtfolyamban; üzenetenként bontja és
  // gapUs mikroszekundum szünetet tart közöttük (Soft Registration).
  virtual void sendBurst(const std::vector<uint8_t>& bytes, unsigned gapUs);

  void setInputCallback(MidiCallback cb) { inCb_ = std::move(cb); }

protected:
  // A konkrét transzport ezt hívja minden bejövő üzenetnél
  void deliver(const uint8_t* m, size_t n, uint64_t ts) { if (inCb_) inCb_(m, n, ts); }
  MidiCallback inCb_;
};

// Egy bájtfolyamot önálló MIDI üzenetekre bont (SysEx, csatorna- és rendszerüzenetek)
std::vector<std::vector<uint8_t>> splitMidiStream(const std::vector<uint8_t>& bytes);

// Mikroszekundumos monoton idő
uint64_t nowUs();

// ---- Konkrét transzportok ----

// Tesztelés hangszer nélkül: a kimenő üzeneteket hexában kiírja
std::unique_ptr<MidiTransport> makeConsoleTransport();

#ifdef ALS_WITH_RTMIDI
struct PortList { std::vector<std::string> inputs, outputs; };
PortList listRtMidiPorts();
// USB-MIDI (Windows WinMM, macOS CoreMIDI, Linux ALSA) az RtMidi könyvtáron át
std::unique_ptr<MidiTransport> makeRtMidiTransport(int inPort, int outPort);
#endif

} // namespace als
