// core/include/als/wav_io.hpp — stúdióminőségű WAV olvasó/író
//
// - PCM 16/24/32 bit egész és 32 bit float, WAVE_FORMAT_EXTENSIBLE is
// - Bitpontos: a módosítatlan minták visszaírva bitre azonosak az eredetivel
//   (belül 64 bites lebegőpontos tárolás, szimmetrikus 2^(n-1) skálázás)
// - A többi blokk (pl. bext, LIST metaadatok) változatlanul megmarad
// - Loop pontok: 'smpl' blokk olvasása és írása (Yamaha Expansion Manager, samplerek)
#pragma once
#include <cstdint>
#include <string>
#include <utility>
#include <vector>

namespace als {

struct WavData {
  int channels = 0;
  int sampleRate = 0;
  int bitsPerSample = 16;
  bool isFloat = false;
  std::vector<double> pcm;   // interleaved, [-1, 1)

  // Loop (smpl blokk): -1 = nincs. loopEnd az utolsó lejátszott minta a loopban (inkluzív).
  long long loopStart = -1, loopEnd = -1;
  int unityNote = 60;

  // Ismeretlen blokkok, változatlanul visszaírva
  std::vector<std::pair<std::string, std::vector<uint8_t>>> extraChunks;

  size_t frames() const { return channels > 0 ? pcm.size() / size_t(channels) : 0; }
};

bool readWav(const std::string& path, WavData& out, std::string* error = nullptr);
bool writeWav(const std::string& path, const WavData& in, std::string* error = nullptr);

} // namespace als
