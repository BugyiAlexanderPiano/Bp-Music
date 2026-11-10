// lib/model/project.dart — a SoundNexus Pro projekt adatmodellje (.snxproj JSON)
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Hangszín-tár: fő csoportok és alkategóriák (GM-példák; a Genos saját bankjait
// a modellprofil adja majd)
// ---------------------------------------------------------------------------
const groupIcons = <String, IconData>{
  'piano': Icons.piano, 'organ': Icons.view_week, 'guitar': Icons.music_note, 'bass': Icons.graphic_eq,
  'strings': Icons.waves, 'choir': Icons.blur_on, 'brass': Icons.campaign, 'wind': Icons.air,
  'drums': Icons.album, 'synth': Icons.tune, 'mic': Icons.mic, 'star': Icons.star, 'folder': Icons.folder,
};

class VoicePreset {
  VoicePreset(this.name, this.category, this.program, {this.msb = 0, this.lsb = 0});
  String name, category;
  int msb, lsb, program;

  Map<String, dynamic> toJson() => {'name': name, 'category': category, 'program': program, 'msb': msb, 'lsb': lsb};
  factory VoicePreset.fromJson(Map<String, dynamic> j) => VoicePreset(
        j['name'] as String? ?? 'Hangszín',
        j['category'] as String? ?? '',
        j['program'] as int? ?? 0,
        msb: j['msb'] as int? ?? 0,
        lsb: j['lsb'] as int? ?? 0,
      );
}

class VoiceGroup {
  VoiceGroup(this.name, this.iconKey, this.voices);
  String name, iconKey;
  final List<VoicePreset> voices;
  IconData get icon => groupIcons[iconKey] ?? Icons.folder;

  Map<String, dynamic> toJson() => {'name': name, 'icon': iconKey, 'voices': [for (final v in voices) v.toJson()]};
  factory VoiceGroup.fromJson(Map<String, dynamic> j) => VoiceGroup(
        j['name'] as String? ?? 'Csoport',
        j['icon'] as String? ?? 'folder',
        [for (final v in j['voices'] as List? ?? const []) VoicePreset.fromJson(v as Map<String, dynamic>)],
      );
}

/// Alap hangszín-tár (GM-példák; a Genos saját bankjai a szerkesztőben felvehetők)
List<VoiceGroup> defaultVoiceGroups() => [
      VoiceGroup('Zongora', 'piano', [
        VoicePreset('Grand Piano', 'piano', 0), VoicePreset('Bright Piano', 'piano', 1),
        VoicePreset('E. Piano 1', 'piano', 4), VoicePreset('E. Piano 2', 'piano', 5),
        VoicePreset('Harpsichord', 'piano', 6),
      ]),
      VoiceGroup('Orgona', 'organ', [
        VoicePreset('Drawbar Organ', 'organ', 16), VoicePreset('Jazz Organ', 'organ', 17),
        VoicePreset('Rock Organ', 'organ', 18), VoicePreset('Church Organ', 'organ', 19),
        VoicePreset('Accordion', 'lead', 21),
      ]),
      VoiceGroup('Gitár', 'guitar', [
        VoicePreset('Nylon Guitar', 'lead', 24), VoicePreset('Steel Guitar', 'lead', 25),
        VoicePreset('Jazz Guitar', 'lead', 26), VoicePreset('Clean Guitar', 'lead', 27),
        VoicePreset('Overdrive', 'lead', 29),
      ]),
      VoiceGroup('Basszus', 'bass', [
        VoicePreset('Acoustic Bass', 'bass', 32), VoicePreset('Finger Bass', 'bass', 33),
        VoicePreset('Pick Bass', 'bass', 34), VoicePreset('Fretless', 'bass', 35),
        VoicePreset('Synth Bass', 'bass', 38),
      ]),
      VoiceGroup('Vonósok', 'strings', [
        VoicePreset('Strings', 'pad', 48), VoicePreset('Slow Strings', 'pad', 49),
        VoicePreset('Synth Strings', 'pad', 50), VoicePreset('Violin', 'lead', 40),
        VoicePreset('Cello', 'lead', 42),
      ]),
      VoiceGroup('Kórus, pad', 'choir', [
        VoicePreset('Choir Aahs', 'choir', 52), VoicePreset('Voice Oohs', 'choir', 53),
        VoicePreset('Warm Pad', 'pad', 89), VoicePreset('Polysynth', 'pad', 90),
        VoicePreset('Halo Pad', 'pad', 94),
      ]),
      VoiceGroup('Rézfúvós', 'brass', [
        VoicePreset('Trumpet', 'lead', 56), VoicePreset('Trombone', 'lead', 57),
        VoicePreset('Brass Section', 'lead', 61), VoicePreset('Synth Brass', 'lead', 62),
      ]),
      VoiceGroup('Fafúvós', 'wind', [
        VoicePreset('Alto Sax', 'lead', 65), VoicePreset('Tenor Sax', 'lead', 66),
        VoicePreset('Clarinet', 'lead', 71), VoicePreset('Flute', 'lead', 73),
        VoicePreset('Pan Flute', 'lead', 75),
      ]),
    ];

// ---------------------------------------------------------------------------
// Ritmus-panel gombjai és az alsó sáv moduljai (sorrend = megjelenés)
// ---------------------------------------------------------------------------
const rhythmCatalog = <String, String>{
  'start': 'Start', 'stop': 'Stop',
  'introA': 'Intro A', 'introB': 'Intro B', 'introC': 'Intro C',
  'mainA': 'Main A', 'mainB': 'Main B', 'mainC': 'Main C', 'mainD': 'Main D',
  'fill': 'Fill In', 'break': 'Break',
  'endingA': 'Ending A', 'endingB': 'Ending B', 'endingC': 'Ending C',
  'sync': 'Szinkron', 'tap': 'TAP tempó', 'tempoDown': 'Tempó −', 'tempoUp': 'Tempó +',
  'playScore': 'Dal lejátszása', 'lock': 'Lakat',
};
const defaultRhythmItems = [
  'start', 'stop', 'introA', 'introB', 'introC', 'mainA', 'mainB', 'mainC', 'mainD', 'fill', 'break',
  'endingA', 'endingB', 'endingC',
];

const bottomCatalog = <String, String>{
  'layers': 'Rétegek (V1–V4)', 'ots': 'One Touch Settings', 'tempo': 'Tempó', 'regs': 'Regiszter bankok',
  'startStop': 'Start / Stop', 'mains': 'Main A–D', 'sync': 'Szinkron gomb', 'playScore': 'Dal lejátszása',
  'lock': 'Lakat', 'spacer': 'Térköz',
};
const defaultBottomModules = ['layers', 'ots', 'tempo', 'regs'];

// ---------------------------------------------------------------------------
// Kotta (dallam + akkordok)
// ---------------------------------------------------------------------------
class ScoreNote {
  ScoreNote(this.start, this.beats, this.pitch);
  double start, beats; // negyedekben
  int pitch;
  List<num> toJson() => [start, beats, pitch];
  factory ScoreNote.fromJson(List<dynamic> j) => ScoreNote((j[0] as num).toDouble(), (j[1] as num).toDouble(), j[2] as int);
}

class SongScore {
  SongScore({required this.name, this.midiB64, this.melodyTrack = 0, List<ScoreNote>? notes, this.beatsPerBar = 4, this.bpm})
      : notes = notes ?? [];
  String name;
  String? midiB64;      // a teljes MIDI fájl (lejátszáshoz)
  int melodyTrack;
  final List<ScoreNote> notes;
  int beatsPerBar;
  double? bpm;

  Map<String, dynamic> toJson() => {
        'name': name, 'midi': midiB64, 'melodyTrack': melodyTrack, 'beatsPerBar': beatsPerBar, 'bpm': bpm,
        'notes': [for (final n in notes) n.toJson()],
      };
  factory SongScore.fromJson(Map<String, dynamic> j) => SongScore(
        name: j['name'] as String? ?? 'Kotta',
        midiB64: j['midi'] as String?,
        melodyTrack: j['melodyTrack'] as int? ?? 0,
        beatsPerBar: j['beatsPerBar'] as int? ?? 4,
        bpm: (j['bpm'] as num?)?.toDouble(),
        notes: [for (final n in j['notes'] as List? ?? const []) ScoreNote.fromJson(n as List<dynamic>)],
      );
}

enum ReaderView { text, score, both }



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
    List<SongScore>? scores,
    this.activeScore = 0,
  }) : scores = scores ?? [];

  String title, artist, key, timeSig, style;
  double bpm;
  int mainSection, barsPerLine, transpose;
  String body;
  /// A dalhoz kötött regisztráció (bank, hely) — a szinkron gomb ezt is behívja
  ({int bank, int slot})? registration;
  /// Csatolt kották (a tableten választható, melyik látszik)
  final List<SongScore> scores;
  int activeScore;
  SongScore? get score => scores.isEmpty ? null : scores[activeScore.clamp(0, scores.length - 1)];

  Map<String, dynamic> toJson() => {
        'title': title, 'artist': artist, 'key': key, 'bpm': bpm, 'timeSig': timeSig,
        'style': style, 'mainSection': mainSection, 'barsPerLine': barsPerLine,
        'transpose': transpose, 'body': body,
        if (registration != null) 'registration': {'bank': registration!.bank, 'slot': registration!.slot},
        'scores': [for (final sc in scores) sc.toJson()],
        'activeScore': activeScore,
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
      scores: [for (final sc in j['scores'] as List? ?? const []) SongScore.fromJson(sc as Map<String, dynamic>)],
      activeScore: j['activeScore'] as int? ?? 0,
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
  // Mozgó színátmenet és háttérkép
  bool animate = false;
  double animSeconds = 18;           // egy teljes kör ideje
  bool animateHue = false;           // a színek lassú körbeforgatása is
  String? bgImage;                   // kép azonosító a Project.images-ben
  String bgFit = 'cover';            // cover | contain | tile
  double bgBlur = 0, bgDarken = 0.35, bgOpacity = 1.0;

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'background': [for (final c in background) c.toARGB32()],
        'gradientBegin': [gradientBegin.x, gradientBegin.y],
        'accent': accent.toARGB32(), 'panel': panel.toARGB32(), 'panelOpacity': panelOpacity,
        'radius': radius, 'fontFamily': fontFamily, 'fontSize': fontSize,
        'textColor': textColor.toARGB32(), 'chordColor': chordColor.toARGB32(),
        'sectionColor': sectionColor.toARGB32(), 'highlight': highlight.toARGB32(),
        'animate': animate, 'animSeconds': animSeconds, 'animateHue': animateHue,
        'bgImage': bgImage, 'bgFit': bgFit, 'bgBlur': bgBlur, 'bgDarken': bgDarken, 'bgOpacity': bgOpacity,
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
    animate = j['animate'] as bool? ?? false;
    animSeconds = (j['animSeconds'] as num? ?? animSeconds).toDouble();
    animateHue = j['animateHue'] as bool? ?? false;
    bgImage = j['bgImage'] as String?;
    bgFit = j['bgFit'] as String? ?? 'cover';
    bgBlur = (j['bgBlur'] as num? ?? 0).toDouble();
    bgDarken = (j['bgDarken'] as num? ?? 0.35).toDouble();
    bgOpacity = (j['bgOpacity'] as num? ?? 1.0).toDouble();
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
// Panel- és gombstílusok (csak PC-n szerkeszthető)
// ---------------------------------------------------------------------------
enum ButtonShape { rounded, pill, square, circle }

const buttonShapeNames = {
  ButtonShape.rounded: 'Lekerekített',
  ButtonShape.pill: 'Kapszula',
  ButtonShape.square: 'Szögletes',
  ButtonShape.circle: 'Kör',
};

Color? _c(dynamic v) => v is int ? Color(v) : null;

/// Egy sáv (bal, jobb, alsó, közép) teljes kinézete
class PanelStyle {
  bool useOwn = false;                 // false = a téma panelszínét használja
  List<Color> background = [const Color(0xFF151B2B)];
  double opacity = 0.85;
  double radius = 14;
  Color border = const Color(0x22FFFFFF);
  double borderWidth = 1;
  String? backgroundImage;             // kép azonosító a Project.images-ben
  double imageOpacity = 0.35;
  ButtonShape shape = ButtonShape.pill;
  double buttonScale = 1.0;            // gombok mérete (0.7–1.8)
  Color? buttonColor;                  // null = téma kiemelőszín
  Color? buttonText;
  double fontSize = 14;

  Map<String, dynamic> toJson() => {
        'useOwn': useOwn,
        'background': [for (final c in background) c.toARGB32()],
        'opacity': opacity, 'radius': radius, 'border': border.toARGB32(), 'borderWidth': borderWidth,
        'backgroundImage': backgroundImage, 'imageOpacity': imageOpacity, 'shape': shape.name,
        'buttonScale': buttonScale, 'buttonColor': buttonColor?.toARGB32(), 'buttonText': buttonText?.toARGB32(),
        'fontSize': fontSize,
      };

  void loadJson(Map<String, dynamic> j) {
    useOwn = j['useOwn'] as bool? ?? false;
    final bg = j['background'];
    if (bg is List && bg.isNotEmpty) background = [for (final v in bg) Color(v as int)];
    opacity = (j['opacity'] as num? ?? opacity).toDouble();
    radius = (j['radius'] as num? ?? radius).toDouble();
    border = _c(j['border']) ?? border;
    borderWidth = (j['borderWidth'] as num? ?? borderWidth).toDouble();
    backgroundImage = j['backgroundImage'] as String?;
    imageOpacity = (j['imageOpacity'] as num? ?? imageOpacity).toDouble();
    shape = ButtonShape.values.firstWhere((s) => s.name == j['shape'], orElse: () => shape);
    buttonScale = (j['buttonScale'] as num? ?? buttonScale).toDouble();
    buttonColor = _c(j['buttonColor']);
    buttonText = _c(j['buttonText']);
    fontSize = (j['fontSize'] as num? ?? fontSize).toDouble();
  }
}

/// Egy gomb egyedi kinézete (kép, felirat, szín, méret)
class ItemStyle {
  String? image;      // kép azonosító
  String? label;      // egyedi felirat (null = alapértelmezett)
  Color? color;
  double scale = 1.0;
  bool imageOnly = false; // csak a kép látszik, felirat nélkül

  bool get isEmpty => image == null && label == null && color == null && scale == 1.0 && !imageOnly;

  Map<String, dynamic> toJson() => {
        'image': image, 'label': label, 'color': color?.toARGB32(), 'scale': scale, 'imageOnly': imageOnly,
      };

  static ItemStyle fromJson(Map<String, dynamic> j) => ItemStyle()
    ..image = j['image'] as String?
    ..label = j['label'] as String?
    ..color = _c(j['color'])
    ..scale = (j['scale'] as num? ?? 1.0).toDouble()
    ..imageOnly = j['imageOnly'] as bool? ?? false;
}

const panelKeys = ['left', 'center', 'right', 'bottom'];
const panelNames = {'left': 'Hangszínek (bal)', 'center': 'Dalszöveg (közép)', 'right': 'Ritmus (jobb)', 'bottom': 'Alsó vezérlősáv'};

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

  static const fileExtension = 'snxproj';
  /// Korábbi (ALS) projektfájlok is megnyithatók
  static const legacyExtensions = ['alsproj'];
  static const formatVersion = 1;

  String name = 'Új projekt';
  final songs = <Song>[];
  final banks = <RegBank>[RegBank('Bank 1')];
  final slots = List<VSlot>.generate(4, (i) => VSlot(8 + i));
  final theme = ThemeSettings();
  final layout = LayoutSettings();
  final panels = {for (final k in panelKeys) k: PanelStyle()};
  final voiceGroups = defaultVoiceGroups();
  int leftColumns = 2;
  final rhythmItems = List<String>.of(defaultRhythmItems);
  int rhythmColumns = 2;
  final bottomModules = List<String>.of(defaultBottomModules);
  ReaderView readerView = ReaderView.text;
  final items = <String, ItemStyle>{};
  /// Beágyazott képek: azonosító → base64 (PNG/JPG), hogy a csomag egyetlen fájl legyen
  final images = <String, String>{};
  /// Fellépő csomag: PC-ről érkezett, a mobilon nem szerkeszthető
  bool readOnly = false;
  String? sourceInfo;

  ItemStyle? item(String id) => items[id];

  /// A már nem használt képek törlése (kisebb fájl, gyorsabb átvitel)
  void pruneImages() {
    final used = <String>{
      if (theme.bgImage != null) theme.bgImage!,
      for (final ps in panels.values)
        if (ps.backgroundImage != null) ps.backgroundImage!,
      for (final it in items.values)
        if (it.image != null) it.image!,
    };
    images.removeWhere((k, _) => !used.contains(k));
  }
  ItemStyle itemFor(String id) => items.putIfAbsent(id, ItemStyle.new);

  Map<String, dynamic> toJson() => {
        'format': 'SoundNexus Pro project', 'version': formatVersion, 'name': name,
        'songs': [for (final s in songs) s.toJson()],
        'banks': [for (final b in banks) b.toJson()],
        'slots': [for (final s in slots) s.toJson()],
        'theme': theme.toJson(),
        'layout': layout.toJson(),
        'panels': {for (final e in panels.entries) e.key: e.value.toJson()},
        'items': {for (final e in items.entries) if (!e.value.isEmpty) e.key: e.value.toJson()},
        'images': images,
        'voiceGroups': [for (final g in voiceGroups) g.toJson()],
        'leftColumns': leftColumns,
        'rhythmItems': rhythmItems,
        'rhythmColumns': rhythmColumns,
        'bottomModules': bottomModules,
        'readerView': readerView.name,
        'readOnly': readOnly,
        if (sourceInfo != null) 'sourceInfo': sourceInfo,
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
    final panels = j['panels'];
    if (panels is Map<String, dynamic>) {
      for (final e in panels.entries) {
        if (p.panels.containsKey(e.key)) p.panels[e.key]!.loadJson(e.value as Map<String, dynamic>);
      }
    }
    final items = j['items'];
    if (items is Map<String, dynamic>) {
      for (final e in items.entries) {
        p.items[e.key] = ItemStyle.fromJson(e.value as Map<String, dynamic>);
      }
    }
    final images = j['images'];
    if (images is Map<String, dynamic>) {
      for (final e in images.entries) {
        p.images[e.key] = e.value as String;
      }
    }
    final vg = j['voiceGroups'];
    if (vg is List && vg.isNotEmpty) {
      p.voiceGroups
        ..clear()
        ..addAll([for (final g in vg) VoiceGroup.fromJson(g as Map<String, dynamic>)]);
    }
    p.leftColumns = (j['leftColumns'] as int? ?? 2).clamp(1, 3);
    final ri = j['rhythmItems'];
    if (ri is List) {
      p.rhythmItems
        ..clear()
        ..addAll([for (final x in ri) if (rhythmCatalog.containsKey(x)) x as String]);
    }
    p.rhythmColumns = (j['rhythmColumns'] as int? ?? 2).clamp(1, 3);
    final bm = j['bottomModules'];
    if (bm is List) {
      p.bottomModules
        ..clear()
        ..addAll([for (final x in bm) if (bottomCatalog.containsKey(x)) x as String]);
    }
    p.readerView = ReaderView.values.firstWhere((v) => v.name == j['readerView'], orElse: () => ReaderView.text);
    p.readOnly = j['readOnly'] as bool? ?? false;
    p.sourceInfo = j['sourceInfo'] as String?;
    return p;
  }

  /// Saját, egyszerű bemutató-dallam G-dúrban (nem létező dal) a kottanézethez
  static SongScore _demoScore() {
    const bars = [
      [67, 71, 74, 71], [69, 72, 74, 72], [71, 69, 67, 64], [62, 66, 69, 67],
      [67, 67, 71, 74], [76, 74, 72, 71], [72, 71, 69, 67], [66, 67, 69, 62],
    ];
    final notes = <ScoreNote>[];
    for (var b = 0; b < 22; b++) {
      final pat = bars[b % bars.length];
      if (b % 4 == 3) {
        notes
          ..add(ScoreNote(b * 4.0, 2, pat[0]))
          ..add(ScoreNote(b * 4.0 + 2, 1.5, pat[2]))
          ..add(ScoreNote(b * 4.0 + 3.5, 0.5, pat[3]));
      } else {
        for (var k = 0; k < 4; k++) {
          notes.add(ScoreNote(b * 4.0 + k, 1, pat[k]));
        }
      }
    }
    return SongScore(name: 'Bemutató dallam', notes: notes, beatsPerBar: 4, bpm: 96);
  }

  factory Project.demo() {
    final p = Project()
      ..name = 'Bemutató projekt'
      ..readerView = ReaderView.both;
    p.songs.addAll([
      Song(
        title: 'Bemutató dal',
        artist: 'SoundNexus Pro',
        key: 'G',
        bpm: 96,
        style: '8Beat Pop',
        scores: [_demoScore()],
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
      base = '${env['APPDATA'] ?? env['USERPROFILE'] ?? '.'}\\SoundNexus Pro';
    } else if (Platform.isMacOS) {
      base = '${env['HOME'] ?? '.'}/Library/Application Support/SoundNexus Pro';
    } else {
      base = '${env['HOME'] ?? '.'}/.soundnexus';
    }
    return Directory(base);
  }

  static File get autosaveFile =>
      File('${appDataDir.path}${Platform.pathSeparator}utolso.$fileExtension');

  /// A korábbi (ALS nevű) verzió automatikus mentése — első indításkor átvesszük
  static File get legacyAutosaveFile {
    final env = Platform.environment;
    final String base;
    if (Platform.isWindows) {
      base = '${env['APPDATA'] ?? env['USERPROFILE'] ?? '.'}\\ALS';
    } else if (Platform.isMacOS) {
      base = '${env['HOME'] ?? '.'}/Library/Application Support/ALS';
    } else {
      base = '${env['HOME'] ?? '.'}/.als';
    }
    return File('$base${Platform.pathSeparator}utolso.alsproj');
  }
}
