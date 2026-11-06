// lib/model/project.dart — az ALS projekt adatmodellje (.alsproj JSON)
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Hangszín-tár: fő csoportok és alkategóriák (GM-példák; a Genos saját bankjait
// a modellprofil adja majd)
// ---------------------------------------------------------------------------
class VoicePreset {
  const VoicePreset(this.name, this.category, this.program, {this.msb = 0, this.lsb = 0});
  final String name, category;
  final int msb, lsb, program;
}

class VoiceGroup {
  const VoiceGroup(this.name, this.icon, this.voices);
  final String name;
  final IconData icon;
  final List<VoicePreset> voices;
}

const voiceGroups = <VoiceGroup>[
  VoiceGroup('Zongora', Icons.piano, [
    VoicePreset('Grand Piano', 'piano', 0), VoicePreset('Bright Piano', 'piano', 1),
    VoicePreset('E. Piano 1', 'piano', 4), VoicePreset('E. Piano 2', 'piano', 5),
    VoicePreset('Harpsichord', 'piano', 6),
  ]),
  VoiceGroup('Orgona, harmonika', Icons.view_week, [
    VoicePreset('Drawbar Organ', 'organ', 16), VoicePreset('Jazz Organ', 'organ', 17),
    VoicePreset('Rock Organ', 'organ', 18), VoicePreset('Church Organ', 'organ', 19),
    VoicePreset('Accordion', 'lead', 21),
  ]),
  VoiceGroup('Gitár', Icons.music_note, [
    VoicePreset('Nylon Guitar', 'lead', 24), VoicePreset('Steel Guitar', 'lead', 25),
    VoicePreset('Jazz Guitar', 'lead', 26), VoicePreset('Clean Guitar', 'lead', 27),
    VoicePreset('Overdrive', 'lead', 29),
  ]),
  VoiceGroup('Basszus', Icons.graphic_eq, [
    VoicePreset('Acoustic Bass', 'bass', 32), VoicePreset('Finger Bass', 'bass', 33),
    VoicePreset('Pick Bass', 'bass', 34), VoicePreset('Fretless', 'bass', 35),
    VoicePreset('Synth Bass', 'bass', 38),
  ]),
  VoiceGroup('Vonósok', Icons.waves, [
    VoicePreset('Strings', 'pad', 48), VoicePreset('Slow Strings', 'pad', 49),
    VoicePreset('Synth Strings', 'pad', 50), VoicePreset('Violin', 'lead', 40),
    VoicePreset('Cello', 'lead', 42),
  ]),
  VoiceGroup('Kórus, pad', Icons.blur_on, [
    VoicePreset('Choir Aahs', 'choir', 52), VoicePreset('Voice Oohs', 'choir', 53),
    VoicePreset('Warm Pad', 'pad', 89), VoicePreset('Polysynth', 'pad', 90),
    VoicePreset('Halo Pad', 'pad', 94),
  ]),
  VoiceGroup('Rézfúvósok', Icons.campaign, [
    VoicePreset('Trumpet', 'lead', 56), VoicePreset('Trombone', 'lead', 57),
    VoicePreset('Brass Section', 'lead', 61), VoicePreset('Synth Brass', 'lead', 62),
  ]),
  VoiceGroup('Fafúvósok', Icons.air, [
    VoicePreset('Alto Sax', 'lead', 65), VoicePreset('Tenor Sax', 'lead', 66),
    VoicePreset('Clarinet', 'lead', 71), VoicePreset('Flute', 'lead', 73),
    VoicePreset('Pan Flute', 'lead', 75),
  ]),
];

// ---------------------------------------------------------------------------
// Virtuális réteg (V1–V4)
// ---------------------------------------------------------------------------
class VSlot {
  VSlot(this.channel);
  int channel; // 0-alapú MIDI csatorna (8 = ch9)
  bool enabled = false;
  String name = '—';
  String category = '';
  int low = 60, high = 96, velLow = 1;
  int transpose = 0;
  double curve = 1.0;
  int msb = 0, lsb = 0, program = 48, volume = 90;

  Map<String, dynamic> toJson() => {
        'channel': channel, 'enabled': enabled, 'name': name, 'category': category,
        'low': low, 'high': high, 'velLow': velLow, 'transpose': transpose, 'curve': curve,
        'msb': msb, 'lsb': lsb, 'program': program, 'volume': volume,
      };

  void loadJson(Map<String, dynamic> j) {
    channel = j['channel'] as int? ?? channel;
    enabled = j['enabled'] as bool? ?? false;
    name = j['name'] as String? ?? '—';
    category = j['category'] as String? ?? '';
    low = j['low'] as int? ?? 60;
    high = j['high'] as int? ?? 96;
    velLow = j['velLow'] as int? ?? 1;
    transpose = j['transpose'] as int? ?? 0;
    curve = (j['curve'] as num? ?? 1.0).toDouble();
    msb = j['msb'] as int? ?? 0;
    lsb = j['lsb'] as int? ?? 0;
    program = j['program'] as int? ?? 0;
    volume = j['volume'] as int? ?? 90;
  }

  void applyPreset(VoicePreset p) {
    name = p.name;
    category = p.category;
    msb = p.msb;
    lsb = p.lsb;
    program = p.program;
    enabled = true;
    autoZone();
  }

  /// Automatikus zóna a hangszín kategóriája alapján
  void autoZone() {
    switch (category) {
      case 'bass':
        low = 28; high = 54; transpose = 0; curve = 1.0; velLow = 1;
      case 'pad':
        low = 55; high = 108; transpose = 0; curve = 0.8; velLow = 1;
      case 'choir':
        low = 55; high = 96; transpose = 0; curve = 1.0; velLow = 90;
      case 'lead':
        low = 60; high = 108; transpose = 0; curve = 1.0; velLow = 1;
      default:
        low = 36; high = 108; transpose = 0; curve = 1.0; velLow = 1;
    }
  }
}

// ---------------------------------------------------------------------------
// Dal
// ---------------------------------------------------------------------------
class Song {
  Song({
    this.title = 'Új dal',
    this.artist = '',
    this.key = 'C',
    this.bpm = 96,
    this.timeSig = '4/4',
    this.style = '',
    this.mainSection = 0x08,
    this.barsPerLine = 2,
    this.transpose = 0,
    this.body = '',
    this.registration,
  });

  String title, artist, key, timeSig, style;
  double bpm;
  int mainSection, barsPerLine, transpose;
  String body;
  /// A dalhoz kötött regisztráció (bank, hely) — a szinkron gomb ezt is behívja
  ({int bank, int slot})? registration;

  Map<String, dynamic> toJson() => {
        'title': title, 'artist': artist, 'key': key, 'bpm': bpm, 'timeSig': timeSig,
        'style': style, 'mainSection': mainSection, 'barsPerLine': barsPerLine,
        'transpose': transpose, 'body': body,
        if (registration != null) 'registration': {'bank': registration!.bank, 'slot': registration!.slot},
      };

  factory Song.fromJson(Map<String, dynamic> j) {
    final r = j['registration'] as Map<String, dynamic>?;
    return Song(
      title: j['title'] as String? ?? 'Új dal',
      artist: j['artist'] as String? ?? '',
      key: j['key'] as String? ?? 'C',
      bpm: (j['bpm'] as num? ?? 96).toDouble(),
      timeSig: j['timeSig'] as String? ?? '4/4',
      style: j['style'] as String? ?? '',
      mainSection: j['mainSection'] as int? ?? 0x08,
      barsPerLine: j['barsPerLine'] as int? ?? 2,
      transpose: j['transpose'] as int? ?? 0,
      body: j['body'] as String? ?? '',
      registration: r == null ? null : (bank: r['bank'] as int, slot: r['slot'] as int),
    );
  }

  Song copy() => Song.fromJson(toJson());

  int get beatsPerBar => int.tryParse(timeSig.split('/').first) ?? 4;
}

// ---------------------------------------------------------------------------
// Megjelenés
// ---------------------------------------------------------------------------
enum BackgroundMode { solid, gradient }

class ThemeSettings {
  BackgroundMode mode = BackgroundMode.gradient;
  List<Color> background = [const Color(0xFF0E1525), const Color(0xFF1B1035)];
  Alignment gradientBegin = Alignment.topLeft;
  Color accent = const Color(0xFF4F8CFF);
  Color panel = const Color(0xFF151B2B);
  double panelOpacity = 0.82;
  double radius = 14;
  // Dalszöveg
  String fontFamily = 'Segoe UI';
  double fontSize = 30;
  Color textColor = const Color(0xFFF2F4F8);
  Color chordColor = const Color(0xFFFFC34D);
  Color sectionColor = const Color(0xFFB79CFF);
  Color highlight = const Color(0xFF4F8CFF);

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'background': [for (final c in background) c.toARGB32()],
        'gradientBegin': [gradientBegin.x, gradientBegin.y],
        'accent': accent.toARGB32(), 'panel': panel.toARGB32(), 'panelOpacity': panelOpacity,
        'radius': radius, 'fontFamily': fontFamily, 'fontSize': fontSize,
        'textColor': textColor.toARGB32(), 'chordColor': chordColor.toARGB32(),
        'sectionColor': sectionColor.toARGB32(), 'highlight': highlight.toARGB32(),
      };

  void loadJson(Map<String, dynamic> j) {
    Color c(String k, Color d) => j[k] is int ? Color(j[k] as int) : d;
    mode = BackgroundMode.values.firstWhere((m) => m.name == j['mode'], orElse: () => mode);
    final bg = j['background'];
    if (bg is List && bg.isNotEmpty) background = [for (final v in bg) Color(v as int)];
    final gb = j['gradientBegin'];
    if (gb is List && gb.length == 2) gradientBegin = Alignment((gb[0] as num).toDouble(), (gb[1] as num).toDouble());
    accent = c('accent', accent);
    panel = c('panel', panel);
    panelOpacity = (j['panelOpacity'] as num? ?? panelOpacity).toDouble();
    radius = (j['radius'] as num? ?? radius).toDouble();
    fontFamily = j['fontFamily'] as String? ?? fontFamily;
    fontSize = (j['fontSize'] as num? ?? fontSize).toDouble();
    textColor = c('textColor', textColor);
    chordColor = c('chordColor', chordColor);
    sectionColor = c('sectionColor', sectionColor);
    highlight = c('highlight', highlight);
  }

  Decoration get backgroundDecoration => mode == BackgroundMode.solid || background.length < 2
      ? BoxDecoration(color: background.first)
      : BoxDecoration(
          gradient: LinearGradient(
            begin: gradientBegin,
            end: Alignment(-gradientBegin.x, -gradientBegin.y),
            colors: background,
          ),
        );
}

