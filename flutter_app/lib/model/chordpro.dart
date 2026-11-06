// lib/model/chordpro.dart — dalszöveg akkordokkal (ChordPro-szerű jelölés)
//
//   [G]Ez egy [D]dalszöveg [Em]sor     → akkordok a szöveg fölött
//   {Main A}                           → szakaszcímke (a hangszer szakaszához)
//   # megjegyzés                       → nem jelenik meg

class ChordSegment {
  const ChordSegment(this.chord, this.text);
  final String? chord;
  final String text;
}

enum LineKind { lyric, section, comment, empty }

class SongLine {
  SongLine(this.kind, this.segments, {this.label = ''});
  final LineKind kind;
  final List<ChordSegment> segments;
  final String label;

  bool get hasChords => segments.any((s) => s.chord != null);
  String get plainText => segments.map((s) => s.text).join();
}

final _chordRe = RegExp(r'\[([^\]]+)\]');

SongLine parseLine(String raw) {
  final line = raw.trimRight();
  final t = line.trimLeft();
  if (t.isEmpty) return SongLine(LineKind.empty, const []);
  if (t.startsWith('#')) return SongLine(LineKind.comment, const []);
  if (t.startsWith('{')) {
    final end = t.indexOf('}');
    final label = end > 0 ? t.substring(1, end) : t.substring(1);
    final rest = end > 0 ? t.substring(end + 1).trim() : '';
    return SongLine(LineKind.section, const [], label: rest.isEmpty ? label : '$label $rest');
  }
  final segs = <ChordSegment>[];
  var pos = 0;
  String? pending;
  for (final m in _chordRe.allMatches(line)) {
    final text = line.substring(pos, m.start);
    if (text.isNotEmpty || pending != null) segs.add(ChordSegment(pending, text));
    pending = m.group(1);
    pos = m.end;
  }
  final tail = line.substring(pos);
  if (tail.isNotEmpty || pending != null) segs.add(ChordSegment(pending, tail.isEmpty ? ' ' : tail));
  return SongLine(LineKind.lyric, segs);
}

/// Szakaszcímke → Yamaha szakaszkód (pl. "Main B" → 0x09); null, ha nem felismerhető.
int? sectionCodeFor(String label) {
  final l = label.toLowerCase().replaceAll(' ', '');
  const map = {
    'introa': 0x00, 'introb': 0x01, 'introc': 0x02, 'intro': 0x00,
    'maina': 0x08, 'mainb': 0x09, 'mainc': 0x0A, 'maind': 0x0B,
    'break': 0x18,
    'endinga': 0x20, 'endingb': 0x21, 'endingc': 0x22, 'ending': 0x20,
  };
  for (final e in map.entries) {
    if (l.startsWith(e.key)) return e.value;
  }
  return null;
}

/// Hangnem transzponálása félhangokkal (pl. "G" +2 → "A")
const _sharps = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
const _flats = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'];

String transposeChord(String chord, int semitones) {
  if (semitones == 0) return chord;
  final m = RegExp(r'^([A-G])([#b]?)(.*)$').firstMatch(chord);
  if (m == null) return chord;
  final root = m.group(1)! + m.group(2)!;
  var idx = _sharps.indexOf(root);
  if (idx < 0) idx = _flats.indexOf(root);
  if (idx < 0) return chord;
  final useFlats = m.group(2) == 'b';
  final n = (idx + semitones) % 12;
  var rest = m.group(3)!;
  // basszushang: "G/B"
  final slash = rest.lastIndexOf('/');
  if (slash >= 0 && slash + 1 < rest.length) {
    rest = '${rest.substring(0, slash)}/${transposeChord(rest.substring(slash + 1), semitones)}';
  }
  return (useFlats ? _flats : _sharps)[n < 0 ? n + 12 : n] + rest;
}
