// lib/score/midi_file.dart — Standard MIDI File (SMF 0/1) olvasó és dallam-kivonatoló
import 'dart:typed_data';

import '../model/project.dart';

class MidiEvent {
  MidiEvent(this.tick, this.bytes, {this.track = 0});
  final int tick;
  final List<int> bytes; // teljes üzenet (csatorna- vagy SysEx-üzenet)
  final int track;
}

class MidiTrackInfo {
  MidiTrackInfo(this.index, this.name, this.noteCount, this.channels, this.lowest, this.highest);
  final int index, noteCount, lowest, highest;
  final String name;
  final Set<int> channels;
  String get label => '${index + 1}. sáv${name.isNotEmpty ? ' – $name' : ''} · $noteCount hang'
      '${channels.isNotEmpty ? ' · ch${channels.map((c) => c + 1).join(',')}' : ''}';
}

class MidiFile {
  MidiFile._(this.ticksPerBeat, this.events, this.tempos, this.tracks, this.beatsPerBar);

  final int ticksPerBeat;
  final List<MidiEvent> events;          // időrendben, minden sávból
  final List<(int tick, int usPerBeat)> tempos;
  final List<MidiTrackInfo> tracks;
  final int beatsPerBar;

  double get firstBpm => tempos.isEmpty ? 120 : 60000000 / tempos.first.$2;

  static MidiFile parse(Uint8List b) {
    final bd = ByteData.sublistView(b);
    String id(int o) => String.fromCharCodes(b.sublist(o, o + 4));
    if (b.length < 14 || id(0) != 'MThd') throw const FormatException('Nem MIDI fájl');
    final ntracks = bd.getUint16(10);
    final div = bd.getUint16(12);
    if (div & 0x8000 != 0) throw const FormatException('SMPTE időzítésű MIDI nem támogatott');
    var pos = 8 + bd.getUint32(4);
    final events = <MidiEvent>[];
    final tempos = <(int, int)>[];
    final infos = <MidiTrackInfo>[];
    var beatsPerBar = 4;

    for (var t = 0; t < ntracks && pos + 8 <= b.length; t++) {
      if (id(pos) != 'MTrk') break;
      final len = bd.getUint32(pos + 4);
      var p = pos + 8;
      final end = (p + len).clamp(0, b.length);
      var tick = 0, running = 0, notes = 0, lo = 127, hi = 0;
      var name = '';
      final chans = <int>{};
      int vlq() {
        var v = 0;
        while (p < end) {
          final c = b[p++];
          v = (v << 7) | (c & 0x7F);
          if (c & 0x80 == 0) break;
        }
        return v;
      }

      while (p < end) {
        tick += vlq();
        if (p >= end) break;
        var st = b[p];
        if (st == 0xFF) {
          final type = b[p + 1];
          p += 2;
          final l = vlq();
          final data = b.sublist(p, (p + l).clamp(0, end));
          p += l;
          if (type == 0x51 && data.length == 3) tempos.add((tick, (data[0] << 16) | (data[1] << 8) | data[2]));
          if (type == 0x58 && data.isNotEmpty && tick == 0) beatsPerBar = data[0];
          if (type == 0x03 && name.isEmpty) name = String.fromCharCodes(data.where((c) => c >= 32));
          if (type == 0x2F) break;
          continue;
        }
        if (st == 0xF0 || st == 0xF7) {
          p++;
          final l = vlq();
          final data = b.sublist(p, (p + l).clamp(0, end));
          p += l;
          if (st == 0xF0) events.add(MidiEvent(tick, [0xF0, ...data], track: t));
          continue;
        }
        if (st & 0x80 != 0) {
          running = st;
          p++;
        } else {
          st = running; // running status
        }
        final type = st & 0xF0;
        final n = (type == 0xC0 || type == 0xD0) ? 1 : 2;
        if (p + n > end) break;
        final msg = [st, for (var k = 0; k < n; k++) b[p + k]];
        p += n;
        events.add(MidiEvent(tick, msg, track: t));
        if (type == 0x90 && msg[2] > 0) {
          notes++;
          chans.add(st & 0x0F);
          if (msg[1] < lo) lo = msg[1];
          if (msg[1] > hi) hi = msg[1];
        }
      }
      infos.add(MidiTrackInfo(t, name, notes, chans, notes == 0 ? 0 : lo, hi));
      pos += 8 + len;
    }
    events.sort((a, b) => a.tick.compareTo(b.tick));
    tempos.sort((a, b) => a.$1.compareTo(b.$1));
    return MidiFile._(div, events, tempos, infos, beatsPerBar);
  }

  /// A legvalószínűbb dallamsáv: sok hang, magas fekvés, nem dob (ch10)
  int guessMelodyTrack() {
    var best = 0;
    var bestScore = -1.0;
    for (final t in tracks) {
      if (t.noteCount < 8 || t.channels.contains(9)) continue;
      final score = t.noteCount * 0.2 + (t.lowest + t.highest) / 2;
      if (score > bestScore) {
        bestScore = score;
        best = t.index;
      }
    }
    return best;
  }

  /// Egy szólamú dallam: a választott sáv legfelső hangja, nyolcadokra (vagy tizenhatodokra) igazítva
  List<ScoreNote> melody(int track, {double grid = 0.5}) {
    final on = <int, int>{};
    final raw = <ScoreNote>[];
    for (final e in events) {
      if (e.track != track || e.bytes.length < 3) continue;
      final type = e.bytes[0] & 0xF0;
      final note = e.bytes[1];
      if (type == 0x90 && e.bytes[2] > 0) {
        on[note] = e.tick;
      } else if ((type == 0x80 || type == 0x90) && on.containsKey(note)) {
        final st = on.remove(note)!;
        raw.add(ScoreNote(st / ticksPerBeat, (e.tick - st) / ticksPerBeat, note));
      }
    }
    raw.sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : b.pitch.compareTo(a.pitch));
    // kvantálás + monofonizálás (egy időpontban a legmagasabb hang)
    final out = <ScoreNote>[];
    for (final n in raw) {
      final s = (n.start / grid).round() * grid;
      var d = (n.beats / grid).round() * grid;
      if (d < grid) d = grid;
      if (out.isNotEmpty && (out.last.start - s).abs() < 1e-6) continue; // akkord: a felső hang marad
      if (out.isNotEmpty && out.last.start + out.last.beats > s) out.last.beats = s - out.last.start;
      if (out.isNotEmpty && out.last.beats <= 0) out.removeLast();
      out.add(ScoreNote(s, d, n.pitch));
    }
    return out;
  }
}