class LayoutSettings {
  double leftWidth = 270, rightWidth = 270, bottomHeight = 148;
  bool swapSides = false;
  bool showLeft = true, showRight = true;

  Map<String, dynamic> toJson() => {
        'leftWidth': leftWidth, 'rightWidth': rightWidth, 'bottomHeight': bottomHeight,
        'swapSides': swapSides, 'showLeft': showLeft, 'showRight': showRight,
      };

  void loadJson(Map<String, dynamic> j) {
    leftWidth = (j['leftWidth'] as num? ?? leftWidth).toDouble();
    rightWidth = (j['rightWidth'] as num? ?? rightWidth).toDouble();
    bottomHeight = (j['bottomHeight'] as num? ?? bottomHeight).toDouble();
    swapSides = j['swapSides'] as bool? ?? false;
    showLeft = j['showLeft'] as bool? ?? true;
    showRight = j['showRight'] as bool? ?? true;
  }
}

// ---------------------------------------------------------------------------
// Regisztrációs bank (ALS saját): 8 hely bankonként
// ---------------------------------------------------------------------------
class RegBank {
  RegBank(this.name) : slots = List<Map<String, dynamic>?>.filled(8, null);
  String name;
  final List<Map<String, dynamic>?> slots;

  Map<String, dynamic> toJson() => {'name': name, 'slots': slots};

