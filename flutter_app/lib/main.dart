// flutter_app/lib/main.dart — ALS grafikus felület (Windows / macOS / Android)
//
//  ┌──────────────── felső sáv: kapcsolat, WAV-vágó, normalizáló ────────────────┐
//  │ Bal: hangszínek  │        Közép: Smart Reader        │ Jobb: ritmus, stílus │
//  └──────────────── alsó sáv: OTS, regisztrációk, napló ─────────────────────────┘
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'ffi/als_core.dart';
import 'reader/teleprompter_controller.dart';

void main() => runApp(const AlsApp());

class AlsApp extends StatelessWidget {
  const AlsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ALS – Yamaha Arranger Live Suite',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF3D7BF7),
          useMaterial3: true,
          visualDensity: VisualDensity.compact,
        ),
        home: const HomePage(),
      );
}

// ---------------------------------------------------------------------------
// Adatmodell
// ---------------------------------------------------------------------------

const _noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'H'];
/// Yamaha jelölés: 60 = C3
String noteName(int n) => '${_noteNames[n % 12]}${n ~/ 12 - 2}';

/// Hangszín a tárban (GM-példák; a Genos saját bankjait a modellprofil adja majd)
class VoicePreset {
  const VoicePreset(this.name, this.category, this.msb, this.lsb, this.program);
  final String name, category;
  final int msb, lsb, program;
}

const voiceLibrary = <VoicePreset>[
  VoicePreset('Strings', 'pad', 0, 0, 48),
  VoicePreset('Slow Strings', 'pad', 0, 0, 49),
  VoicePreset('Choir Aahs', 'choir', 0, 0, 52),
  VoicePreset('Warm Pad', 'pad', 0, 0, 89),
  VoicePreset('Brass Section', 'lead', 0, 0, 61),
  VoicePreset('Flute', 'lead', 0, 0, 73),
  VoicePreset('Jazz Organ', 'organ', 0, 0, 17),
  VoicePreset('Accordion', 'lead', 0, 0, 21),
  VoicePreset('Finger Bass', 'bass', 0, 0, 33),
  VoicePreset('Acoustic Bass', 'bass', 0, 0, 32),
  VoicePreset('Grand Piano', 'piano', 0, 0, 0),
  VoicePreset('E. Piano', 'piano', 0, 0, 4),
];

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
    channel = j['channel'] as int;
    enabled = j['enabled'] as bool;
    name = j['name'] as String;
    category = j['category'] as String;
    low = j['low'] as int;
    high = j['high'] as int;
    velLow = j['velLow'] as int;
    transpose = j['transpose'] as int;
    curve = (j['curve'] as num).toDouble();
    msb = j['msb'] as int;
    lsb = j['lsb'] as int;
    program = j['program'] as int;
    volume = j['volume'] as int;
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

class Section {
  const Section(this.label, this.code);
  final String label;
  final int code;
}

const intros = [Section('Intro A', 0x00), Section('Intro B', 0x01), Section('Intro C', 0x02)];
const mains = [Section('Main A', 0x08), Section('Main B', 0x09), Section('Main C', 0x0A), Section('Main D', 0x0B)];
const endings = [Section('Ending A', 0x20), Section('Ending B', 0x21), Section('Ending C', 0x22)];

const _demoLyrics = '''{Intro} – 4 ütem
Ide írd vagy töltsd be a dal szövegét
Minden sor egy-két ütemnyi idő
A program a hangszer tempójával görget
{Main A}
Első versszak, első sor
Első versszak, második sor
Első versszak, harmadik sor
Első versszak, negyedik sor
{Main B} – refrén
Refrén, első sor
Refrén, második sor
Refrén, harmadik sor
Refrén, negyedik sor
{Main A}
Második versszak, első sor
Második versszak, második sor
Második versszak, harmadik sor
Második versszak, negyedik sor
{Ending}
Vége''';

