// core/src/dsp/sample_trimmer.cpp — 4. modul: automatikus WAV sample-vágó
#include "als/dsp.hpp"

namespace als::dsp {

static constexpr double kPi = 3.14159265358979323846;
static double toLin(double db) { return std::pow(10.0, db / 20.0); }
static double toDb(double a)   { return 20.0 * std::log10(std::max(a, 1e-12)); }

TrimReport trim(std::vector<float>& pcm, int ch, int sr, const TrimParams& p) {
  TrimReport r;
  const size_t frames = pcm.size() / ch;
  if (frames == 0) { r.silentFile = true; return r; }
  auto at = [&](size_t f, int c) -> float& { return pcm[f * ch + c]; };

  // 1. DC-eltolás eltávolítása csatornánként
  for (int c = 0; c < ch; ++c) {
    double s = 0; for (size_t f = 0; f < frames; ++f) s += at(f, c);
    const float dc = float(s / frames);
    for (size_t f = 0; f < frames; ++f) at(f, c) -= dc;
  }
  auto peak = [&](size_t f) { float m = 0; for (int c = 0; c < ch; ++c) m = std::max(m, std::fabs(at(f, c))); return m; };
  auto mono = [&](size_t f) { float s = 0; for (int c = 0; c < ch; ++c) s += at(f, c); return s / ch; };

  // 2. Zajpadló: a leghalkabb 50 ms-os ablak RMS-e
  const size_t win = std::max<size_t>(2, size_t(sr * 0.05));
  double floorRms = 1.0;
  for (size_t f = 0; f + win <= frames; f += win / 2) {
    double s = 0; for (size_t k = f; k < f + win; ++k) { const double v = peak(k); s += v * v; }
    floorRms = std::min(floorRms, std::sqrt(s / win));
  }
  const double startThr = std::max(toLin(p.startThreshDb), floorRms * toLin(p.noiseMarginDb));

  // 3. Kezdőpont: első minta a küszöb felett, majd vissza a nullátmenetig
  size_t onset = 0;
  while (onset < frames && peak(onset) < startThr) ++onset;
  if (onset == frames) { r.silentFile = true; return r; }
  size_t start = onset;
  const size_t maxBack = size_t(sr * p.maxZeroSearchMs / 1000.0);
  while (start > 0 && onset - start < maxBack && mono(start - 1) * mono(start) > 0.0f) --start;

  // 4. Végpont: hátulról az utolsó RMS-ablak a lecsengési küszöb felett
  const size_t rw = std::max<size_t>(2, size_t(sr * p.rmsWindowMs / 1000.0));
  const double tailThr = std::max(toLin(p.tailThreshDb), floorRms * toLin(p.noiseMarginDb / 2));
  size_t end = frames;
  while (end > start + rw) {
    double s = 0; for (size_t k = end - rw; k < end; ++k) { const double v = peak(k); s += v * v; }
    if (std::sqrt(s / rw) >= tailThr) break;
    end -= rw / 2;
  }

  // 5. Lecsengés: legalább 2 periódusnyi (nullátmenetekből becsült), equal-power fade
  size_t crossings = 0; const size_t probe = std::min(end - start, size_t(sr * 0.05));
  for (size_t f = end - probe + 1; f < end; ++f) if (mono(f - 1) * mono(f) <= 0.0f) ++crossings;
  const double periodMs = crossings > 1 ? 2.0 * (probe * 1000.0 / sr) / crossings : p.fadeMaxMs;
  const double fadeMs = std::clamp(2.0 * periodMs, p.fadeMinMs, p.fadeMaxMs);
  const size_t fade = std::min(end - start, size_t(sr * fadeMs / 1000.0));
  for (size_t i = 0; i < fade; ++i) {
    const double t = double(i + 1) / fade;                 // utolsó minta: t = 1 → gain = 0
    const float g = float(std::cos(t * kPi / 2.0));
    for (int c = 0; c < ch; ++c) at(end - fade + i, c) *= g;
  }
  if (fade) for (int c = 0; c < ch; ++c) at(end - 1, c) = 0.0f;   // pontos nulla a végén

  // 6. Riport + vágás
  float pk = 0; size_t pkAt = start;
  for (size_t f = start; f < end; ++f) if (peak(f) > pk) { pk = peak(f); pkAt = f; }
  r.startFrame = start; r.endFrame = end; r.peakDb = toDb(pk);
  r.cutHeadMs = start * 1000.0 / sr;
  r.cutTailMs = (frames - end) * 1000.0 / sr;
  r.needsReview = (maxBack > 0 && onset - start == maxBack)   // nem talált nullátmenetet
               || (pkAt - onset) * 1000.0 / sr > 100.0;       // lassú felfutás (pad): kézi ellenőrzés
  pcm.erase(pcm.begin() + end * ch, pcm.end());
  pcm.erase(pcm.begin(), pcm.begin() + start * ch);
  return r;
}

} // namespace als::dsp
