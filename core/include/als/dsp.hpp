// core/include/als/dsp.hpp — 4. és 5. modul deklarációi (sample-vágó, normalizáló)
#pragma once
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace als::dsp {

// ---- 4. modul: automatikus WAV sample-vágó ----
struct TrimParams {
  double startThreshDb = -60.0;  // kezdőpont küszöb
  double tailThreshDb  = -70.0;  // lecsengés küszöb
  double noiseMarginDb = 12.0;   // zajpadló feletti minimum
  double rmsWindowMs   = 10.0;
  double fadeMinMs = 5.0, fadeMaxMs = 20.0;
  double maxZeroSearchMs = 5.0;  // ennyit léphet vissza nullátmenetért
};

struct TrimReport {
  size_t startFrame = 0, endFrame = 0;
  double cutHeadMs = 0, cutTailMs = 0, peakDb = -INFINITY;
  bool silentFile = false, needsReview = false;
};

// pcm: interleaved float [-1, 1]; helyben vág
TrimReport trim(std::vector<float>& pcm, int ch, int sr, const TrimParams& p = {});

// ---- 5. modul: hangerő-normalizáló ----
// GM/XG ajánlás szerinti hangerőgörbe: gain_dB ≈ 40 · log10(CC7 / 127)
inline double cc7ToDb(uint8_t v) { return v == 0 ? -INFINITY : 40.0 * std::log10(v / 127.0); }
inline uint8_t dbToCc7(double db) {
  return uint8_t(std::clamp<long>(std::lround(127.0 * std::pow(10.0, db / 40.0)), 1, 127));
}

struct PartLevel { uint8_t channel; uint8_t cc7; };

struct NormalizeResult {
  std::vector<PartLevel> parts;  // a stílus kezdő beállításába írandó CC7-ek
  double appliedDb = 0;          // ennyit korrigáltunk a részeken
  double residualDb = 0;         // ami nem fért bele: Soft Registration stílushangerőbe
};

// measuredLufs: a stílus Main A–D szakaszainak integrált hangereje (EBU R128)
NormalizeResult normalizeStyle(std::vector<PartLevel> parts, double measuredLufs,
                               double targetLufs = -18.0, double maxBoostDb = 6.0);

} // namespace als::dsp