// ---------------------------------------------------------------------------
// Főoldal
// ---------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  static const double lineHeight = 58;

  AlsCore? core;
  String? coreError;
  bool connected = false, testMode = false;
  String connectionLabel = 'Nincs kapcsolat';

  double bpm = 96;
  bool styleRunning = false;
  int currentMain = 0x08;
  int? lastSection;

  final vslots = List<VSlot>.generate(4, (i) => VSlot(8 + i));
  final regs = List<Map<String, dynamic>?>.filled(8, null);
  bool saveMode = false;
  int? activeReg;

  String lyrics = _demoLyrics;
  int barsPerLine = 2;
  bool editLyrics = false;
  final lyricsCtrl = TextEditingController();
  final scroll = ScrollController();
  late TeleprompterController reader;
  late final Ticker ticker;
  Duration lastTick = Duration.zero;

  final logLines = <String>['ALS elindult.'];

  // ---- életciklus ----
  @override
  void initState() {
    super.initState();
    try {
      core = AlsCore.load();
    } catch (e) {
      coreError = 'A zenei mag (als_core_ffi.dll) nem tölthető be: $e';
    }
    _buildReader();
    _loadRegistrations();
    ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    ticker.dispose();
    core?.close();
    scroll.dispose();
    lyricsCtrl.dispose();
    super.dispose();
  }

  void log(String s) {
    setState(() {
      logLines.add(s);
      if (logLines.length > 200) logLines.removeAt(0);
    });
  }

  // ---- Smart Reader ----
  List<String> get lines => lyrics.split('\n');

  void _buildReader() {
    final n = math.max(lines.length, 2);
    reader = TeleprompterController(
      [for (var i = 0; i <= n; i++) Anchor((i * barsPerLine).toDouble(), i * lineHeight)],
      lookAheadBars: 0,
      bpm: bpm,
    );
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - lastTick).inMicroseconds / 1e6).clamp(0.0, 0.1);
    lastTick = elapsed;
    final now = core?.nowUs() ?? DateTime.now().microsecondsSinceEpoch;
    reader.tick(dt, now);
    if (scroll.hasClients && !editLyrics) {
      final view = scroll.position.viewportDimension;
      final target = (reader.scrollY - view * 0.30 + lineHeight / 2)
          .clamp(0.0, scroll.position.maxScrollExtent);
      if ((scroll.offset - target).abs() > 0.5) scroll.jumpTo(target);
    }
  }

  void _onRealtime(int status, int tsUs) {
    reader.onMidiRealtime(status, tsUs);
    if (status == 0xFA && !styleRunning) setState(() => styleRunning = true);
    if (status == 0xFC && styleRunning) setState(() => styleRunning = false);
  }

  // ---- kapcsolat ----
  Future<void> _connectDialog() async {
    final c = core;
    if (c == null) return;
    var (ins, outs) = c.listPorts();
    bool isYamaha(String p) {
      final l = p.toLowerCase();
      return l.contains('genos') || l.contains('tyros') || l.contains('yamaha') || l.contains('psr');
    }
    final yi = ins.indexWhere(isYamaha), yo = outs.indexWhere(isYamaha);
    int? inSel = yi >= 0 ? yi : (ins.isEmpty ? null : 0);
    int? outSel = yo >= 0 ? yo : (outs.isEmpty ? null : 0);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Kapcsolódás a hangszerhez'),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (ins.isEmpty && outs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Nem található MIDI-eszköz. Csatlakoztasd a hangszert USB-kábellel '
                      '(USB TO HOST), kapcsold be, majd kattints a Frissítés gombra.'),
                ),
              const Text('MIDI bemenet (a hangszerről):'),
              DropdownButton<int>(
                isExpanded: true,
                value: inSel,
                hint: const Text('nincs'),
                items: [for (var i = 0; i < ins.length; i++) DropdownMenuItem(value: i, child: Text(ins[i]))],
                onChanged: (v) => setD(() => inSel = v),
              ),
              const SizedBox(height: 8),
              const Text('MIDI kimenet (a hangszer felé):'),
              DropdownButton<int>(
                isExpanded: true,
                value: outSel,
                hint: const Text('nincs'),
                items: [for (var i = 0; i < outs.length; i++) DropdownMenuItem(value: i, child: Text(outs[i]))],
                onChanged: (v) => setD(() => outSel = v),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => setD(() {
                (ins, outs) = c.listPorts();
                inSel = ins.isEmpty ? null : 0;
                outSel = outs.isEmpty ? null : 0;
              }),
              child: const Text('Frissítés'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx, 'test'), child: const Text('Teszt mód (hangszer nélkül)')),
            FilledButton(
              onPressed: outSel == null ? null : () => Navigator.pop(ctx, 'connect'),
              child: const Text('Kapcsolódás'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;

    final ok = result == 'test'
        ? c.open(testMode: true)
        : c.open(inPort: inSel ?? -1, outPort: outSel ?? 0);
    setState(() {
      connected = ok;
      testMode = result == 'test';
      connectionLabel = !ok
          ? 'Kapcsolódási hiba'
          : testMode
              ? 'Teszt mód'
              : outs[outSel!];
    });
    if (!ok) {
      log('Nem sikerült megnyitni a MIDI-portot.');
      return;
    }
    c.onRealtime(_onRealtime);
    for (var i = 0; i < vslots.length; i++) {
      _applyZone(i);
    }
    log(testMode ? 'Teszt mód: a parancsok nem mennek hangszerre.' : 'Kapcsolódva: $connectionLabel');
  }

  // ---- hangszínek ----
  void _applyZone(int i) {
    final s = vslots[i];
    if (connected) {
      core?.setZone(i,
          enabled: s.enabled, low: s.low, high: s.high, velLow: s.velLow,
          transpose: s.transpose, velCurve: s.curve, outChannel: s.channel);
    }
  }

  void _sendVoice(int i) {
    final s = vslots[i];
    if (!connected) {
      log('Előbb kapcsolódj a hangszerhez.');
      return;
    }
    core?.voice(s.channel, s.msb, s.lsb, s.program, s.volume);
    log('V${i + 1}: ${s.name} elküldve (ch${s.channel + 1}, ${s.msb}/${s.lsb}/${s.program + 1})');
  }

  void _dropVoice(int i, VoicePreset p) {
    setState(() {
      final s = vslots[i];
      s
        ..name = p.name
        ..category = p.category
        ..msb = p.msb
        ..lsb = p.lsb
        ..program = p.program
        ..enabled = true
        ..autoZone();
    });
    _applyZone(i);
    _sendVoice(i);
  }

  void _autoAssignAll() {
    setState(() {
      for (final s in vslots) {
        if (s.category.isNotEmpty) s.autoZone();
      }
    });
    for (var i = 0; i < vslots.length; i++) {
      _applyZone(i);
    }
    log('Automatikus zónakiosztás kész.');
  }

  // ---- stílus ----
  void _start() {
    if (connected) core?.styleStart();
    setState(() => styleRunning = true);
    if (!connected) {
      reader.setBpm(bpm);
      reader.startInternal();
      log('Nincs hangszer: belső órával görget ($bpm BPM).');
    }
  }

  void _stop() {
    if (connected) core?.styleStop();
    reader.stop();
    setState(() => styleRunning = false);
  }

  void _section(Section s) {
    if (connected) core?.section(s.code);
    setState(() {
      lastSection = s.code;
      if (s.code >= 0x08 && s.code <= 0x0B) currentMain = s.code;
    });
    log('Szakasz: ${s.label}');
  }

  void _fill() {
    final code = 0x10 + (currentMain - 0x08);
    if (connected) core?.section(code);
    log('Fill In → ${mains[currentMain - 0x08].label}');
  }

  void _setTempo(double v, {bool send = true}) {
    setState(() => bpm = v.roundToDouble().clamp(30.0, 300.0));
    reader.setBpm(bpm);
    if (send && connected) core?.tempo(bpm);
  }

  // ---- regisztrációk ----
  File get _regFile =>
      File('${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}registrations.json');

  void _loadRegistrations() {
    try {
      final f = _regFile;
      if (!f.existsSync()) return;
      final list = jsonDecode(f.readAsStringSync()) as List;
      for (var i = 0; i < regs.length && i < list.length; i++) {
        regs[i] = list[i] as Map<String, dynamic>?;
      }
    } catch (_) {}
  }

  void _saveRegistrations() {
    try {
      _regFile.writeAsStringSync(jsonEncode(regs));
    } catch (e) {
      log('A regisztrációk mentése nem sikerült: $e');
    }
  }

  void _registration(int i) {
    if (saveMode) {
      regs[i] = {
        'bpm': bpm,
        'main': currentMain,
        'slots': [for (final s in vslots) s.toJson()],
      };
      _saveRegistrations();
      setState(() {
        saveMode = false;
        activeReg = i;
      });
      log('Regisztráció ${i + 1} elmentve.');
      return;
    }
    final r = regs[i];
    if (r == null) {
      log('A ${i + 1}. regisztráció üres. Mentéshez kattints a „Mentés” gombra, majd a számra.');
      return;
    }
    setState(() {
      activeReg = i;
      final slots = r['slots'] as List;
      for (var k = 0; k < vslots.length && k < slots.length; k++) {
        vslots[k].loadJson(slots[k] as Map<String, dynamic>);
      }
    });
    _setTempo((r['bpm'] as num).toDouble());
    _section(mains[((r['main'] as int) - 0x08).clamp(0, 3)]);
    for (var k = 0; k < vslots.length; k++) {
      _applyZone(k);
      if (vslots[k].enabled && connected) core?.voice(vslots[k].channel, vslots[k].msb, vslots[k].lsb, vslots[k].program, vslots[k].volume);
    }
    log('Regisztráció ${i + 1} behívva.');
  }

  // ---- eszközök ----
  Future<void> _trimWav() async {
    final c = core;
    if (c == null) return;
    final path = c.pickFile('WAV sample kiválasztása', 'wav');
    if (path == null) return;
    final dot = path.toLowerCase().lastIndexOf('.wav');
    final out = '${dot > 0 ? path.substring(0, dot) : path}_vagott.wav';
    final r = c.trimWav(path, out);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(r.ok ? 'Sample levágva' : 'Hiba'),
        content: Text(r.ok
            ? 'Levágva az elejéről: ${(r.json['cutHeadMs'] as num).toStringAsFixed(2)} ms\n'
                'Levágva a végéről: ${(r.json['cutTailMs'] as num).toStringAsFixed(2)} ms\n'
                'Csúcsszint: ${(r.json['peakDb'] as num).toStringAsFixed(1)} dBFS\n'
                '${r.json['needsReview'] == true ? '\nFigyelem: kézi ellenőrzés javasolt (lassú felfutás).\n' : ''}'
                '\nMentve: $out'
            : '${r.json['error']}'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    log(r.ok ? 'WAV levágva: $out' : 'WAV-vágás hiba: ${r.json['error']}');
  }

  Future<void> _loadLyrics() async {
    final path = core?.pickFile('Dalszöveg betöltése', 'txt');
    if (path == null) return;
    try {
      final text = await File(path).readAsString();
      setState(() {
        lyrics = text.replaceAll('\r\n', '\n');
        _buildReader();
      });
      log('Szöveg betöltve: $path');
    } catch (e) {
      log('A szöveg nem olvasható (UTF-8 formátum kell): $e');
    }
  }

  Future<void> _normalizeDialog() async {
    final lufsCtrl = TextEditingController(text: '-22.5');
    final ccCtrl = TextEditingController(text: '100 90 110 80');
    String result = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Stílus hangerő-normalizálás'),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Cél: −18 LUFS. Add meg a stílus mért hangerejét és a részek jelenlegi CC7 értékeit.'),
              const SizedBox(height: 12),
              TextField(controller: lufsCtrl, decoration: const InputDecoration(labelText: 'Mért hangerő (LUFS)')),
              TextField(controller: ccCtrl, decoration: const InputDecoration(labelText: 'CC7 értékek szóközzel')),
              const SizedBox(height: 12),
              SelectableText(result, style: const TextStyle(fontFamily: 'Consolas')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bezárás')),
            FilledButton(
              onPressed: () => setD(() => result = _normalize(lufsCtrl.text, ccCtrl.text)),
              child: const Text('Számítás'),
            ),
          ],
        ),
      ),
    );
  }

  /// Ugyanaz a képlet, mint a C++ magban: gain_dB ≈ 40·log10(CC7/127)
  String _normalize(String lufsText, String ccText) {
    final measured = double.tryParse(lufsText.replaceAll(',', '.'));
    final ccs = ccText.split(RegExp(r'[\s,;]+')).map(int.tryParse).whereType<int>().where((v) => v > 0 && v <= 127).toList();
    if (measured == null || ccs.isEmpty) return 'Hibás bemenet.';
    double toDb(int v) => 40 * math.log(v / 127) / math.ln10;
    int toCc(double db) => (127 * math.pow(10, db / 40)).round().clamp(1, 127);
    final wanted = -18.0 - measured;
    final headroom = ccs.map((v) => -toDb(v)).reduce(math.min);
    final delta = [wanted, headroom, 6.0].reduce(math.min);
    final b = StringBuffer()
      ..writeln('Alkalmazott: ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)} dB')
      ..writeln('Maradék (stílushangerőbe): ${(wanted - delta).toStringAsFixed(2)} dB');
    for (var i = 0; i < ccs.length; i++) {
      b.writeln('Rész ${i + 1}: CC7 ${ccs[i]} → ${toCc(toDb(ccs[i]) + delta)}');
    }
    return b.toString();
  }

  // -------------------------------------------------------------------------
  // Felület
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 1300;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ALS – Yamaha Arranger Live Suite'),
        backgroundColor: cs.surfaceContainerHigh,
        actions: [
          TextButton.icon(
            onPressed: core == null ? null : _trimWav,
            icon: const Icon(Icons.content_cut),
            label: const Text('WAV vágás'),
          ),
          TextButton.icon(
            onPressed: _normalizeDialog,
            icon: const Icon(Icons.equalizer),
            label: const Text('Normalizálás'),
          ),
          const SizedBox(width: 12),
          Chip(
            avatar: Icon(Icons.circle, size: 12, color: connected ? (testMode ? Colors.amber : Colors.greenAccent) : Colors.redAccent),
            label: Text(connectionLabel),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: core == null ? null : _connectDialog,
            icon: const Icon(Icons.usb),
            label: Text(connected ? 'Újracsatlakozás' : 'Kapcsolódás'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(children: [
        if (coreError != null)
          MaterialBanner(content: Text(coreError!), actions: const [SizedBox()]),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: compact ? 290 : 340, child: _voicesPanel(cs)),
            VerticalDivider(width: 1, color: cs.outlineVariant),
            Expanded(child: _readerPanel(cs)),
            VerticalDivider(width: 1, color: cs.outlineVariant),
            SizedBox(width: compact ? 250 : 290, child: _stylePanel(cs, compact ? 250 : 290)),
          ]),
        ),
        Divider(height: 1, color: cs.outlineVariant),
        _bottomBar(cs),
      ]),
    );
  }

  Widget _panelTitle(String t, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
        child: Row(children: [
          Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (trailing != null) trailing,
        ]),
      );

  // ---- bal sáv: hangszínek ----
  Widget _voicesPanel(ColorScheme cs) => ListView(padding: const EdgeInsets.only(bottom: 16), children: [
        _panelTitle('Hangszínek',
            trailing: TextButton(onPressed: _autoAssignAll, child: const Text('Auto-kiosztás'))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('Natív részek (a hangszeren): Left · Right 1 · Right 2 · Right 3',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('Hangszín-tár – húzd a hangszínt egy V-slotra:',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in voiceLibrary)
              Draggable<VoicePreset>(
                data: p,
                feedback: Material(color: Colors.transparent, child: Chip(label: Text(p.name))),
                child: Chip(label: Text(p.name, style: const TextStyle(fontSize: 12))),
              ),
          ]),
        ),
        for (var i = 0; i < vslots.length; i++) _slotCard(i, cs),
      ]);

  Widget _slotCard(int i, ColorScheme cs) {
    final s = vslots[i];
    return DragTarget<VoicePreset>(
      onAcceptWithDetails: (d) => _dropVoice(i, d.data),
      builder: (ctx, cand, _) => Card(
        margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
        color: cand.isNotEmpty ? cs.primaryContainer : (s.enabled ? cs.surfaceContainerHighest : cs.surfaceContainer),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('V${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis)),
              DropdownButton<int>(
                value: s.channel,
                underline: const SizedBox(),
                items: [for (var c = 0; c < 16; c++) DropdownMenuItem(value: c, child: Text('ch${c + 1}'))],
                onChanged: (v) {
                  setState(() => s.channel = v!);
                  _applyZone(i);
                },
              ),
              Switch(
                value: s.enabled,
                onChanged: (v) {
                  setState(() => s.enabled = v);
                  _applyZone(i);
                },
              ),
            ]),
            Text('Zóna: ${noteName(s.low)} – ${noteName(s.high)}'
                '${s.transpose != 0 ? '   transz: ${s.transpose > 0 ? '+' : ''}${s.transpose}' : ''}'
                '${s.velLow > 1 ? '   vel ≥ ${s.velLow}' : ''}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            RangeSlider(
              values: RangeValues(s.low.toDouble(), s.high.toDouble()),
              min: 21,
              max: 108,
              divisions: 87,
              onChanged: (v) => setState(() {
                s.low = v.start.round();
                s.high = v.end.round();
              }),
              onChangeEnd: (_) => _applyZone(i),
            ),
            Row(children: [
              const Text('Oktáv', style: TextStyle(fontSize: 12)),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove, size: 16),
                onPressed: () {
                  setState(() => s.transpose = (s.transpose - 12).clamp(-24, 24));
                  _applyZone(i);
                },
              ),
              Text('${s.transpose ~/ 12}'),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add, size: 16),
                onPressed: () {
                  setState(() => s.transpose = (s.transpose + 12).clamp(-24, 24));
                  _applyZone(i);
                },
              ),
              const Spacer(),
              const Text('Hangerő', style: TextStyle(fontSize: 12)),
              SizedBox(
                width: 110,
                child: Slider(
                  value: s.volume.toDouble(),
                  max: 127,
                  onChanged: (v) => setState(() => s.volume = v.round()),
                  onChangeEnd: (_) {
                    if (s.enabled) _sendVoice(i);
                  },
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  // ---- középső sáv: Smart Reader ----
  Widget _readerPanel(ColorScheme cs) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _panelTitle('Smart Reader', trailing: AnimatedBuilder(
          animation: reader,
          builder: (_, __) => Text(
            'Ütem ${(reader.currentBar + 1).floor()}  ·  ${reader.bpm.toStringAsFixed(0)} BPM  ·  '
            '${reader.source == ClockSource.midi ? 'MIDI Clock' : 'belső óra'}',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        )),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          const SizedBox(width: 6),
          const Text('Ütem/sor:'),
          DropdownButton<int>(
            value: barsPerLine,
            underline: const SizedBox(),
            items: const [1, 2, 4].map((v) => DropdownMenuItem(value: v, child: Text(' $v'))).toList(),
            onChanged: (v) => setState(() {
              barsPerLine = v!;
              _buildReader();
            }),
          ),
          IconButton(
            tooltip: 'Elejére',
            icon: const Icon(Icons.skip_previous),
            onPressed: () => setState(() => reader.reset()),
          ),
          IconButton(
            tooltip: reader.running ? 'Megállítás' : 'Görgetés indítása (belső óra)',
            icon: Icon(reader.running ? Icons.pause : Icons.play_arrow),
            onPressed: () => setState(() {
              if (reader.running) {
                reader.stop();
              } else {
                reader.setBpm(bpm);
                reader.startInternal();
              }
            }),
          ),
          IconButton(
            tooltip: 'Szöveg betöltése (.txt)',
            icon: const Icon(Icons.folder_open),
            onPressed: core == null ? null : _loadLyrics,
          ),
          IconButton(
            tooltip: editLyrics ? 'Kész' : 'Szöveg szerkesztése',
            icon: Icon(editLyrics ? Icons.check : Icons.edit),
            onPressed: () => setState(() {
              if (editLyrics) {
                lyrics = lyricsCtrl.text;
                _buildReader();
              } else {
                lyricsCtrl.text = lyrics;
              }
              editLyrics = !editLyrics;
            }),
          ),
        ])),
        Divider(height: 1, color: cs.outlineVariant),
        Expanded(
          child: editLyrics
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: lyricsCtrl,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(fontSize: 20),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Soronként a dalszöveg. {Main A} stb. jelölés a szakaszokhoz.',
                    ),
                  ),
                )
              : AnimatedBuilder(
                  animation: reader,
                  builder: (_, __) {
                    final current = (reader.currentBar / barsPerLine).floor();
                    final ls = lines;
                    return ListView.builder(
                      controller: scroll,
                      itemExtent: lineHeight,
                      padding: const EdgeInsets.only(bottom: 600),
                      itemCount: ls.length,
                      itemBuilder: (_, i) {
                        final isTag = ls[i].trimLeft().startsWith('{');
                        final isCurrent = i == current;
                        return Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          color: isCurrent ? cs.primary.withValues(alpha: 0.16) : null,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                            ls[i],
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: isTag ? 18 : 30,
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                              color: isTag
                                  ? cs.tertiary
                                  : i < current
                                      ? cs.onSurface.withValues(alpha: 0.35)
                                      : cs.onSurface,
                            ),
                          ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ]);

  // ---- jobb sáv: ritmus és stílus ----
  Widget _stylePanel(ColorScheme cs, double panelWidth) {
    final btnW = (panelWidth - 28 - 8) / 2;
    Widget sectionBtn(Section s) {
      final sel = lastSection == s.code || (s.code == currentMain && lastSection == null);
      return SizedBox(
        width: btnW,
        child: sel
            ? FilledButton(onPressed: () => _section(s), child: Text(s.label))
            : OutlinedButton(onPressed: () => _section(s), child: Text(s.label)),
      );
    }

    return ListView(padding: const EdgeInsets.only(bottom: 16), children: [
      _panelTitle('Ritmus és stílus'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: styleRunning ? Colors.green.shade700 : null),
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _stop,
                icon: const Icon(Icons.stop),
                label: const Text('Stop', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Center(
        child: Text('${bpm.toStringAsFixed(0)} BPM',
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          IconButton(onPressed: () => _setTempo(bpm - 1), icon: const Icon(Icons.remove)),
          Expanded(
            child: Slider(
              value: bpm,
              min: 40,
              max: 240,
              onChanged: (v) => _setTempo(v, send: false),
              onChangeEnd: (v) => _setTempo(v),
            ),
          ),
          IconButton(onPressed: () => _setTempo(bpm + 1), icon: const Icon(Icons.add)),
        ]),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in intros) sectionBtn(s),
          for (final s in mains) sectionBtn(s),
          SizedBox(width: btnW, child: OutlinedButton(onPressed: _fill, child: const Text('Fill In'))),
          sectionBtn(const Section('Break', 0x18)),
          for (final s in endings) sectionBtn(s),
        ]),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          'A stílust a hangszeren választod ki; innen az indítás, a szakaszok és a tempó vezérelhető.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ),
    ]);
  }

  // ---- alsó sáv: OTS és regisztrációk ----
  Widget _bottomBar(ColorScheme cs) => Container(
        color: cs.surfaceContainerHigh,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          Flexible(flex: 4, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          const Text('OTS', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          for (var i = 1; i <= 4; i++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: 'OTS-hívás MIDI-n: a modell Data List-je alapján kerül be',
                child: OutlinedButton(onPressed: null, child: Text('$i')),
              ),
            ),
          const SizedBox(width: 16),
          const Text('Regisztráció', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: () => setState(() => saveMode = !saveMode),
            icon: Icon(Icons.save, color: saveMode ? Colors.orangeAccent : null),
            label: Text(saveMode ? 'Hová?' : 'Mentés'),
          ),
          for (var i = 0; i < regs.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: SizedBox(
                width: 46,
                child: activeReg == i
                    ? FilledButton(
                        style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () => _registration(i),
                        child: Text('${i + 1}'))
                    : OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: BorderSide(color: saveMode ? Colors.orangeAccent : (regs[i] != null ? cs.primary : cs.outline)),
                        ),
                        onPressed: () => _registration(i),
                        child: Text('${i + 1}')),
              ),
            ),
          ]))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(logLines.last,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ]),
      );
}
