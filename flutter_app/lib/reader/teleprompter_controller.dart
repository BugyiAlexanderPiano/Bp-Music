// flutter_app/lib/reader/teleprompter_controller.dart — 6. modul: BPM-szinkron Smart Reader
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Ütemszám → függőleges pozíció (px) a kottán vagy a szövegen.
class Anchor {
  const Anchor(this.bar, this.y);
  final double bar;
  final double y;
}

enum ClockSource { midi, internal }

class TeleprompterController extends ChangeNotifier {
  TeleprompterController(this.anchors,
      {this.beatsPerBar = 4, this.lookAheadBars = 1.0, double bpm = 120})
      : _bpm = bpm;

  final List<Anchor> anchors; // ütem szerint rendezve
  final int beatsPerBar;
  final double lookAheadBars;

  double _bpm;
  double _bar = 0;            // aktuális pozíció ütemben
  bool _running = false;
  ClockSource _source = ClockSource.internal;
  int _ticks = 0;
  int? _lastTickUs;
  double _y = 0, _v = 0;      // megjelenített pozíció és sebesség

  double get scrollY => _y;
  double get bpm => _bpm;

  /// MIDI real-time üzenetek a hangszerről (F8 Clock, FA Start, FC Stop).
  void onMidiRealtime(int status, int timestampUs) {
    switch (status) {
      case 0xFA:
        _ticks = 0; _bar = 0; _running = true; _source = ClockSource.midi;
      case 0xFC:
        _running = false;
      case 0xF8:
        if (_lastTickUs != null) {
          final dt = (timestampUs - _lastTickUs!) / 1e6;
          if (dt > 0) _bpm = _bpm * 0.92 + (60.0 / (dt * 24)) * 0.08; // jitter-szűrés
        }
        _lastTickUs = timestampUs;
        _source = ClockSource.midi;
        if (_running) { _ticks++; _bar = _ticks / (24.0 * beatsPerBar); }
    }
  }

  void startInternal() { _source = ClockSource.internal; _running = true; }
  void setBpm(double bpm) => _bpm = bpm;
  void seekToBar(double bar) { _bar = bar; _ticks = (bar * 24 * beatsPerBar).round(); }

  /// Minden képkockánál hívva (Ticker), dt másodpercben.
  /// nowUs ugyanabból az órából jöjjön, mint a MIDI időbélyeg: AlsCore.nowUs().
  void tick(double dt, int nowUs) {
    final clockLost = _lastTickUs == null || nowUs - _lastTickUs! > 250000;
    if (_running && (_source == ClockSource.internal || clockLost)) {
      _bar += dt * _bpm / 60.0 / beatsPerBar;       // belső óra / tartalék
    }
    final target = _yForBar(_bar + lookAheadBars);
    // Kritikusan csillapított rugó: sima, túlfutás nélküli követés
    const omega = 8.0;
    final a = omega * omega * (target - _y) - 2 * omega * _v;
    _v += a * dt;
    _y += _v * dt;
    notifyListeners();
  }

  double _yForBar(double bar) {
    if (anchors.isEmpty) return 0;
    if (bar <= anchors.first.bar) return anchors.first.y;
    if (bar >= anchors.last.bar) return anchors.last.y;
    var lo = 0, hi = anchors.length - 1;          // bináris keresés
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (anchors[mid].bar <= bar) { lo = mid; } else { hi = mid; }
    }
    final a = anchors[lo], b = anchors[hi];
    final t = (bar - a.bar) / math.max(1e-9, b.bar - a.bar);
    return a.y + (b.y - a.y) * t;
  }
}
