// core/include/als/dsp.hpp — sample-vágó, loop-pont kereső, hangerő-normalizáló
#pragma once
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace als::dsp {

// ---- Sample-vágó ----
// Stúdióminőség: a megmaradó minták bitre változatlanok; csak a lecsengés
// utolsó néhány ezredmásodperce kap fade-et (és az is kikapcsolható).
struct TrimParams {
  double startThreshDb = -60.0;  // kezdőpont küszöb
  double tailThreshDb  = -70.0;  // lecsengés küszöb
  double noiseMarginDb = 12.0;   // zajpadló feletti minimum
  double rmsWindowMs   = 10.0;
  double fadeMinMs = 5.0, fadeMaxMs = 20.0;
  double maxZeroSearchMs = 5.0;  // ennyit léphet vissza nullátmenetért
  bool trimHead = true, trimTail = true, fadeTail = true;
};

struct TrimReport {
  size_t startFrame = 0, endFrame = 0, onsetFrame = 0;
  double cutHeadMs = 0, cutTailMs = 0, peakDb = -INFINITY, noiseFloorDb = -INFINITY, fadeMs = 0;
  bool silentFile = false, needsReview = false;
};

// pcm: interleaved [-1, 1); helyben vág
TrimReport trim(std::vector<double>& pcm, int ch, int sr, const TrimParams& p = {});

// ---- Loop-pont kereső (kitartott hangmintákhoz) ----
struct LoopParams {
  double minLoopMs = 400.0;       // legrövidebb elfogadható loop
  double crossfadeMs = 0.0;       // 0 = nincs crossfade (a minták érintetlenek)
  double windowMs = 25.0;         // összehasonlító ablak a varrat körül
  double searchStartPct = 0.25;   // a keresés a hang ennyiedénél kezdődhet legkorábban
  double searchEndPct = 0.92;     // és a loop vége legfeljebb itt lehet
};

struct LoopReport {
  bool found = false;
  long long loopStart = -1, loopEnd = -1;  // loopEnd inkluzív (smpl szabvány)
  double score = 0;                        // 0–1: a varrat hasonlósága (1 = tökéletes)
  double levelDiffDb = 0;                  // hangerő-eltérés a loop két vége között
  double lengthMs = 0, crossfadeMs = 0;
};

// pcm: interleaved; ha crossfadeMs > 0, a loop vége előtti részt helyben átkeveri
LoopReport findLoop(std::vector<double>& pcm, int ch, int sr, const LoopParams& p = {});

// ---- Hangerő-normalizáló ----
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
