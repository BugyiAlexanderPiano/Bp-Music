// lib/ui/home_page.dart — az ALS főablaka (PC-s szerkesztő mód)
//
//  ┌ menüsor: Fájl · Szerkesztés · Nézet · Hangszer · Eszközök · Súgó ── kapcsolat · Szinkron ┐
//  │ Hangszíncsoportok │        Dal-oldalak (lapozható, zárható)        │ Ritmus, stílus    │
//  ├──────────── V1–V4 · One Touch Settings · Tempó · Regiszter bankok ──────────────────────┤
//  └ állapotsor ──────────────────────────────────────────────────────────────────────────────┘
import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../ffi/als_core.dart';
import '../model/project.dart';
import '../reader/teleprompter_controller.dart';
import 'dialogs.dart';
import 'song_editor.dart';
import 'song_view.dart';

bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

class Section {
  const Section(this.label, this.code);
  final String label;
  final int code;
}

const intros = [Section('Intro A', 0x00), Section('Intro B', 0x01), Section('Intro C', 0x02)];
const mains = [Section('Main A', 0x08), Section('Main B', 0x09), Section('Main C', 0x0A), Section('Main D', 0x0B)];
const endings = [Section('Ending A', 0x20), Section('Ending B', 0x21), Section('Ending C', 0x22)];

