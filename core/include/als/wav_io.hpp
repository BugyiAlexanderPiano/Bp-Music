// core/include/als/wav_io.hpp — egyszerű WAV olvasó/író a sample-vágóhoz
// Támogatott: PCM 16/24/32 bit egész és 32 bit float, WAVE_FORMAT_EXTENSIBLE is.
#pragma once
#include <string>
#include <vector>

namespace als {

struct WavData {
  int channels = 0;
  int sampleRate = 0;
  int bitsPerSample = 16;
  bool isFloat = false;
  std::vector<float> pcm;   // interleaved, [-1, 1]
};

bool readWav(const std::string& path, WavData& out, std::string* error = nullptr);
bool writeWav(const std::string& path, const WavData& in, std::string* error = nullptr);

} // namespace als
