// lib/score/midi_player.dart — MIDI dal lejátszása a hangszeren (PC és tablet)
import 'dart:async';
import 'dart:convert';

import '../midi/midi_backend.dart';
import '../model/project.dart';
import 'midi_file.dart';

class MidiPlayer {
  MidiPlayer(this.midi);
  final MidiBackend midi;

  Timer? _timer;
  final _sw = Stopwatch();
  List<(int us, List<int> bytes)> _schedule = const [];
  int _next = 0;
  final _sounding = <int>{}; // (csatorna << 8 | hang) — leálláskor elengedjük
  void Function()? onFinished;

  bool get playing => _timer != null;
  double get positionSeconds => _sw.elapsedMicroseconds / 1e6;

  /// Időzítés előkészítése: tick → mikroszekundum a tempótérkép szerint
  static List<(int, List<int>)> buildSchedule(MidiFile f, {Set<int>? onlyTracks, double tempoScale = 1.0}) {
    final out = <(int, List<int>)>[];
    var tempoIdx = 0, lastTick = 0, usPerBeat = 500000;
    var us = 0.0;
    for (final e in f.events) {
      while (tempoIdx < f.tempos.length && f.tempos[tempoIdx].$1 <= e.tick) {
        us += (f.tempos[tempoIdx].$1 - lastTick) * usPerBeat / f.ticksPerBeat;
        lastTick = f.tempos[tempoIdx].$1;
        usPerBeat = f.tempos[tempoIdx].$2;
        tempoIdx++;
      }
      us += (e.tick - lastTick) * usPerBeat / f.ticksPerBeat;
      lastTick = e.tick;
      if (onlyTracks != null && !onlyTracks.contains(e.track)) continue;
      out.add(((us / tempoScale).round(), e.bytes));
    }
    return out;
  }

  /// A dalhoz csatolt kotta MIDI-jének lejátszása. melodyOnly: csak a dallamsáv.
  bool play(SongScore score, {bool melodyOnly = false, double? targetBpm}) {
    stop();
    final b64 = score.midiB64;
    if (b64 == null) return false;
    final f = MidiFile.parse(base64Decode(b64));
    final scale = targetBpm == null ? 1.0 : targetBpm / f.firstBpm;
    _schedule = buildSchedule(f, onlyTracks: melodyOnly ? {score.melodyTrack} : null, tempoScale: scale);
    _next = 0;
    _sw
      ..reset()
      ..start();
    _timer = Timer.periodic(const Duration(milliseconds: 2), (_) => _pump());
    return true;
  }

  void _pump() {
    final now = _sw.elapsedMicroseconds;
    while (_next < _schedule.length && _schedule[_next].$1 <= now) {
      final m = _schedule[_next].$2;
      midi.sendRaw(m);
      if (m.length >= 3) {
        final type = m[0] & 0xF0, key = ((m[0] & 0x0F) << 8) | m[1];
        if (type == 0x90 && m[2] > 0) {
          _sounding.add(key);
        } else if (type == 0x80 || type == 0x90) {
          _sounding.remove(key);
        }
      }
      _next++;
    }
    if (_next >= _schedule.length) {
      stop();
      onFinished?.call();
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _sw.stop();
    for (final k in _sounding) {
      midi.sendRaw([0x80 | (k >> 8), k & 0xFF, 0]);
    }
    _sounding.clear();
  }
}