  factory RegBank.fromJson(Map<String, dynamic> j) {
    final b = RegBank(j['name'] as String? ?? 'Bank');
    final s = j['slots'] as List? ?? const [];
    for (var i = 0; i < 8 && i < s.length; i++) {
      b.slots[i] = s[i] as Map<String, dynamic>?;
    }
    return b;
  }
}

// ---------------------------------------------------------------------------
// Projekt
// ---------------------------------------------------------------------------
class Project {
  Project();

  static const fileExtension = 'alsproj';
  static const formatVersion = 1;

  String name = 'Új projekt';
  final songs = <Song>[];
  final banks = <RegBank>[RegBank('Bank 1')];
  final slots = List<VSlot>.generate(4, (i) => VSlot(8 + i));
  final theme = ThemeSettings();
  final layout = LayoutSettings();

  Map<String, dynamic> toJson() => {
        'format': 'ALS project', 'version': formatVersion, 'name': name,
        'songs': [for (final s in songs) s.toJson()],
        'banks': [for (final b in banks) b.toJson()],
        'slots': [for (final s in slots) s.toJson()],
        'theme': theme.toJson(),
        'layout': layout.toJson(),
      };

  factory Project.fromJson(Map<String, dynamic> j) {
    final p = Project()..name = j['name'] as String? ?? 'Projekt';
    for (final s in j['songs'] as List? ?? const []) {
      p.songs.add(Song.fromJson(s as Map<String, dynamic>));
    }
    final banks = j['banks'] as List? ?? const [];
    if (banks.isNotEmpty) {
      p.banks
        ..clear()
        ..addAll([for (final b in banks) RegBank.fromJson(b as Map<String, dynamic>)]);
    }
    final slots = j['slots'] as List? ?? const [];
    for (var i = 0; i < p.slots.length && i < slots.length; i++) {
      p.slots[i].loadJson(slots[i] as Map<String, dynamic>);
    }
    if (j['theme'] is Map<String, dynamic>) p.theme.loadJson(j['theme'] as Map<String, dynamic>);
    if (j['layout'] is Map<String, dynamic>) p.layout.loadJson(j['layout'] as Map<String, dynamic>);
    return p;
  }

