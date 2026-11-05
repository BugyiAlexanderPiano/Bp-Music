// core/src/dsp/style_normalizer.cpp — 5. modul: hangerő-normalizáló
// A LUFS-mérés EBU R128 szerint történik (pl. libebur128, MIT licenc); itt a mért érték bemenet.
#include "als/dsp.hpp"

namespace als::dsp {

NormalizeResult normalizeStyle(std::vector<PartLevel> parts, double measuredLufs,
                               double targetLufs, double maxBoostDb) {
  NormalizeResult r;
  const double wanted = targetLufs - measuredLufs;
  double headroom = INFINITY;                 // a leghangosabb rész meddig emelhető
  for (const auto& p : parts) if (p.cc7 > 0) headroom = std::min(headroom, -cc7ToDb(p.cc7));
  const double delta = std::min({wanted, headroom, maxBoostDb});
  for (auto& p : parts) if (p.cc7 > 0) p.cc7 = dbToCc7(cc7ToDb(p.cc7) + delta);
  r.parts = std::move(parts);
  r.appliedDb = delta;
  r.residualDb = wanted - delta;
  return r;
}

} // namespace als::dsp
