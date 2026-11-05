// core/src/midi_transport.cpp
#include "als/midi_transport.hpp"

#include <chrono>
#include <cstdio>
#include <thread>

namespace als {

uint64_t nowUs() {
  using namespace std::chrono;
  return uint64_t(duration_cast<microseconds>(steady_clock::now().time_since_epoch()).count());
}

static size_t messageLength(uint8_t status) {
  if (status >= 0xF8) return 1;                       // real-time (Clock, Start, Stop…)
  switch (status & 0xF0) {
    case 0x80: case 0x90: case 0xA0: case 0xB0: case 0xE0: return 3;
    case 0xC0: case 0xD0: return 2;
  }
  switch (status) {
    case 0xF1: case 0xF3: return 2;
    case 0xF2: return 3;
    default:   return 1;                              // F6, F7 stb.
  }
}

std::vector<std::vector<uint8_t>> splitMidiStream(const std::vector<uint8_t>& b) {
  std::vector<std::vector<uint8_t>> out;
  size_t i = 0;
  while (i < b.size()) {
    if (b[i] == 0xF0) {                               // SysEx: F0 … F7
      size_t j = i + 1;
      while (j < b.size() && b[j] != 0xF7) ++j;
      const size_t end = (j < b.size()) ? j + 1 : j;
      out.emplace_back(b.begin() + i, b.begin() + end);
      i = end;
    } else if (b[i] & 0x80) {
      const size_t len = messageLength(b[i]);
      const size_t end = std::min(b.size(), i + len);
      out.emplace_back(b.begin() + i, b.begin() + end);
      i = end;
    } else {
      ++i;                                            // running status nem használt: kihagyjuk
    }
  }
  return out;
}

void MidiTransport::sendBurst(const std::vector<uint8_t>& bytes, unsigned gapUs) {
  for (const auto& m : splitMidiStream(bytes)) {
    send(m.data(), m.size(), nowUs());
    if (gapUs) std::this_thread::sleep_for(std::chrono::microseconds(gapUs));
  }
}

// ---- Konzol transzport (hangszer nélküli teszt) ----
namespace {
class ConsoleTransport final : public MidiTransport {
public:
  void send(const uint8_t* m, size_t n, uint64_t) override {
    std::printf("  MIDI OUT:");
    for (size_t i = 0; i < n; ++i) std::printf(" %02X", m[i]);
    std::printf("\n");
  }
  void sendBurst(const std::vector<uint8_t>& bytes, unsigned) override {
    MidiTransport::sendBurst(bytes, 0);               // konzolon nincs szükség szünetre
  }
};
} // namespace

std::unique_ptr<MidiTransport> makeConsoleTransport() { return std::make_unique<ConsoleTransport>(); }

} // namespace als