const _projectTypes = [XTypeGroup(label: 'ALS projekt', extensions: ['alsproj'])];

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.project,
    required this.initialPath,
    required this.onProjectReplaced,
    required this.onThemeChanged,
  });

  final Project project;
  final String? initialPath;
  final ValueChanged<Project> onProjectReplaced;
  final VoidCallback onThemeChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  Project get p => widget.project;
  bool get _compact => MediaQuery.sizeOf(context).width < 1300;

  // Hangszer
  AlsCore? core;
  String? coreError;
  bool connected = false, testMode = false;
  String connectionLabel = 'Nincs kapcsolat';

  // Fájl
  String? currentPath;
  bool dirty = false;
  Timer? _autosave;

  // Oldalak és olvasó
  final pages = PageController();
  int page = 0;
  bool locked = false;
  final _scrolls = <int, ScrollController>{};
  SongLayout? _layout;
  late TeleprompterController reader;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  // Felület
  bool editLayout = false;
  int? openGroup = 0;
  bool styleRunning = false;
  int currentMain = 0x08;
  int? lastSection;
  double bpm = 96;
  final _taps = <DateTime>[];

  // Regisztrációk
  int bank = 0;
  bool saveMode = false;
  int? activeReg;

  final logLines = <String>['ALS elindult.'];

  // -------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    currentPath = widget.initialPath;
    try {
      core = AlsCore.load();
    } catch (e) {
      coreError = 'A zenei mag (als_core_ffi) nem tölthető be: $e';
    }
    _rebuildReader();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(HomePage old) {
    super.didUpdateWidget(old);
    if (!identical(old.project, widget.project)) {
      page = 0;
      bank = 0;
      activeReg = null;
      for (final c in _scrolls.values) {
        c.dispose();
      }
      _scrolls.clear();
      if (pages.hasClients) pages.jumpToPage(0);
      _rebuildReader();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _autosave?.cancel();
    _writeAutosave();
    core?.close();
    pages.dispose();
    for (final c in _scrolls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void log(String s) => setState(() {
        logLines.add(s);
        if (logLines.length > 200) logLines.removeAt(0);
      });

  void _changed({bool theme = false}) {
    setState(() => dirty = true);
    if (theme) widget.onThemeChanged();
    _autosave?.cancel();
    _autosave = Timer(const Duration(seconds: 2), _writeAutosave);
  }

  void _writeAutosave() {
    try {
      Project.appDataDir.createSync(recursive: true);
      Project.autosaveFile.writeAsStringSync(p.toFileString());
    } catch (_) {}
  }

  // ---- olvasó ----
  Song? get song => p.songs.isEmpty ? null : p.songs[page.clamp(0, p.songs.length - 1)];

  ScrollController _scrollFor(int i) => _scrolls.putIfAbsent(i, ScrollController.new);

  void _rebuildReader() {
    final s = song;
    if (s == null) {
      _layout = null;
      reader = TeleprompterController(const [Anchor(0, 0), Anchor(1, 0)]);
      return;
    }
    _layout = SongLayout(s, p.theme);
    bpm = s.bpm;
    reader = TeleprompterController(_layout!.anchors, beatsPerBar: s.beatsPerBar, lookAheadBars: 0, bpm: s.bpm);
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastTick = elapsed;
    reader.tick(dt, core?.nowUs() ?? DateTime.now().microsecondsSinceEpoch);
    final sc = _scrolls[page];
    if (sc != null && sc.hasClients && reader.running) {
      final view = sc.position.viewportDimension;
      final target = (reader.scrollY - view * 0.30).clamp(0.0, sc.position.maxScrollExtent);
      if ((sc.offset - target).abs() > 0.5) sc.jumpTo(target);
    }
  }

  void _onRealtime(int status, int tsUs) {
    reader.onMidiRealtime(status, tsUs);
    if (status == 0xFA) setState(() => styleRunning = true);
    if (status == 0xFC) setState(() => styleRunning = false);
  }

  void _goToPage(int i) {
    if (p.songs.isEmpty) return;
    final target = i.clamp(0, p.songs.length - 1);
    pages.animateToPage(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  // ---- fájlkezelés ----
  Future<bool> _confirmDiscard() async {
    if (!dirty) return true;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mentetlen változások'),
        content: const Text('A projekt módosult. Folytatod mentés nélkül?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Mégse')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Folytatás mentés nélkül')),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _newProject() async {
    if (!await _confirmDiscard()) return;
    final np = Project()
      ..songs.add(Song(title: 'Új dal', body: '{Main A}\n[C]Ide írd a szöveget'));
    np.theme.loadJson(p.theme.toJson());
    np.layout.loadJson(p.layout.toJson());
    currentPath = null;
    dirty = false;
    widget.onProjectReplaced(np);
    log('Új projekt.');
  }

  Future<void> _openProject() async {
    if (!await _confirmDiscard()) return;
    final f = await openFile(acceptedTypeGroups: _projectTypes);
    if (f == null) return;
    try {
      final np = Project.fromFileString(await File(f.path).readAsString());
      currentPath = f.path;
      dirty = false;
      widget.onProjectReplaced(np);
      log('Megnyitva: ${f.path}');
    } catch (e) {
      log('A fájl nem ALS projekt vagy sérült: $e');
    }
  }

  Future<void> _saveProject({bool saveAs = false}) async {
    var path = currentPath;
    if (path == null || saveAs) {
      final loc = await getSaveLocation(
        suggestedName: '${p.name}.${Project.fileExtension}',
        acceptedTypeGroups: _projectTypes,
      );
      if (loc == null) return;
      path = loc.path.toLowerCase().endsWith('.${Project.fileExtension}') ? loc.path : '${loc.path}.${Project.fileExtension}';
      p.name = File(path).uri.pathSegments.last.replaceAll('.${Project.fileExtension}', '');
    }
    try {
      await File(path).writeAsString(p.toFileString());
      setState(() {
        currentPath = path;
        dirty = false;
      });
      _writeAutosave();
      log('Mentve: $path');
    } catch (e) {
      log('A mentés nem sikerült: $e');
    }
  }

  Future<void> _importLyrics() async {
    final f = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'Szöveg', extensions: ['txt', 'cho', 'pro'])]);
    if (f == null) return;
    try {
      final text = (await File(f.path).readAsString()).replaceAll('\r\n', '\n');
      final title = f.name.replaceAll(RegExp(r'\.(txt|cho|pro)$', caseSensitive: false), '');
      setState(() => p.songs.add(Song(title: title, body: text)));
      _changed();
      _goToPage(p.songs.length - 1);
      log('Dal importálva: $title');
    } catch (e) {
      log('A szöveg nem olvasható (UTF-8 kell): $e');
    }
  }

  Future<void> _exit() async {
    if (!await _confirmDiscard()) return;
    _writeAutosave();
    exit(0);
  }

  // ---- dalok ----
  Future<void> _editSong() async {
    final s = song;
    if (s == null) return;
    final edited = await showSongEditor(context, s, p.theme, p.banks.length);
    if (edited == null) return;
    setState(() {
      p.songs[page] = edited;
      _rebuildReader();
    });
    _changed();
  }

  Future<void> _addSong() async {
    final s = Song(title: 'Új dal', body: '{Main A}\n[C]Ide írd a szöveget');
    final edited = await showSongEditor(context, s, p.theme, p.banks.length);
    if (edited == null) return;
    setState(() => p.songs.insert(p.songs.isEmpty ? 0 : page + 1, edited));
    _changed();
    _goToPage(p.songs.isEmpty ? 0 : page + 1);
  }

  Future<void> _deleteSong() async {
    final s = song;
    if (s == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dal törlése'),
        content: Text('Biztosan törlöd: „${s.title}”?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Mégse')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Törlés')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      p.songs.removeAt(page);
      page = page.clamp(0, (p.songs.length - 1).clamp(0, 1 << 30));
      _rebuildReader();
    });
    _changed();
  }

  void _moveSong(int dir) {
    final to = page + dir;
    if (song == null || to < 0 || to >= p.songs.length) return;
    setState(() {
      final s = p.songs.removeAt(page);
      p.songs.insert(to, s);
    });
    _changed();
    _goToPage(to);
  }

  // ---- hangszer ----
  Future<void> _connectDialog() async {
    final c = core;
    if (c == null) return;
    var (ins, outs) = c.listPorts();
    bool isYamaha(String n) {
      final l = n.toLowerCase();
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
    final ok = result == 'test' ? c.open(testMode: true) : c.open(inPort: inSel ?? -1, outPort: outSel ?? 0);
    setState(() {
      connected = ok;
      testMode = result == 'test';
      connectionLabel = !ok ? 'Kapcsolódási hiba' : (testMode ? 'Teszt mód' : outs[outSel!]);
    });
    if (!ok) {
      log('Nem sikerült megnyitni a MIDI-portot.');
      return;
    }
    c.onRealtime(_onRealtime);
    for (var i = 0; i < p.slots.length; i++) {
      _applyZone(i);
    }
    log(testMode ? 'Teszt mód: a parancsok nem mennek hangszerre.' : 'Kapcsolódva: $connectionLabel');
  }

  void _applyZone(int i) {
    final s = p.slots[i];
    if (connected) {
      core?.setZone(i,
          enabled: s.enabled, low: s.low, high: s.high, velLow: s.velLow,
          transpose: s.transpose, velCurve: s.curve, outChannel: s.channel);
    }
  }

  void _sendVoice(int i) {
    final s = p.slots[i];
    if (!connected) {
      log('Előbb kapcsolódj a hangszerhez (Hangszer → Kapcsolódás).');
      return;
    }
    core?.voice(s.channel, s.msb, s.lsb, s.program, s.volume);
    log('V${i + 1}: ${s.name} elküldve (ch${s.channel + 1})');
  }

  void _assignVoice(int i, VoicePreset v) {
    setState(() => p.slots[i].applyPreset(v));
    _applyZone(i);
    if (connected) _sendVoice(i);
    _changed();
    log('V${i + 1} ← ${v.name}');
  }

  void _start() {
    if (connected) core?.styleStart();
    setState(() => styleRunning = true);
    if (!connected) {
      reader.setBpm(bpm);
      reader.startInternal();
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
  }

  void _fill() {
    if (connected) core?.section(0x10 + (currentMain - 0x08));
    log('Fill In');
  }

  void _setTempo(double v, {bool send = true}) {
    setState(() => bpm = v.roundToDouble().clamp(30.0, 300.0));
    reader.setBpm(bpm);
    if (send && connected) core?.tempo(bpm);
  }

  void _tapTempo() {
    final now = DateTime.now();
    if (_taps.isNotEmpty && now.difference(_taps.last).inMilliseconds > 2000) _taps.clear();
    _taps.add(now);
    if (_taps.length > 5) _taps.removeAt(0);
    if (_taps.length >= 2) {
      final ms = now.difference(_taps.first).inMilliseconds / (_taps.length - 1);
      _setTempo(60000 / ms);
    }
  }

  /// Egykattintásos szinkron: a dal adatai alapján beállítja a hangszert
  void _syncSong() {
    final s = song;
    if (s == null) return;
    if (s.registration != null) _recallReg(s.registration!.bank, s.registration!.slot, quiet: true);
    _setTempo(s.bpm);
    _section(mains.firstWhere((m) => m.code == s.mainSection, orElse: () => mains.first));
    var layers = 0;
    for (var i = 0; i < p.slots.length; i++) {
      _applyZone(i);
      if (p.slots[i].enabled) {
        layers++;
        if (connected) core?.voice(p.slots[i].channel, p.slots[i].msb, p.slots[i].lsb, p.slots[i].program, p.slots[i].volume);
      }
    }
    reader.reset();
    final msg = connected
        ? 'Elküldve: ${s.bpm.round()} BPM, ${mains.firstWhere((m) => m.code == s.mainSection, orElse: () => mains.first).label}, '
            '$layers réteg${s.style.isNotEmpty ? '. Stílus: ${s.style} – ezt válaszd ki a hangszeren.' : '.'}'
        : 'Nincs hangszer csatlakoztatva – a beállítás csak a programban történt meg.';
    log(msg);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- regisztrációk ----
  void _regButton(int i) {
    if (saveMode) {
      p.banks[bank].slots[i] = {
        'bpm': bpm,
        'main': currentMain,
        'slots': [for (final s in p.slots) s.toJson()],
      };
      setState(() {
        saveMode = false;
        activeReg = i;
      });
      _changed();
      log('Mentve: ${p.banks[bank].name} / ${i + 1}');
      return;
    }
    _recallReg(bank, i);
  }

  void _recallReg(int b, int i, {bool quiet = false}) {
    if (b >= p.banks.length) return;
    final r = p.banks[b].slots[i];
    if (r == null) {
      if (!quiet) log('${p.banks[b].name} / ${i + 1} üres. Mentéshez: Mentés, majd a szám.');
      return;
    }
    setState(() {
      bank = b;
      activeReg = i;
      final slots = r['slots'] as List;
      for (var k = 0; k < p.slots.length && k < slots.length; k++) {
        p.slots[k].loadJson(slots[k] as Map<String, dynamic>);
      }
    });
    _setTempo((r['bpm'] as num).toDouble());
    _section(mains[((r['main'] as int) - 0x08).clamp(0, 3)]);
    for (var k = 0; k < p.slots.length; k++) {
      _applyZone(k);
      if (p.slots[k].enabled && connected) {
        core?.voice(p.slots[k].channel, p.slots[k].msb, p.slots[k].lsb, p.slots[k].program, p.slots[k].volume);
      }
    }
    if (!quiet) log('Behívva: ${p.banks[b].name} / ${i + 1}');
  }

  // ---- eszközök ----
  Future<void> _trimWav() async {
    final c = core;
    if (c == null) return;
    final f = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'WAV', extensions: ['wav'])]);
    if (f == null) return;
    final path = f.path;
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
  }

  void _about() => showAboutDialog(
        context: context,
        applicationName: 'ALS – Yamaha Arranger Live Suite',
        applicationVersion: '0.3 (1. szakasz: PC-s szerkesztő)',
        children: const [
          Text('Szerkesztő és élő vezérlő program Yamaha Genos 2, Genos, Tyros 5, Tyros 4 és PSR-SX hangszerekhez.'),
          SizedBox(height: 8),
          Text('Billentyűparancsok: Ctrl+N új · Ctrl+O megnyitás · Ctrl+S mentés · Ctrl+Shift+S mentés másként · '
              'Ctrl+E dal szerkesztése · F5 szinkron · ←/→ lapozás · Szóköz Start/Stop'),
        ],
      );

  // -------------------------------------------------------------------------
  // Felület
  // -------------------------------------------------------------------------
  SingleActivator _key(LogicalKeyboardKey k, {bool shift = false}) =>
      SingleActivator(k, control: !Platform.isMacOS, meta: Platform.isMacOS, shift: shift);

  @override
  Widget build(BuildContext context) {
    final t = p.theme;
    final l = p.layout;
    return CallbackShortcuts(
      bindings: {
        _key(LogicalKeyboardKey.keyN): _newProject,
        _key(LogicalKeyboardKey.keyO): _openProject,
        _key(LogicalKeyboardKey.keyS): () => _saveProject(),
        _key(LogicalKeyboardKey.keyS, shift: true): () => _saveProject(saveAs: true),
        _key(LogicalKeyboardKey.keyE): _editSong,
        const SingleActivator(LogicalKeyboardKey.f5): _syncSong,
        const SingleActivator(LogicalKeyboardKey.arrowRight): () { if (!locked) _goToPage(page + 1); },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () { if (!locked) _goToPage(page - 1); },
        const SingleActivator(LogicalKeyboardKey.space): () {
          if (styleRunning) {
            _stop();
          } else {
            _start();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: t.backgroundDecoration,
            child: SafeArea(
              child: Column(children: [
                if (isDesktop) _topBar(context),
                if (coreError != null)
                  Container(
                    width: double.infinity,
                    color: Colors.red.withValues(alpha: 0.25),
                    padding: const EdgeInsets.all(8),
                    child: Text(coreError!),
                  ),
                if (editLayout) _editBar(),
                Expanded(child: _mainRow(l)),
                if (editLayout) _hSplitter(),
                SizedBox(height: l.bottomHeight, child: _panel(_bottomBar(), margin: const EdgeInsets.fromLTRB(6, 0, 6, 0))),
                _statusLine(),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(Widget child, {EdgeInsets margin = const EdgeInsets.all(6)}) {
    final t = p.theme;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: t.panel.withValues(alpha: t.panelOpacity),
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: editLayout ? t.accent.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.07)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(p.theme.radius), child: child),
    );
  }

  // ---- felső menüsor ----
  Widget _topBar(BuildContext context) {
    final t = p.theme;
    MenuItemButton item(String label, VoidCallback? onTap, {IconData? icon, MenuSerializableShortcut? shortcut}) =>
        MenuItemButton(
          onPressed: onTap,
          leadingIcon: icon == null ? null : Icon(icon, size: 18),
          shortcut: shortcut,
          child: Text(label),
        );
    CheckboxMenuButton check(String label, bool value, VoidCallback onTap) =>
        CheckboxMenuButton(value: value, onChanged: (_) => onTap(), child: Text(label));

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25)),
      child: Row(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.graphic_eq, color: t.accent),
        ),
        Expanded(
          child: MenuBar(
            style: const MenuStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.transparent),
              elevation: WidgetStatePropertyAll(0),
            ),
            children: [
              SubmenuButton(menuChildren: [
                item('Új projekt', _newProject, icon: Icons.note_add_outlined, shortcut: _key(LogicalKeyboardKey.keyN)),
                item('Megnyitás…', _openProject, icon: Icons.folder_open_outlined, shortcut: _key(LogicalKeyboardKey.keyO)),
                const Divider(height: 1),
                item('Mentés', () => _saveProject(), icon: Icons.save_outlined, shortcut: _key(LogicalKeyboardKey.keyS)),
                item('Mentés másként…', () => _saveProject(saveAs: true), icon: Icons.save_as_outlined,
                    shortcut: _key(LogicalKeyboardKey.keyS, shift: true)),
                const Divider(height: 1),
                item('Dalszöveg importálása (.txt)…', _importLyrics, icon: Icons.file_download_outlined),
                item('Küldés tabletre… (2. szakasz)', null, icon: Icons.tablet_android),
                const Divider(height: 1),
                item('Kilépés', _exit, icon: Icons.logout),
              ], child: const Text('Fájl')),
              SubmenuButton(menuChildren: [
                item('Új dal…', _addSong, icon: Icons.add),
                item('Dal szerkesztése…', song == null ? null : _editSong, icon: Icons.edit_outlined,
                    shortcut: _key(LogicalKeyboardKey.keyE)),
                item('Dal törlése', song == null ? null : _deleteSong, icon: Icons.delete_outline),
                const Divider(height: 1),
                item('Dal előrébb', page > 0 ? () => _moveSong(-1) : null, icon: Icons.arrow_back),
                item('Dal hátrébb', page < p.songs.length - 1 ? () => _moveSong(1) : null, icon: Icons.arrow_forward),
              ], child: const Text('Szerkesztés')),
              SubmenuButton(menuChildren: [
                item('Téma és színek…', () => showThemeDialog(context, p.theme, () => _changed(theme: true)),
                    icon: Icons.palette_outlined),
                item('Betűtípus és szöveg…', () => showFontDialog(context, p.theme, () {
                      _changed(theme: true);
                      setState(_rebuildReader);
                    }), icon: Icons.text_fields),
                const Divider(height: 1),
                check('Elrendezés szerkesztése', editLayout, () => setState(() => editLayout = !editLayout)),
                check('Hangszín panel', p.layout.showLeft, () {
                  setState(() => p.layout.showLeft = !p.layout.showLeft);
                  _changed();
                }),
                check('Ritmus panel', p.layout.showRight, () {
                  setState(() => p.layout.showRight = !p.layout.showRight);
                  _changed();
                }),
              ], child: const Text('Nézet')),
              SubmenuButton(menuChildren: [
                item('Kapcsolódás…', core == null ? null : _connectDialog, icon: Icons.usb),
                item('Szinkron a hangszerre', song == null ? null : _syncSong, icon: Icons.sync,
                    shortcut: const SingleActivator(LogicalKeyboardKey.f5)),
                const Divider(height: 1),
                item('Stílus Start', _start, icon: Icons.play_arrow),
                item('Stílus Stop', _stop, icon: Icons.stop),
              ], child: const Text('Hangszer')),
              SubmenuButton(menuChildren: [
                item('WAV sample vágása…', core == null ? null : _trimWav, icon: Icons.content_cut),
                item('Hangerő-normalizálás…', () => showNormalizeDialog(context), icon: Icons.equalizer),
              ], child: const Text('Eszközök')),
              SubmenuButton(menuChildren: [
                item('Névjegy és billentyűparancsok', _about, icon: Icons.info_outline),
              ], child: const Text('Súgó')),
            ],
          ),
        ),
        Icon(Icons.circle, size: 11, color: connected ? (testMode ? Colors.amber : Colors.greenAccent) : Colors.redAccent),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _compact ? 90 : 180),
          child: Text(connectionLabel, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: core == null ? null : _connectDialog,
          icon: const Icon(Icons.usb, size: 18),
          label: Text(connected ? 'Újra' : (_compact ? 'MIDI' : 'Kapcsolódás')),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: song == null ? null : _syncSong,
          icon: const Icon(Icons.sync, size: 18),
          label: Text(_compact ? 'Szinkron' : 'Szinkron a hangszerre'),
        ),
        const SizedBox(width: 6),
      ]),
    );
  }

  // ---- elrendezés-szerkesztő sáv ----
  Widget _editBar() => Container(
        color: p.theme.accent.withValues(alpha: 0.18),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          const Icon(Icons.dashboard_customize_outlined, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text('Elrendezés szerkesztése: húzd a kiemelt választóvonalakat a panelek átméretezéséhez.')),
          TextButton.icon(
            onPressed: () {
              setState(() => p.layout.swapSides = !p.layout.swapSides);
              _changed();
            },
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Oldalak cseréje'),
          ),
          TextButton.icon(
            onPressed: () => showThemeDialog(context, p.theme, () => _changed(theme: true)),
            icon: const Icon(Icons.palette_outlined),
            label: const Text('Színek, formák'),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() => p.layout.loadJson(LayoutSettings().toJson()));
              _changed();
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('Alaphelyzet'),
          ),
          FilledButton(onPressed: () => setState(() => editLayout = false), child: const Text('Kész')),
        ]),
      );

  Widget _vSplitter(void Function(double dx) onDrag) {
    if (!editLayout) return const SizedBox(width: 0);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) {
          setState(() => onDrag(d.delta.dx));
        },
        onHorizontalDragEnd: (_) => _changed(),
        child: SizedBox(
          width: 12,
          child: Center(
            child: Container(
              width: 4,
              height: 80,
              decoration: BoxDecoration(color: p.theme.accent, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hSplitter() => MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (d) =>
              setState(() => p.layout.bottomHeight = (p.layout.bottomHeight - d.delta.dy).clamp(118.0, 320.0)),
          onVerticalDragEnd: (_) => _changed(),
          child: SizedBox(
            height: 12,
            child: Center(
              child: Container(
                width: 80,
                height: 4,
                decoration: BoxDecoration(color: p.theme.accent, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
        ),
      );

  Widget _mainRow(LayoutSettings l) {
    final voicesFirst = !l.swapSides;
    Widget side(bool voices) => SizedBox(
          width: voices ? l.leftWidth : l.rightWidth,
          child: _panel(voices ? _voicesPanel() : _rhythmPanel()),
        );
    void resize(bool voices, double dx, bool onLeft) {
      final d = onLeft ? dx : -dx;
      if (voices) {
        l.leftWidth = (l.leftWidth + d).clamp(190.0, 520.0);
      } else {
        l.rightWidth = (l.rightWidth + d).clamp(190.0, 520.0);
      }
    }

    final leftIsVoices = voicesFirst;
    final showLeftPanel = leftIsVoices ? l.showLeft : l.showRight;
    final showRightPanel = leftIsVoices ? l.showRight : l.showLeft;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (showLeftPanel) ...[
        side(leftIsVoices),
        _vSplitter((dx) => resize(leftIsVoices, dx, true)),
      ],
      Expanded(child: _panel(_centerPanel())),
      if (showRightPanel) ...[
        _vSplitter((dx) => resize(!leftIsVoices, dx, false)),
        side(!leftIsVoices),
      ],
    ]);
  }

  Widget _title(String text, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Row(children: [
          Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          const Spacer(),
          if (trailing != null) trailing,
        ]),
      );

  // ---- bal: hangszíncsoportok ----
  Widget _voicesPanel() {
    final t = p.theme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title('Hangszínek'),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: Text('Kattints egy csoportra, majd húzd a hangszínt az alsó sáv V1–V4 helyére.',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(8, 0, 8, 12), children: [
          for (var g = 0; g < voiceGroups.length; g++) ...[
            Material(
              color: openGroup == g ? t.accent.withValues(alpha: 0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => openGroup = openGroup == g ? null : g),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(children: [
                    Icon(voiceGroups[g].icon, size: 20, color: openGroup == g ? t.accent : null),
                    const SizedBox(width: 10),
                    Expanded(child: Text(voiceGroups[g].name, style: const TextStyle(fontSize: 14))),
                    Icon(openGroup == g ? Icons.expand_less : Icons.chevron_right, size: 18),
                  ]),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: openGroup != g
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 4, 10),
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final v in voiceGroups[g].voices)
                          Draggable<VoicePreset>(
                            data: v,
                            feedback: Material(
                              color: Colors.transparent,
                              child: Chip(label: Text(v.name), backgroundColor: t.accent),
                            ),
                            child: PopupMenuButton<int>(
                              tooltip: 'Kattints: hozzárendelés · Húzd: V-helyre',
                              onSelected: (i) => _assignVoice(i, v),
                              itemBuilder: (_) => [
                                for (var i = 0; i < 4; i++)
                                  PopupMenuItem(value: i, child: Text('V${i + 1}-re (${p.slots[i].name})')),
                              ],
                              child: Chip(label: Text(v.name, style: const TextStyle(fontSize: 12))),
                            ),
                          ),
                      ]),
                    ),
            ),
          ],
        ]),
      ),
    ]);
  }

  // ---- jobb: ritmus ----
  Widget _rhythmPanel() {
    final t = p.theme;
    return LayoutBuilder(builder: (ctx, box) {
      final btnW = (box.maxWidth - 28 - 8) / 2;
      Widget sec(Section s) {
        final sel = lastSection == s.code || (lastSection == null && s.code == currentMain);
        return SizedBox(
          width: btnW,
          height: 40,
          child: sel
              ? FilledButton(onPressed: () => _section(s), child: Text(s.label))
              : OutlinedButton(onPressed: () => _section(s), child: Text(s.label)),
        );
      }

      return ListView(padding: const EdgeInsets.only(bottom: 12), children: [
        _title('Ritmus és stílus'),
        if (song != null && song!.style.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(children: [
              Icon(Icons.queue_music, size: 18, color: t.accent),
              const SizedBox(width: 8),
              Expanded(child: Text(song!.style, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: styleRunning ? Colors.green.shade700 : null),
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start', style: TextStyle(fontSize: 17)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop', style: TextStyle(fontSize: 17)),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in intros) sec(s),
            for (final s in mains) sec(s),
            SizedBox(width: btnW, height: 40, child: OutlinedButton(onPressed: _fill, child: const Text('Fill In'))),
            sec(const Section('Break', 0x18)),
            for (final s in endings) sec(s),
          ]),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('A stílust a hangszeren választod ki; innen az indítás, a szakaszok és a tempó vezérelhető.',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
        ),
      ]);
    });
  }

  // ---- közép: dal-oldalak ----
  Widget _centerPanel() {
    final t = p.theme;
    final n = p.songs.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
        child: Row(children: [
          IconButton(
            tooltip: 'Előző dal',
            onPressed: locked || page == 0 ? null : () => _goToPage(page - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(n == 0 ? '0 / 0' : '${page + 1} / $n', style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            tooltip: 'Következő dal',
            onPressed: locked || page >= n - 1 ? null : () => _goToPage(page + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 4),
          // Oldalpöttyök
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var i = 0; i < n; i++)
                  GestureDetector(
                    onTap: locked ? null : () => _goToPage(i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == page ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == page ? t.accent : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: reader,
            builder: (_, __) => Text(
              'Ütem ${(reader.currentBar + 1).floor()} · ${reader.source == ClockSource.midi ? 'MIDI Clock' : 'belső óra'}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: 'Elejére',
            onPressed: () => setState(() {
              reader.reset();
              _scrolls[page]?.jumpTo(0);
            }),
            icon: const Icon(Icons.skip_previous),
          ),
          IconButton(
            tooltip: reader.running ? 'Görgetés megállítása' : 'Görgetés indítása (belső óra)',
            onPressed: () => setState(() {
              if (reader.running) {
                reader.stop();
              } else {
                reader.setBpm(bpm);
                reader.startInternal();
              }
            }),
            icon: Icon(reader.running ? Icons.pause_circle_outline : Icons.play_circle_outline),
          ),
          IconButton(
            tooltip: locked ? 'Oldal feloldása' : 'Oldal lezárása (nem lapoz el)',
            isSelected: locked,
            style: locked ? IconButton.styleFrom(backgroundColor: Colors.orange.withValues(alpha: 0.3)) : null,
            onPressed: () => setState(() => locked = !locked),
            icon: Icon(locked ? Icons.lock : Icons.lock_open),
          ),
          if (isDesktop) ...[
            IconButton(tooltip: 'Dal szerkesztése (Ctrl+E)', onPressed: song == null ? null : _editSong, icon: const Icon(Icons.edit_note)),
            IconButton(tooltip: 'Új dal', onPressed: _addSong, icon: const Icon(Icons.add_circle_outline)),
          ],
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: n == 0
            ? Center(
                child: FilledButton.icon(onPressed: _addSong, icon: const Icon(Icons.add), label: const Text('Első dal hozzáadása')),
              )
            : ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.mouse,
                }),
                child: PageView.builder(
                  controller: pages,
                  physics: locked ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                  itemCount: n,
                  onPageChanged: (i) => setState(() {
                    page = i;
                    _rebuildReader();
                  }),
                  itemBuilder: (ctx, i) => SongPage(
                    song: p.songs[i],
                    layout: i == page && _layout != null ? _layout! : SongLayout(p.songs[i], t),
                    theme: t,
                    scroll: _scrollFor(i),
                    reader: i == page ? reader : null,
                  ),
                ),
              ),
      ),
    ]);
  }

  // ---- alsó vezérlősáv ----
  Widget _bottomBar() {
    final t = p.theme;
    Widget group(String title, Widget child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.7))),
            const SizedBox(height: 6),
            child,
          ]),
        );
    Widget sep() => VerticalDivider(width: 18, indent: 14, endIndent: 14, color: Colors.white.withValues(alpha: 0.12));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        group(
          'Rétegek (V1–V4)',
          _compact
              ? Column(children: [
                  Row(children: [_slotTile(0), _slotTile(1)]),
                  const SizedBox(height: 6),
                  Row(children: [_slotTile(2), _slotTile(3)]),
                ])
              : Row(children: [for (var i = 0; i < p.slots.length; i++) _slotTile(i)]),
        ),
        sep(),
        group(
          _compact ? 'OTS' : 'One Touch Settings',
          Wrap(
            direction: Axis.horizontal,
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 1; i <= 4; i++)
                Tooltip(
                  message: 'OTS-hívás MIDI-n: a modell Data List-je alapján kerül be',
                  child: SizedBox(
                    width: _compact ? 40 : 44,
                    height: _compact ? 40 : 44,
                    child: OutlinedButton(onPressed: null, style: OutlinedButton.styleFrom(padding: EdgeInsets.zero), child: Text('$i')),
                  ),
                ),
            ],
          ).wrapWidth(_compact ? 84 : 200),
        ),
        sep(),
        group(
          'Tempó',
          Row(children: [
            IconButton.filledTonal(onPressed: () => _setTempo(bpm - 1), icon: const Icon(Icons.remove)),
            SizedBox(
              width: 92,
              child: Center(child: Text('${bpm.round()}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700))),
            ),
            IconButton.filledTonal(onPressed: () => _setTempo(bpm + 1), icon: const Icon(Icons.add)),
            const SizedBox(width: 6),
            SizedBox(height: 44, child: OutlinedButton(onPressed: _tapTempo, child: const Text('TAP'))),
          ]),
        ),
        sep(),
        group(
          'Regiszter bankok',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              DropdownButton<int>(
                value: bank.clamp(0, p.banks.length - 1),
                underline: const SizedBox(),
                items: [for (var b = 0; b < p.banks.length; b++) DropdownMenuItem(value: b, child: Text(p.banks[b].name))],
                onChanged: (v) => setState(() {
                  bank = v!;
                  activeReg = null;
                }),
              ),
              IconButton(
                tooltip: 'Új bank',
                onPressed: () {
                  setState(() {
                    p.banks.add(RegBank('Bank ${p.banks.length + 1}'));
                    bank = p.banks.length - 1;
                  });
                  _changed();
                },
                icon: const Icon(Icons.add, size: 18),
              ),
              TextButton.icon(
                onPressed: () => setState(() => saveMode = !saveMode),
                icon: Icon(Icons.save, size: 18, color: saveMode ? Colors.orangeAccent : null),
                label: Text(saveMode ? 'Hová?' : 'Mentés'),
              ),
            ]),
            Wrap(runSpacing: 4, children: [
              for (var i = 0; i < 8; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: SizedBox(
                    width: 40,
                    height: 36,
                    child: activeReg == i
                        ? FilledButton(
                            style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                            onPressed: () => _regButton(i),
                            child: Text('${i + 1}'),
                          )
                        : OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              side: BorderSide(
                                color: saveMode
                                    ? Colors.orangeAccent
                                    : (p.banks[bank.clamp(0, p.banks.length - 1)].slots[i] != null ? t.accent : Colors.white24),
                              ),
                            ),
                            onPressed: () => _regButton(i),
                            child: Text('${i + 1}'),
                          ),
                  ),
                ),
            ]).wrapWidth(_compact ? 176 : 360),
          ]),
        ),
      ]),
    );
  }

  Widget _slotTile(int i) {
    final t = p.theme;
    final s = p.slots[i];
    return DragTarget<VoicePreset>(
      onAcceptWithDetails: (d) => _assignVoice(i, d.data),
      builder: (ctx, cand, _) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Material(
          color: cand.isNotEmpty
              ? t.accent.withValues(alpha: 0.45)
              : (s.enabled ? t.accent.withValues(alpha: 0.20) : Colors.white.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => showSlotDialog(context, i, s, () {
              setState(() {});
              _applyZone(i);
              _changed();
            }, () => _sendVoice(i)),
            child: SizedBox(
              width: _compact ? 140 : 148,
              height: _compact ? 44 : 64,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('V${i + 1}  ${s.name}', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('ch${s.channel + 1} · ${noteName(s.low)}–${noteName(s.high)}',
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
                    ]),
                  ),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: s.enabled,
                      onChanged: (v) {
                        setState(() => s.enabled = v);
                        _applyZone(i);
                        _changed();
                      },
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusLine() => Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Text(
          '${p.name}${dirty ? ' •' : ''}   ·   ${logLines.last}${currentPath != null ? '      ·  $currentPath' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
        ),
      );
}

extension on Widget {
  /// Fix szélességű doboz (a Wrap ennyi helyen tördel)
  Widget wrapWidth(double w) => SizedBox(width: w, child: this);
}