  factory Project.demo() {
    final p = Project()..name = 'Bemutató projekt';
    p.songs.addAll([
      Song(
        title: 'Bemutató dal',
        artist: 'ALS',
        key: 'G',
        bpm: 96,
        style: '8Beat Pop',
        body: '''{Intro} 4 ütem
[G]Ide írd a dal [D]szövegét
[Em]Az akkordok szögletes [C]zárójelbe kerülnek
{Main A}
[G]Első versszak, [D]első sor
[Em]Első versszak, [C]második sor
[G]Első versszak, [D]harmadik sor
[C]Első versszak, [D]negyedik sor
{Main B} refrén
[C]Refrén, első [G]sor
[D]Refrén, második [Em]sor
[C]Refrén, harmadik [G]sor
[D]Refrén, negyedik [G]sor
{Ending}
[G]Vége''',
      ),
      Song(
        title: 'Második dal',
        key: 'Am',
        bpm: 120,
        timeSig: '4/4',
        style: 'Disco',
        mainSection: 0x09,
        body: '''{Main A}
[Am]Lapozz ide jobbra vagy [F]balra húzással
[C]A lakat gombbal az oldal [G]lezárható
{Main B}
[Am]Ez már a második [E]dal''',
      ),
    ]);
    return p;
  }

  // ---- fájlkezelés ----
  String toFileString() => const JsonEncoder.withIndent('  ').convert(toJson());

  static Project fromFileString(String s) => Project.fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// Felhasználói adatmappa (automatikus mentés helye)
  static Directory get appDataDir {
    final env = Platform.environment;
    final String base;
    if (Platform.isWindows) {
      base = '${env['APPDATA'] ?? env['USERPROFILE'] ?? '.'}\\ALS';
    } else if (Platform.isMacOS) {
      base = '${env['HOME'] ?? '.'}/Library/Application Support/ALS';
    } else {
      base = '${env['HOME'] ?? '.'}/.als';
    }
    return Directory(base);
  }

  static File get autosaveFile =>
      File('${appDataDir.path}${Platform.pathSeparator}utolso.$fileExtension');
}
