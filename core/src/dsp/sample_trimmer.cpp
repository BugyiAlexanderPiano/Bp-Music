// core/src/dsp/sample_trimmer.cpp — automatikus, mintapontos sample-vágó
//
// Az elemzés DC-korrigált, egyszerre minden csatornát figyelő jelen fut, de a
// kimenetbe a minták változatlanul kerülnek: csak az elejét és a végét vágja le,
// és (ha kérik) a lecsengés utolsó pár ezredmásodpercére tesz equal-power fade-et.
#include "als/dsp.hpp"

namespace als::dsp {

static constexpr double kPi = 3.14159265358979323846;
static double toLin(double db) { return std::pow(10.0, db / 20.0); }
static double toDb(double a)   { return 20.0 * std::log10(std::max(a, 1e-12)); }

TrimReport trim(std::vector<double>& pcm, int ch, int sr, const TrimParams& p) {
  TrimReport r;
  const size_t frames = ch > 0 ? pcm.size() / size_t(ch) : 0;
  if (frames == 0) { r.silentFile = true; return r; }
  auto at = [&](size_t f, int c) -> double& { return pcm[f * size_t(ch) + size_t(c)]; };

  // DC-eltolás csak az elemzéshez (a kimenet nem változik tőle)
  std::vector<double> dc(size_t(ch), 0.0);
  for (int c = 0; c < ch; ++c) {
    double s = 0; for (size_t f = 0; f < frames; ++f) s += at(f, c);
    dc[size_t(c)] = s / double(frames);
  }
  auto peak = [&](size_t f) { double m = 0; for (int c = 0; c < ch; ++c) m = std::max(m, std::fabs(at(f, c) - dc[size_t(c)])); return m; };
  auto mono = [&](size_t f) { double s = 0; for (int c = 0; c < ch; ++c) s += at(f, c) - dc[size_t(c)]; return s / ch; };

  // Zajpadló: a leghalkabb 50 ms-os ablak RMS-e
  const size_t win = std::max<size_t>(2, size_t(sr * 0.05));
  double floorRms = 1.0;
  if (frames >= win) {
    for (size_t f = 0; f + win <= frames; f += win / 2) {
      double s = 0; for (size_t k = f; k < f + win; ++k) { const double v = peak(k); s += v * v; }
      floorRms = std::min(floorRms, std::sqrt(s / double(win)));
    }
  } else {
    floorRms = 0;
  }
  r.noiseFloorDb = toDb(floorRms);
  const double startThr = std::max(toLin(p.startThreshDb), floorRms * toLin(p.noiseMarginDb));

  // Kezdőpont: első minta a küszöb felett, majd vissza a legközelebbi nullátmenetig
  size_t onset = 0;
  while (onset < frames && peak(onset) < startThr) ++onset;
  if (onset == frames) { r.silentFile = true; return r; }
  size_t start = onset;
  const size_t maxBack = size_t(sr * p.maxZeroSearchMs / 1000.0);
  while (start > 0 && onset - start < maxBack && mono(start - 1) * mono(start) > 0.0) --start;
  if (!p.trimHead) start = 0;
  r.onsetFrame = onset;

  // Végpont: hátulról az utolsó RMS-ablak a lecsengési küszöb felett
  const size_t rw = std::max<size_t>(2, size_t(sr * p.rmsWindowMs / 1000.0));
  const double tailThr = std::max(toLin(p.tailThreshDb), floorRms * toLin(p.noiseMarginDb / 2));
  size_t end = frames;
  if (p.trimTail) {
    while (end > start + rw) {
      double s = 0; for (size_t k = end - rw; k < end; ++k) { const double v = peak(k); s += v * v; }
      if (std::sqrt(s / double(rw)) >= tailThr) break;
      end -= rw / 2;
    }
  }

  // Lecsengés: legalább 2 periódusnyi (nullátmenetekből becsült), equal-power fade
  size_t fade = 0;
  if (p.trimTail && p.fadeTail && end < frames) {
    size_t crossings = 0;
    const size_t probe = std::min(end - start, size_t(sr * 0.05));
    for (size_t f = end - probe + 1; f < end; ++f) if (mono(f - 1) * mono(f) <= 0.0) ++crossings;
    const double periodMs = crossings > 1 ? 2.0 * (double(probe) * 1000.0 / sr) / double(crossings) : p.fadeMaxMs;
    const double fadeMs = std::clamp(2.0 * periodMs, p.fadeMinMs, p.fadeMaxMs);
    fade = std::min(end - start, size_t(sr * fadeMs / 1000.0));
    for (size_t i = 0; i < fade; ++i) {
      const double t = double(i + 1) / double(fade);            // utolsó minta: t = 1 → gain = 0
      const double g = std::cos(t * kPi / 2.0);
      for (int c = 0; c < ch; ++c) at(end - fade + i, c) *= g;
    }
    if (fade) for (int c = 0; c < ch; ++c) at(end - 1, c) = 0.0;  // pontos nulla a végén
    r.fadeMs = double(fade) * 1000.0 / sr;
  }

  // Riport + vágás
  double pk = 0; size_t pkAt = start;
  for (size_t f = start; f < end; ++f) if (peak(f) > pk) { pk = peak(f); pkAt = f; }
  r.startFrame = start; r.endFrame = end; r.peakDb = toDb(pk);
  r.cutHeadMs = double(start) * 1000.0 / sr;
  r.cutTailMs = double(frames - end) * 1000.0 / sr;
  r.needsReview = (p.trimHead && maxBack > 0 && onset - start == maxBack)   // nem talált nullátmenetet
               || double(pkAt - onset) * 1000.0 / sr > 100.0;               // lassú felfutás (pad)
  pcm.erase(pcm.begin() + std::ptrdiff_t(end * size_t(ch)), pcm.end());
  pcm.erase(pcm.begin(), pcm.begin() + std::ptrdiff_t(start * size_t(ch)));
  return r;
}

} // namespace als::dsp
