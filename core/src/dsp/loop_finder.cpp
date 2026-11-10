// core/src/dsp/loop_finder.cpp — loop-pont kereső kitartott hangmintákhoz
//
// Cél: olyan [S, E) tartomány, amelyet végtelenítve nincs kattanás és nincs
// hallható ugrás. Módszer:
//   1. Burkológörbe (RMS) → a stabil, kitartott szakasz kijelölése
//   2. Jelölt pontok: csak felfelé haladó nullátmenetek (azonos fázis)
//   3. Minden (S, E) párra a varrat körüli ablakok normalizált keresztkorrelációja
//      (a jel E után ugyanúgy folytatódik, mint S után) + hangerő-egyezés
//   4. A legjobb pár; opcionálisan equal-power crossfade a loop vége előtt
#include "als/dsp.hpp"

namespace als::dsp {

static constexpr double kPi = 3.14159265358979323846;

LoopReport findLoop(std::vector<double>& pcm, int ch, int sr, const LoopParams& p) {
  LoopReport r;
  const size_t frames = ch > 0 ? pcm.size() / size_t(ch) : 0;
  if (frames < size_t(sr) / 4) return r;
  auto at = [&](size_t f, int c) -> double& { return pcm[f * size_t(ch) + size_t(c)]; };

  // Mono elemző jel (DC nélkül)
  std::vector<double> x(frames);
  double dcSum = 0;
  for (size_t f = 0; f < frames; ++f) {
    double s = 0; for (int c = 0; c < ch; ++c) s += at(f, c);
    x[f] = s / ch; dcSum += x[f];
  }
  const double dc = dcSum / double(frames);
  for (auto& v : x) v -= dc;

  // 1. Burkológörbe 10 ms-os ablakokkal; stabil szakasz = a csúcs utáni rész,
  //    ahol a szint a medián ±6 dB-én belül marad
  const size_t hop = std::max<size_t>(1, size_t(sr / 100));
  std::vector<double> env;
  for (size_t f = 0; f + hop <= frames; f += hop) {
    double s = 0; for (size_t k = f; k < f + hop; ++k) s += x[k] * x[k];
    env.push_back(std::sqrt(s / double(hop)));
  }
  if (env.size() < 10) return r;
  const size_t peakIdx = size_t(std::max_element(env.begin(), env.end()) - env.begin());
  std::vector<double> tail(env.begin() + std::ptrdiff_t(peakIdx), env.end());
  std::nth_element(tail.begin(), tail.begin() + std::ptrdiff_t(tail.size() / 2), tail.end());
  const double med = tail[tail.size() / 2];
  size_t stableEnd = env.size() - 1;
  while (stableEnd > peakIdx && env[stableEnd] < med * 0.5) --stableEnd;   // a lecsengés (release) kihagyása

  size_t lo = std::max(size_t(double(frames) * p.searchStartPct), (peakIdx + 2) * hop);
  size_t hi = std::min(size_t(double(frames) * p.searchEndPct), stableEnd * hop);
  const size_t W = std::max<size_t>(64, size_t(sr * p.windowMs / 1000.0));
  const size_t minLen = size_t(sr * p.minLoopMs / 1000.0);
  if (hi <= lo + minLen || hi + W >= frames || lo < W) {
    // rövid minta: a feltételek lazítása
    lo = std::max<size_t>(W, frames / 5);
    hi = frames > W * 2 ? frames - W * 2 : 0;
    if (hi <= lo + minLen / 2) return r;
  }

  // 2. Felfelé haladó nullátmenetek
  std::vector<size_t> zc;
  for (size_t f = lo; f < hi; ++f) if (x[f - 1] < 0.0 && x[f] >= 0.0) zc.push_back(f);
  if (zc.size() < 4) return r;

  // Ablak-energiák előre számolva (a korreláció normalizálásához)
  auto energy = [&](size_t c) { double s = 0; for (size_t k = c - W / 2; k < c + W / 2; ++k) s += x[k] * x[k]; return s; };

  // Vég-jelöltek: a tartomány utolsó harmadából legfeljebb 40 nullátmenet
  std::vector<size_t> ends;
  const size_t endFrom = zc.size() * 2 / 3;
  const size_t endStep = std::max<size_t>(1, (zc.size() - endFrom) / 40);
  for (size_t i = endFrom; i < zc.size(); i += endStep) ends.push_back(zc[i]);
  // Kezdő-jelöltek: legfeljebb 1500 nullátmenet egyenletesen
  const size_t startStep = std::max<size_t>(1, zc.size() / 1500);

  double best = -2; size_t bs = 0, be = 0; double bestLevel = 0;
  for (size_t e : ends) {
    const double ee = energy(e);
    if (ee <= 0) continue;
    for (size_t i = 0; i < zc.size(); i += startStep) {
      const size_t s = zc[i];
      if (s + minLen > e) break;
      double xy = 0;
      for (size_t k = 0; k < W; ++k) xy += x[s - W / 2 + k] * x[e - W / 2 + k];
      const double es = energy(s);
      if (es <= 0) continue;
      const double ncc = xy / std::sqrt(es * ee);
      const double levelDiffDb = 10.0 * std::log10(es / ee);
      const double score = ncc - 0.02 * std::fabs(levelDiffDb);   // hangerő-ugrás büntetése
      if (score > best) { best = score; bs = s; be = e; bestLevel = levelDiffDb; }
    }
  }
  if (best < -1) return r;

  // Finomítás: a legjobb pár körül ±minden nullátmenet (a ritkított keresés után)
  for (size_t s : zc) {
    if (s + W < bs || s > bs + W || s + minLen > be) continue;
    double xy = 0, es = 0, ee = 0;
    for (size_t k = 0; k < W; ++k) {
      const double a = x[s - W / 2 + k], b = x[be - W / 2 + k];
      xy += a * b; es += a * a; ee += b * b;
    }
    if (es <= 0 || ee <= 0) continue;
    const double score = xy / std::sqrt(es * ee) - 0.02 * std::fabs(10.0 * std::log10(es / ee));
    if (score > best) { best = score; bs = s; bestLevel = 10.0 * std::log10(es / ee); }
  }

  // 4. Opcionális crossfade: a loop vége előtti CF minta átkeverése a loop eleje előttivel
  size_t cf = size_t(sr * p.crossfadeMs / 1000.0);
  cf = std::min({cf, bs, (be - bs) / 2});
  for (size_t i = 0; i < cf; ++i) {
    const double t = double(i + 1) / double(cf + 1);
    const double gOut = std::cos(t * kPi / 2.0), gIn = std::sin(t * kPi / 2.0);
    for (int c = 0; c < ch; ++c) {
      const size_t dst = be - cf + i, src = bs - cf + i;
      at(dst, c) = at(dst, c) * gOut + at(src, c) * gIn;
    }
  }

  r.found = true;
  r.loopStart = (long long)bs;
  r.loopEnd = (long long)be - 1;          // be minta ≈ bs minta → az utolsó lejátszott: be-1
  r.score = std::clamp(best, 0.0, 1.0);
  r.levelDiffDb = bestLevel;
  r.lengthMs = double(be - bs) * 1000.0 / sr;
  r.crossfadeMs = double(cf) * 1000.0 / sr;
  return r;
}

} // namespace als::dsp
