// core/src/rtmidi_transport.cpp — valódi USB-MIDI kapcsolat RtMidi-vel
// Csak akkor fordul, ha a CMake ALS_WITH_RTMIDI=ON (alapértelmezett).
#ifdef ALS_WITH_RTMIDI
#include "als/midi_transport.hpp"

#include <RtMidi.h>
#include <stdexcept>

namespace als {

PortList listRtMidiPorts() {
  PortList p;
  RtMidiIn in;
  for (unsigned i = 0; i < in.getPortCount(); ++i) p.inputs.push_back(in.getPortName(i));
  RtMidiOut out;
  for (unsigned i = 0; i < out.getPortCount(); ++i) p.outputs.push_back(out.getPortName(i));
  return p;
}

namespace {
class RtMidiTransport final : public MidiTransport {
public:
  RtMidiTransport(int inPort, int outPort) {
    out_.openPort(unsigned(outPort));
    if (inPort >= 0) {
      in_.openPort(unsigned(inPort));
      // SysEx, MIDI Clock és Active Sensing is jöjjön be (a Smart Readernek kell a Clock)
      in_.ignoreTypes(/*sysex=*/false, /*timing=*/false, /*sense=*/true);
      in_.setCallback(&RtMidiTransport::onIn, this);
    }
  }
  ~RtMidiTransport() override {
    if (in_.isPortOpen()) { in_.cancelCallback(); in_.closePort(); }
    if (out_.isPortOpen()) out_.closePort();
  }
  void send(const uint8_t* m, size_t n, uint64_t) override {
    out_.sendMessage(m, n);
  }

private:
  static void onIn(double /*deltaSec*/, std::vector<unsigned char>* msg, void* self) {
    if (!msg || msg->empty()) return;
    static_cast<RtMidiTransport*>(self)->deliver(msg->data(), msg->size(), nowUs());
  }
  RtMidiIn in_;
  RtMidiOut out_;
};
} // namespace

std::unique_ptr<MidiTransport> makeRtMidiTransport(int inPort, int outPort) {
  return std::make_unique<RtMidiTransport>(inPort, outPort);
}

} // namespace als
#endif
