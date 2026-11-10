// lib/ui/home_page.dart — a SoundNexus Pro főablaka
//  PC (Windows, macOS): szerkesztő mód — minden tervezés, stílus és sablon itt készül
//  Tablet, telefon (Android, iOS): fellépő mód — csak használat, a PC-ről kapott csomaggal
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

import '../i18n/i18n.dart';
import '../midi/midi_backend.dart';
import '../settings.dart';
import '../model/project.dart';
import '../reader/teleprompter_controller.dart';
import '../transfer/transfer.dart';
import '../score/lead_sheet.dart';
import '../score/midi_player.dart';
import 'als_button.dart';
import 'background.dart';
import 'dialogs.dart';
import 'panel_editors.dart';
import 'studio_pages.dart';
import 'style_dialogs.dart';
import 'transfer_dialogs.dart';
import 'song_editor.dart';
import 'song_view.dart';

/// PC = szerkesztő mód. (Teszteléshez az SNX_FORCE_MOBILE=1 környezeti változóval
/// a PC is elindítható fellépő módban.)
bool get isDesktop => AppSettings.instance.effective() == UiMode.pc;

class Section {
  const Section(this.label, this.code);
  final String label;
  final int code;
}

const intros = [Section('Intro A', 0x00), Section('Intro B', 0x01), Section('Intro C', 0x02)];
const mains = [Section('Main A', 0x08), Section('Main B', 0x09), Section('Main C', 0x0A), Section('Main D', 0x0B)];
const endings = [Section('Ending A', 0x20), Section('Ending B', 0x21), Section('Ending C', 0x22)];

List<XTypeGroup> get _projectTypes => [
      XTypeGroup(label: tr('SoundNexus Pro projekt'), extensions: const [Project.fileExtension, ...Project.legacyExtensions]),
    ];

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.project,
    required this.initialPath,
    required this.onProjectReplaced,
    required this.onThemeChanged,
    required this.onSettingsChanged,
  });

  final Project project;
  final String? initialPath;
  final ValueChanged<Project> onProjectReplaced;
  final VoidCallback onThemeChanged;
  final VoidCallback onSettingsChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  Project get p => widget.project;

  // Hangszer
  late final MidiBackend midi = MidiBackend.create();
  String? get coreError => midi.error;
  bool connected = false, testMode = false;
  String connectionLabel = tr('Nincs kapcsolat');

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
  LeadSheetLayout? _sheet;
  final _scoreStrip = ScrollController();
  late final player = MidiPlayer(midi);
  late TeleprompterController reader;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  // Felület
  bool editLayout = isDesktop && Platform.environment['SNX_EDIT_MODE'] == '1';
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

  final logLines = <String>[tr('SoundNexus Pro elindult.')];

  // -------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    currentPath = widget.initialPath;
    _rebuildReader();
    _ticker = createTicker(_onTick)..start();
    // Teszteléshez (CI képernyőképek): SNX_OPEN=sample | loop | voices | rhythm | bottom
    final open = AppSettings.platformIsDesktop ? Platform.environment['SNX_OPEN'] : null;
    if (open != null && open.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final page = switch (open) {
          'sample' => SampleStudioPage(project: p) as Widget,
          'loop' => LoopStudioPage(project: p),
          'voices' => VoicePanelEditorPage(project: p, onChanged: _editorChanged),
          'rhythm' => RhythmPanelEditorPage(project: p, onChanged: _editorChanged),
          'bottom' => BottomBarEditorPage(project: p, onChanged: _editorChanged),
          _ => null,
        };
        if (page != null) _openEditor(page);
        switch (open) {
          case 'settings':
            _settingsDialog();
          case 'song':
            _editSong();
          case 'theme':
            showThemeDialog(context, p, () => _changed(theme: true));
          case 'send':
            showSendDialog(context, p);
          case 'connect':
            _connectDialog();
          case 'slot':
            showSlotDialog(context, 0, p.slots[0], () {}, () {});
          case 'about':
            _about();
        }
      });
    }
    if (!AppSettings.platformIsDesktop) {
      // Fellépő mód: az utoljára fogadott csomag betöltése
      loadShowOnDevice().then((show) {
        if (show != null && mounted) widget.onProjectReplaced(show);
      });
    }
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
    player.stop();
    midi.close();
    _scoreStrip.dispose();
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
    if (!AppSettings.platformIsDesktop) return; // a mobilon a fogadott csomag a forrás
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
    _sheet = s.score == null ? null : LeadSheetLayout(s, p.theme);
    bpm = s.bpm;
    final useScore = p.readerView == ReaderView.score && _sheet != null;
    final anchors = useScore
        ? [for (final a in _sheet!.anchors) Anchor(a.bar, a.y + SongLayout.headerHeight)]
        : _layout!.anchors;
    reader = TeleprompterController(anchors, beatsPerBar: s.beatsPerBar, lookAheadBars: 0, bpm: s.bpm);
  }

  void _setView(ReaderView v) {
    setState(() {
      p.readerView = v;
      _rebuildReader();
    });
    if (isDesktop) _changed();
  }

  /// A dalhoz csatolt kotta (MIDI) lejátszása a hangszeren, a görgetéssel együtt
  void _togglePlay() {
    if (player.playing) {
      player.stop();
      reader.stop();
      setState(() {});
      log(tr('Lejátszás leállítva.'));
      return;
    }
    final sc = song?.score;
    if (sc?.midiB64 == null) {
      log(tr('Ehhez a dalhoz nincs csatolt MIDI. A PC-n: Dal szerkesztése → Kotta → MIDI importálása.'));
      return;
    }
    if (!connected) {
      log(tr('Előbb kapcsolódj a hangszerhez.'));
      return;
    }
    player.onFinished = () {
      reader.stop();
      if (mounted) setState(() {});
    };
    player.play(sc!, targetBpm: bpm);
    reader
      ..reset()
      ..setBpm(bpm)
      ..startInternal();
    setState(() {});
    log(tr('Lejátszás a hangszeren: {0} ({1} BPM)', [song!.title, bpm.round()]));
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastTick = elapsed;
    reader.tick(dt, midi.nowUs());
    final sc = _scrolls[page];
    if (sc != null && sc.hasClients && reader.running) {
      final view = sc.position.viewportDimension;
      final target = (reader.scrollY - view * 0.30).clamp(0.0, sc.position.maxScrollExtent);
      if ((sc.offset - target).abs() > 0.5) sc.jumpTo(target);
    }
    final sheet = _sheet;
    if (p.readerView == ReaderView.both && sheet != null && _scoreStrip.hasClients) {
      final target = ((reader.currentBar / sheet.barsPerSystem).floor() * sheet.systemHeight)
          .clamp(0.0, _scoreStrip.position.maxScrollExtent);
      if ((_scoreStrip.offset - target).abs() > 0.5) _scoreStrip.jumpTo(target);
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
        title: Text(tr('Mentetlen változások')),
        content: Text(tr('A projekt módosult. Folytatod mentés nélkül?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Mégse'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Folytatás mentés nélkül'))),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _newProject() async {
    if (!await _confirmDiscard()) return;
    final np = Project()
      ..songs.add(Song(title: tr('Új dal'), body: tr('{Main A}\n[C]Ide írd a szöveget')));
    np.theme.loadJson(p.theme.toJson());
    np.layout.loadJson(p.layout.toJson());
    currentPath = null;
    dirty = false;
    widget.onProjectReplaced(np);
    log(tr('Új projekt.'));
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
      log(tr('Megnyitva: {0}', [f.path]));
    } catch (e) {
      log(tr('A fájl nem SoundNexus Pro projekt vagy sérült: {0}', [e]));
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
      p.pruneImages();
      await File(path).writeAsString(p.toFileString());
      setState(() {
        currentPath = path;
        dirty = false;
      });
      _writeAutosave();
      log(tr('Mentve: {0}', [path]));
    } catch (e) {
      log(tr('A mentés nem sikerült: {0}', [e]));
    }
  }

  Future<void> _importLyrics() async {
    final f = await openFile(acceptedTypeGroups: [XTypeGroup(label: tr('Szöveg'), extensions: ['txt', 'cho', 'pro'])]);
    if (f == null) return;
    try {
      final text = (await File(f.path).readAsString()).replaceAll('\r\n', '\n');
      final title = f.name.replaceAll(RegExp(r'\.(txt|cho|pro)$', caseSensitive: false), '');
      setState(() => p.songs.add(Song(title: title, body: text)));
      _changed();
      _goToPage(p.songs.length - 1);
      log(tr('Dal importálva: {0}', [title]));
    } catch (e) {
      log(tr('A szöveg nem olvasható (UTF-8 kell): {0}', [e]));
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
    final s = Song(title: tr('Új dal'), body: tr('{Main A}\n[C]Ide írd a szöveget'));
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
        title: Text(tr('Dal törlése')),
        content: Text(tr('Biztosan törlöd: „{0}”?', [s.title])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Mégse'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Törlés'))),
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
    var (ins, outs) = await midi.ports();
    if (!mounted) return;
    bool isYamaha(AlsMidiPort port) {
      final l = port.name.toLowerCase();
      return l.contains('genos') || l.contains('tyros') || l.contains('yamaha') || l.contains('psr');
    }

    int? pick(List<AlsMidiPort> l) {
      final y = l.indexWhere(isYamaha);
      return y >= 0 ? y : (l.isEmpty ? null : 0);
    }

    int? inSel = pick(ins), outSel = pick(outs);
    var scanning = false;
    final mobile = !isDesktop;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          Future<void> refresh({bool bt = false}) async {
            setD(() => scanning = true);
            final r = await midi.ports(scanBluetooth: bt);
            setD(() {
              (ins, outs) = r;
              inSel = pick(ins);
              outSel = pick(outs);
              scanning = false;
            });
          }

          return AlertDialog(
            title: Text(tr('Kapcsolódás a hangszerhez')),
            content: SizedBox(
              width: 460,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (ins.isEmpty && outs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(mobile
                        ? tr('Nem található MIDI-eszköz. Csatlakoztasd a hangszert USB-C / OTG kábellel (a hangszer USB TO HOST aljzatába), vagy keress Bluetooth MIDI adaptert.')
                        : tr('Nem található MIDI-eszköz. Csatlakoztasd a hangszert USB-kábellel (USB TO HOST), kapcsold be, majd kattints a Frissítés gombra.')),
                  ),
                if (mobile) ...[
                  Text(tr('Eszköz:')),
                  DropdownButton<int>(
                    isExpanded: true,
                    value: outSel,
                    hint: Text(tr('nincs')),
                    items: [
                      for (var i = 0; i < outs.length; i++)
                        DropdownMenuItem(value: i, child: Text('${outs[i].bluetooth ? '(BT) ' : ''}${outs[i].name}')),
                    ],
                    onChanged: (v) => setD(() => outSel = inSel = v),
                  ),
                ] else ...[
                  Text(tr('MIDI bemenet (a hangszerről):')),
                  DropdownButton<int>(
                    isExpanded: true,
                    value: inSel,
                    hint: Text(tr('nincs')),
                    items: [for (var i = 0; i < ins.length; i++) DropdownMenuItem(value: i, child: Text(ins[i].name))],
                    onChanged: (v) => setD(() => inSel = v),
                  ),
                  const SizedBox(height: 8),
                  Text(tr('MIDI kimenet (a hangszer felé):')),
                  DropdownButton<int>(
                    isExpanded: true,
                    value: outSel,
                    hint: Text(tr('nincs')),
                    items: [for (var i = 0; i < outs.length; i++) DropdownMenuItem(value: i, child: Text(outs[i].name))],
                    onChanged: (v) => setD(() => outSel = v),
                  ),
                ],
                if (scanning) const LinearProgressIndicator(),
              ]),
            ),
            actions: [
              TextButton(onPressed: scanning ? null : () => refresh(), child: Text(tr('Frissítés'))),
              if (mobile)
                TextButton.icon(
                  onPressed: scanning ? null : () => refresh(bt: true),
                  icon: const Icon(Icons.bluetooth_searching),
                  label: Text(tr('Bluetooth keresés')),
                ),
              if (midi.supportsTestMode)
                TextButton(onPressed: () => Navigator.pop(ctx, 'test'), child: Text(tr('Teszt mód'))),
              FilledButton(
                onPressed: outSel == null ? null : () => Navigator.pop(ctx, 'connect'),
                child: Text(tr('Kapcsolódás')),
              ),
            ],
          );
        },
      ),
    );
    if (result == null) return;
    final ok = result == 'test'
        ? await midi.connect(testMode: true)
        : await midi.connect(
            input: inSel == null || inSel! >= ins.length ? null : ins[inSel!],
            output: outSel == null || outSel! >= outs.length ? null : outs[outSel!],
          );
    setState(() {
      connected = ok;
      testMode = result == 'test';
      connectionLabel = !ok ? tr('Kapcsolódási hiba') : (testMode ? tr('Teszt mód') : outs[outSel!].name);
    });
    if (!ok) {
      log(tr('Nem sikerült kapcsolódni a hangszerhez.'));
      return;
    }
    midi.onRealtime(_onRealtime);
    for (var i = 0; i < p.slots.length; i++) {
      _applyZone(i);
    }
    log(testMode ? tr('Teszt mód: a parancsok nem mennek hangszerre.') : tr('Kapcsolódva: {0}', [connectionLabel]));
  }

  void _applyZone(int i) {
    final s = p.slots[i];
    if (connected) {
      midi.setZone(i,
          enabled: s.enabled, low: s.low, high: s.high, velLow: s.velLow,
          transpose: s.transpose, velCurve: s.curve, outChannel: s.channel);
    }
  }

  void _sendVoice(int i) {
    final s = p.slots[i];
    if (!connected) {
      log(tr('Előbb kapcsolódj a hangszerhez (Hangszer → Kapcsolódás).'));
      return;
    }
    midi.voice(s.channel, s.msb, s.lsb, s.program, s.volume);
    log(tr('V{0}: {1} elküldve (ch{2})', [i + 1, s.name, s.channel + 1]));
  }

  void _assignVoice(int i, VoicePreset v) {
    setState(() => p.slots[i].applyPreset(v));
    _applyZone(i);
    if (connected) _sendVoice(i);
    _changed();
    log('V${i + 1} ← ${v.name}');
  }

  void _start() {
    if (connected) midi.styleStart();
    setState(() => styleRunning = true);
    if (!connected) {
      reader.setBpm(bpm);
      reader.startInternal();
    }
  }

  void _stop() {
    if (connected) midi.styleStop();
    reader.stop();
    setState(() => styleRunning = false);
  }

  void _section(Section s) {
    if (connected) midi.section(s.code);
    setState(() {
      lastSection = s.code;
      if (s.code >= 0x08 && s.code <= 0x0B) currentMain = s.code;
    });
  }

  void _fill() {
    if (connected) midi.section(0x10 + (currentMain - 0x08));
    log('Fill In');
  }

  void _setTempo(double v, {bool send = true}) {
    setState(() => bpm = v.roundToDouble().clamp(30.0, 300.0));
    reader.setBpm(bpm);
    if (send && connected) midi.tempo(bpm);
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
        if (connected) midi.voice(p.slots[i].channel, p.slots[i].msb, p.slots[i].lsb, p.slots[i].program, p.slots[i].volume);
      }
    }
    reader.reset();
    final msg = connected
        ? tr('Elküldve: {0} BPM, {1}, {2} réteg{3}', [s.bpm.round(), mains.firstWhere((m) => m.code == s.mainSection, orElse: () => mains.first).label, layers, s.style.isNotEmpty ? tr('. Stílus: {0} – ezt válaszd ki a hangszeren.', [s.style]) : '.'])
        : tr('Nincs hangszer csatlakoztatva – a beállítás csak a programban történt meg.');
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
      log(tr('Mentve: {0} / {1}', [p.banks[bank].name, i + 1]));
      return;
    }
    _recallReg(bank, i);
  }

  void _recallReg(int b, int i, {bool quiet = false}) {
    if (b >= p.banks.length) return;
    final r = p.banks[b].slots[i];
    if (r == null) {
      if (!quiet) log(tr('{0} / {1} üres. Mentéshez: Mentés, majd a szám.', [p.banks[b].name, i + 1]));
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
        midi.voice(p.slots[k].channel, p.slots[k].msb, p.slots[k].lsb, p.slots[k].program, p.slots[k].volume);
      }
    }
    if (!quiet) log(tr('Behívva: {0} / {1}', [p.banks[b].name, i + 1]));
  }

  // ---- eszközök ----
  /// Nyelv és megjelenési mód
  Future<void> _settingsDialog() async {
    final st = AppSettings.instance;
    var lang = st.lang;
    var mode = st.mode;
    final desktop = AppSettings.platformIsDesktop;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(tr('Beállítások')),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Nyelv'), style: const TextStyle(fontWeight: FontWeight.w600)),
              DropdownButton<String>(
                isExpanded: true,
                value: lang,
                items: [for (final e in languages.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setD(() => lang = v!),
              ),
              const SizedBox(height: 16),
              Text(tr('Megjelenési mód'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SegmentedButton<UiMode>(
                segments: [
                  if (desktop) ButtonSegment(value: UiMode.pc, icon: const Icon(Icons.desktop_windows), label: Text(tr('PC'))),
                  if (!desktop) ButtonSegment(value: UiMode.auto, icon: const Icon(Icons.auto_mode), label: Text(tr('Automatikus'))),
                  ButtonSegment(value: UiMode.tablet, icon: const Icon(Icons.tablet_mac), label: Text(tr('Tablet'))),
                  ButtonSegment(value: UiMode.phone, icon: const Icon(Icons.smartphone), label: Text(tr('Telefon'))),
                ],
                selected: {desktop && mode == UiMode.auto ? UiMode.pc : (!desktop && mode == UiMode.pc ? UiMode.auto : mode)},
                onSelectionChanged: (v) => setD(() => mode = v.first),
              ),
              const SizedBox(height: 8),
              Text(
                desktop
                    ? tr('PC mód: szerkesztés és tervezés. Tablet és Telefon: előnézet, pontosan úgy, ahogy a mobilon fog megjelenni.')
                    : tr('Tablet: három oszlop egymás mellett. Telefon: középen a dal, a hangszínek és a ritmus oldalról kihúzható.'),
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65)),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Mégse'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Alkalmaz'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    st.lang = lang;
    st.mode = mode;
    widget.onSettingsChanged();
  }

  void _editorChanged() {
    _changed(theme: true);
    setState(_rebuildReader);
  }

  Future<void> _openEditor(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(_rebuildReader);
  }

  void _about() => showAboutDialog(
        context: context,
        applicationName: 'SoundNexus Pro',
        applicationVersion: '0.5',
        children: [
          Text(tr('Szerkesztő és élő vezérlő program Yamaha Genos 2, Genos, Tyros 5, Tyros 4 és PSR-SX hangszerekhez.')),
          SizedBox(height: 8),
          Text(tr('Billentyűparancsok: Ctrl+N új · Ctrl+O megnyitás · Ctrl+S mentés · Ctrl+Shift+S mentés másként · Ctrl+E dal szerkesztése · F5 szinkron · ←/→ lapozás · Szóköz Start/Stop')),
        ],
      );

  // -------------------------------------------------------------------------
  // Felület
  // -------------------------------------------------------------------------
  bool get _compact => MediaQuery.sizeOf(context).width < 1300;
  bool get _phone => AppSettings.instance.effective(width: MediaQuery.sizeOf(context).width) == UiMode.phone;
  bool get _canEdit => isDesktop; // minden tervezés és szerkesztés csak PC-n

  SingleActivator _key(LogicalKeyboardKey k, {bool shift = false}) =>
      SingleActivator(k, control: !Platform.isMacOS, meta: Platform.isMacOS, shift: shift);

  void _editItem(String id, String label) =>
      showItemStyleDialog(context, p, id, label, () => _changed(theme: true));

  @override
  Widget build(BuildContext context) {
    final l = p.layout;
    return CallbackShortcuts(
      bindings: {
        if (_canEdit) ...{
          _key(LogicalKeyboardKey.keyN): _newProject,
          _key(LogicalKeyboardKey.keyO): _openProject,
          _key(LogicalKeyboardKey.keyS): () => _saveProject(),
          _key(LogicalKeyboardKey.keyS, shift: true): () => _saveProject(saveAs: true),
          _key(LogicalKeyboardKey.keyE): _editSong,
        },
        const SingleActivator(LogicalKeyboardKey.f5): _syncSong,
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (!locked) _goToPage(page + 1);
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (!locked) _goToPage(page - 1);
        },
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
          drawer: _phone ? Drawer(width: 300, child: SafeArea(child: _voicesPanel())) : null,
          endDrawer: _phone ? Drawer(width: 300, child: SafeArea(child: _rhythmPanel())) : null,
          body: AppBackground(
            project: p,
            child: SafeArea(
              child: Column(children: [
                if (isDesktop) _topBar(context) else _mobileTopBar(),
                if (coreError != null)
                  Container(
                    width: double.infinity,
                    color: Colors.red.withValues(alpha: 0.25),
                    padding: const EdgeInsets.all(8),
                    child: Text(coreError!),
                  ),
                if (editLayout) _editBar(),
                Expanded(child: _phone ? _panel('center', _centerPanel()) : _mainRow(l)),
                if (editLayout) _hSplitter(),
                SizedBox(
                  height: _phone ? 132 : l.bottomHeight,
                  child: _panel('bottom', _bottomBar(), margin: const EdgeInsets.fromLTRB(6, 0, 6, 0)),
                ),
                _statusLine(),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// Egy sáv a saját stílusával; szerkesztő módban „Sáv stílusa” gombbal
  Widget _panel(String key, Widget child, {EdgeInsets margin = const EdgeInsets.all(6)}) {
    return Container(
      margin: margin,
      decoration: panelDecoration(p, key, editMode: editLayout),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(panelRadius(p, key)),
        child: Stack(children: [
          Positioned.fill(child: child),
          if (editLayout)
            Positioned(
              right: 4,
              bottom: 4,
              child: IconButton.filled(
                tooltip: tr('Sáv stílusa: {0}', [tr(panelNames[key] ?? key)]),
                style: IconButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
                onPressed: () => showPanelStyleDialog(context, p, key, () => _changed(theme: true)),
                icon: const Icon(Icons.format_paint, size: 18),
              ),
            ),
        ]),
      ),
    );
  }

  // ---- PC: felső menüsor ----
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
                item(tr('Új projekt'), _newProject, icon: Icons.note_add_outlined, shortcut: _key(LogicalKeyboardKey.keyN)),
                item(tr('Megnyitás…'), _openProject, icon: Icons.folder_open_outlined, shortcut: _key(LogicalKeyboardKey.keyO)),
                const Divider(height: 1),
                item(tr('Mentés'), () => _saveProject(), icon: Icons.save_outlined, shortcut: _key(LogicalKeyboardKey.keyS)),
                item(tr('Mentés másként…'), () => _saveProject(saveAs: true), icon: Icons.save_as_outlined,
                    shortcut: _key(LogicalKeyboardKey.keyS, shift: true)),
                const Divider(height: 1),
                item(tr('Küldés tabletre / telefonra…'), () => showSendDialog(context, p), icon: Icons.send_to_mobile),
                item(tr('Dalszöveg importálása (.txt)…'), _importLyrics, icon: Icons.file_download_outlined),
                const Divider(height: 1),
                item(tr('Kilépés'), _exit, icon: Icons.logout),
              ], child: Text(tr('Fájl'))),
              SubmenuButton(menuChildren: [
                item(tr('Új dal…'), _addSong, icon: Icons.add),
                item(tr('Dal szerkesztése…'), song == null ? null : _editSong, icon: Icons.edit_outlined,
                    shortcut: _key(LogicalKeyboardKey.keyE)),
                item(tr('Dal törlése'), song == null ? null : _deleteSong, icon: Icons.delete_outline),
                const Divider(height: 1),
                item(tr('Dal előrébb'), page > 0 ? () => _moveSong(-1) : null, icon: Icons.arrow_back),
                item(tr('Dal hátrébb'), page < p.songs.length - 1 ? () => _moveSong(1) : null, icon: Icons.arrow_forward),
              ], child: Text(tr('Szerkesztés'))),
              SubmenuButton(menuChildren: [
                item(tr('Téma és színek…'), () => showThemeDialog(context, p, () => _changed(theme: true)),
                    icon: Icons.palette_outlined),
                item(tr('Betűtípus és szöveg…'), () => showFontDialog(context, p.theme, () {
                      _changed(theme: true);
                      setState(_rebuildReader);
                    }), icon: Icons.text_fields),
                item(tr('Hangszín-panel szerkesztő…'), () => _openEditor(VoicePanelEditorPage(project: p, onChanged: _editorChanged)),
                    icon: Icons.piano),
                item(tr('Ritmus-panel szerkesztő…'), () => _openEditor(RhythmPanelEditorPage(project: p, onChanged: _editorChanged)),
                    icon: Icons.queue_music),
                item(tr('Alsó vezérlősáv szerkesztő…'), () => _openEditor(BottomBarEditorPage(project: p, onChanged: _editorChanged)),
                    icon: Icons.view_day),
                SubmenuButton(menuChildren: [
                  for (final k in panelKeys)
                    item(tr(panelNames[k]!), () => showPanelStyleDialog(context, p, k, () => _changed(theme: true)),
                        icon: Icons.format_paint),
                ], leadingIcon: const Icon(Icons.dashboard_outlined, size: 18), child: Text(tr('Sávok stílusa'))),
                const Divider(height: 1),
                item(tr('Nyelv és megjelenési mód…'), _settingsDialog, icon: Icons.language),
                const Divider(height: 1),
                check(tr('Felület szerkesztése (gombok, sávok)'), editLayout, () => setState(() => editLayout = !editLayout)),
                check(tr('Hangszín panel'), p.layout.showLeft, () {
                  setState(() => p.layout.showLeft = !p.layout.showLeft);
                  _changed();
                }),
                check(tr('Ritmus panel'), p.layout.showRight, () {
                  setState(() => p.layout.showRight = !p.layout.showRight);
                  _changed();
                }),
              ], child: Text(tr('Nézet'))),
              SubmenuButton(menuChildren: [
                item(tr('Kapcsolódás…'), coreError != null ? null : _connectDialog, icon: Icons.usb),
                item(tr('Szinkron a hangszerre'), song == null ? null : _syncSong, icon: Icons.sync,
                    shortcut: const SingleActivator(LogicalKeyboardKey.f5)),
                const Divider(height: 1),
                item(tr('Stílus Start'), _start, icon: Icons.play_arrow),
                item(tr('Stílus Stop'), _stop, icon: Icons.stop),
              ], child: Text(tr('Hangszer'))),
              SubmenuButton(menuChildren: [
                item('SoundNexus Sample Studio…', coreError != null ? null : () => _openEditor(SampleStudioPage(project: p)),
                    icon: Icons.content_cut),
                item('SoundNexus Loop Studio…', coreError != null ? null : () => _openEditor(LoopStudioPage(project: p)),
                    icon: Icons.all_inclusive),
                item(tr('Hangerő-normalizálás…'), () => showNormalizeDialog(context), icon: Icons.equalizer),
              ], child: Text(tr('Eszközök'))),
              SubmenuButton(menuChildren: [
                item(tr('Névjegy és billentyűparancsok'), _about, icon: Icons.info_outline),
              ], child: Text(tr('Súgó'))),
            ],
          ),
        ),
        IconButton(tooltip: tr('Beállítások: nyelv, PC / Tablet / Telefon mód'), onPressed: _settingsDialog, icon: const Icon(Icons.settings)),
        Icon(Icons.circle, size: 11, color: connected ? (testMode ? Colors.amber : Colors.greenAccent) : Colors.redAccent),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _compact ? 90 : 180),
          child: Text(connectionLabel, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: coreError != null ? null : _connectDialog,
          icon: const Icon(Icons.usb, size: 18),
          label: Text(connected ? tr('Újra') : (_compact ? 'MIDI' : tr('Kapcsolódás'))),
        ),
        const SizedBox(width: 8),
        if (!_compact) ...[
          OutlinedButton.icon(
            onPressed: () => showSendDialog(context, p),
            icon: const Icon(Icons.send_to_mobile, size: 18),
            label: Text(tr('Küldés')),
          ),
          const SizedBox(width: 8),
        ],
        FilledButton.icon(
          onPressed: song == null ? null : _syncSong,
          icon: const Icon(Icons.sync, size: 18),
          label: Text(_compact ? tr('Szinkron') : tr('Szinkron a hangszerre')),
        ),
        const SizedBox(width: 6),
      ]),
    );
  }

  // ---- Mobil: fellépő mód fejléce ----
  Widget _mobileTopBar() {
    final t = p.theme;
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.black.withValues(alpha: 0.25),
      child: Row(children: [
        if (_phone)
          Builder(
            builder: (ctx) => IconButton(
              tooltip: tr('Hangszínek'),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              icon: const Icon(Icons.piano),
            ),
          ),
        Icon(Icons.graphic_eq, color: t.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(p.sourceInfo == null ? tr('Fellépő mód · bemutató') : tr('Fellépő mód · {0}', [p.sourceInfo]),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
          ]),
        ),
        Icon(Icons.circle, size: 11, color: connected ? Colors.greenAccent : Colors.redAccent),
        IconButton(tooltip: tr('Beállítások: nyelv, Tablet / Telefon mód'), onPressed: _settingsDialog, icon: const Icon(Icons.settings)),
        IconButton(tooltip: tr('Kapcsolódás a hangszerhez'), onPressed: _connectDialog, icon: const Icon(Icons.usb)),
        IconButton(
          tooltip: tr('Fogadás PC-ről'),
          onPressed: () async {
            final show = await showReceiveDialog(context);
            if (show != null) {
              widget.onProjectReplaced(show);
              log(tr('Fogadva: {0}', [show.name]));
            }
          },
          icon: const Icon(Icons.download_for_offline_outlined),
        ),
        FilledButton.icon(
          onPressed: song == null ? null : _syncSong,
          icon: const Icon(Icons.sync, size: 18),
          label: Text(tr('Szinkron')),
        ),
        if (_phone)
          Builder(
            builder: (ctx) => IconButton(
              tooltip: tr('Ritmus'),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              icon: const Icon(Icons.queue_music),
            ),
          ),
      ]),
    );
  }

  // ---- PC: felület-szerkesztő sáv ----
  Widget _editBar() => Container(
        color: p.theme.accent.withValues(alpha: 0.18),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          const Icon(Icons.dashboard_customize_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tr('Felület szerkesztése: kattints bármely gombra a kinézetéhez (kép, felirat, szín, méret); a sávok sarkában lévő narancs ecsettel az egész sávot alakítod; a választóvonalak húzhatók.')),
          ),
          TextButton.icon(
            onPressed: () => _openEditor(BottomBarEditorPage(project: p, onChanged: _editorChanged)),
            icon: const Icon(Icons.view_day),
            label: Text(tr('Alsó sáv…')),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() => p.layout.swapSides = !p.layout.swapSides);
              _changed();
            },
            icon: const Icon(Icons.swap_horiz),
            label: Text(tr('Oldalak cseréje')),
          ),
          TextButton.icon(
            onPressed: () => showThemeDialog(context, p, () => _changed(theme: true)),
            icon: const Icon(Icons.palette_outlined),
            label: Text(tr('Téma')),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() => p.layout.loadJson(LayoutSettings().toJson()));
              _changed();
            },
            icon: const Icon(Icons.restart_alt),
            label: Text(tr('Méretek alaphelyzetbe')),
          ),
          FilledButton(onPressed: () => setState(() => editLayout = false), child: Text(tr('Kész'))),
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
              setState(() => p.layout.bottomHeight = (p.layout.bottomHeight - d.delta.dy).clamp(118.0, 360.0)),
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
          child: _panel(voices ? 'left' : 'right', voices ? _voicesPanel() : _rhythmPanel()),
        );
    void resize(bool voices, double dx, bool onLeft) {
      final d = onLeft ? dx : -dx;
      if (voices) {
        l.leftWidth = (l.leftWidth + d).clamp(190.0, 560.0);
      } else {
        l.rightWidth = (l.rightWidth + d).clamp(190.0, 560.0);
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
      Expanded(child: _panel('center', _centerPanel())),
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
  void _voiceMenu(BuildContext ctx, VoicePreset v) {
    final box = ctx.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy + box.size.height, pos.dx + box.size.width, 0),
      items: [
        for (var i = 0; i < 4; i++) PopupMenuItem(value: i, child: Text('V${i + 1}-re  (${p.slots[i].name})')),
      ],
    ).then((i) {
      if (i != null) _assignVoice(i, v);
    });
  }

  Widget _voicesPanel() {
    final edit = editLayout && _canEdit;
    final groups = p.voiceGroups;
    final cols = p.leftColumns.clamp(1, 3);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(tr('Hangszínek'),
          trailing: _canEdit
              ? IconButton(
                  tooltip: tr('Hangszín-panel szerkesztő'),
                  icon: const Icon(Icons.tune, size: 18),
                  onPressed: () => _openEditor(VoicePanelEditorPage(project: p, onChanged: _editorChanged)),
                )
              : null),
      Expanded(
        child: LayoutBuilder(builder: (ctx, box) {
          final w = (box.maxWidth - 16 - (cols - 1) * 6) / cols;
          final rows = <Widget>[];
          for (var r = 0; r < groups.length; r += cols) {
            final row = [for (var g = r; g < r + cols && g < groups.length; g++) g];
            rows.add(Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                for (final g in row)
                  Padding(
                    padding: EdgeInsets.only(right: g == row.last ? 0 : 6),
                    child: AlsButton(
                      project: p,
                      panel: 'left',
                      id: 'group:${groups[g].name}',
                      label: tr(groups[g].name),
                      icon: groups[g].icon,
                      width: w,
                      height: 44,
                      alignLeft: cols == 1,
                      selected: openGroup == g,
                      editMode: edit,
                      onEdit: () => _editItem('group:${groups[g].name}', groups[g].name),
                      onTap: () => setState(() => openGroup = openGroup == g ? null : g),
                    ),
                  ),
              ]),
            ));
            final open = openGroup;
            if (open != null && row.contains(open) && open < groups.length) {
              rows.add(Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final v in groups[open].voices)
                    Draggable<VoicePreset>(
                      data: v,
                      maxSimultaneousDrags: edit ? 0 : 1,
                      feedback: Material(color: Colors.transparent, child: Chip(label: Text(v.name), backgroundColor: p.theme.accent)),
                      child: Builder(
                        builder: (bctx) => AlsButton(
                          project: p,
                          panel: 'left',
                          id: 'voice:${v.name}',
                          label: v.name,
                          width: w,
                          height: 34,
                          editMode: edit,
                          onEdit: () => _editItem('voice:${v.name}', v.name),
                          onTap: () => _voiceMenu(bctx, v),
                        ),
                      ),
                    ),
                ]),
              ));
            }
          }
          return ListView(padding: const EdgeInsets.fromLTRB(8, 0, 8, 12), children: rows);
        }),
      ),
    ]);
  }

  /// Egy ritmusgomb felirata, művelete, kijelölt állapota és ikonja
  (String, VoidCallback?, bool, IconData?) _rhythmAction(String k) {
    (String, VoidCallback?, bool, IconData?) sec(String label, int code) =>
        (label, () => _section(Section(label, code)), lastSection == code || (lastSection == null && code == currentMain), null);
    return switch (k) {
      'start' => ('Start', _start, styleRunning, Icons.play_arrow),
      'stop' => ('Stop', _stop, false, Icons.stop),
      'introA' => sec('Intro A', 0x00),
      'introB' => sec('Intro B', 0x01),
      'introC' => sec('Intro C', 0x02),
      'mainA' => sec('Main A', 0x08),
      'mainB' => sec('Main B', 0x09),
      'mainC' => sec('Main C', 0x0A),
      'mainD' => sec('Main D', 0x0B),
      'break' => sec('Break', 0x18),
      'endingA' => sec('Ending A', 0x20),
      'endingB' => sec('Ending B', 0x21),
      'endingC' => sec('Ending C', 0x22),
      'fill' => ('Fill In', _fill, false, null),
      'sync' => (tr('Szinkron'), song == null ? null : _syncSong, false, Icons.sync),
      'tap' => ('TAP', _tapTempo, false, Icons.touch_app),
      'tempoDown' => (tr('Tempó −'), () => _setTempo(bpm - 1), false, Icons.remove),
      'tempoUp' => (tr('Tempó +'), () => _setTempo(bpm + 1), false, Icons.add),
      'playScore' => (player.playing ? tr('Leállítás') : tr('Dal lejátszása'), _togglePlay, player.playing, player.playing ? Icons.stop_circle : Icons.play_circle),
      'lock' => (locked ? tr('Feloldás') : tr('Lakat'), () => setState(() => locked = !locked), locked, locked ? Icons.lock : Icons.lock_open),
      _ => (k, null, false, null),
    };
  }

  Widget _rhythmPanel() {
    final t = p.theme;
    final edit = editLayout && _canEdit;
    final cols = p.rhythmColumns.clamp(1, 3);
    return LayoutBuilder(builder: (ctx, box) {
      final avail = box.maxWidth.isFinite ? box.maxWidth : 280;
      final btnW = (avail - 28 - (cols - 1) * 8) / cols;
      return ListView(padding: const EdgeInsets.only(bottom: 12), children: [
        _title(tr('Ritmus és stílus'),
            trailing: _canEdit
                ? IconButton(
                    tooltip: tr('Ritmus-panel szerkesztő'),
                    icon: const Icon(Icons.tune, size: 18),
                    onPressed: () => _openEditor(RhythmPanelEditorPage(project: p, onChanged: _editorChanged)),
                  )
                : null),
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
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in p.rhythmItems)
              Builder(builder: (_) {
                final (label, onTap, sel, icon) = _rhythmAction(k);
                final big = k == 'start' || k == 'stop';
                return AlsButton(
                  project: p,
                  panel: 'right',
                  id: 'r:$k',
                  label: label,
                  icon: icon,
                  width: btnW,
                  height: big ? 54 : 40,
                  selected: sel,
                  editMode: edit,
                  onEdit: () => _editItem('r:$k', tr(rhythmCatalog[k] ?? k)),
                  onTap: onTap,
                );
              }),
          ]),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(tr('A stílust a hangszeren választod ki; innen az indítás, a szakaszok és a tempó vezérelhető.'),
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
        ),
      ]);
    });
  }

  // ---- közép: dal-oldalak (szöveg / kotta / mindkettő) ----
  Widget _songPage(int i) {
    final t = p.theme;
    final s = p.songs[i];
    final current = i == page;
    final layout = current && _layout != null ? _layout! : SongLayout(s, t);
    final text = SongPage(song: s, layout: layout, theme: t, scroll: _scrollFor(i), reader: current ? reader : null);
    if (s.score == null || p.readerView == ReaderView.text) return text;
    final sheet = current && _sheet != null ? _sheet! : LeadSheetLayout(s, t);
    if (p.readerView == ReaderView.score) {
      return ScoreView(
        layout: sheet,
        scroll: _scrollFor(i),
        reader: current ? reader : null,
        header: SizedBox(height: SongLayout.headerHeight, child: SongHeader(song: s, theme: t)),
      );
    }
    // mindkettő: fent a kotta aktuális sora, alatta a szöveg
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: sheet.systemHeight * 1.6,
        child: ScoreView(layout: sheet, scroll: current ? _scoreStrip : ScrollController(), reader: current ? reader : null),
      ),
      Divider(height: 1, color: Colors.white.withValues(alpha: 0.15)),
      Expanded(child: text),
    ]);
  }

  Widget _centerPanel() {
    final t = p.theme;
    final n = p.songs.length;
    final s = song;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
        child: Row(children: [
          IconButton(
            tooltip: tr('Előző dal'),
            onPressed: locked || page == 0 ? null : () => _goToPage(page - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(n == 0 ? '0 / 0' : '${page + 1} / $n', style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            tooltip: tr('Következő dal'),
            onPressed: locked || page >= n - 1 ? null : () => _goToPage(page + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 4),
          if (!_phone)
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (var k = 0; k < n; k++)
                    GestureDetector(
                      onTap: locked ? null : () => _goToPage(k),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: k == page ? 18 : 8,
                        height: 8,
                        decoration: BoxDecoration(color: k == page ? t.accent : Colors.white24, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                ]),
              ),
            ),
          const Spacer(),
          // Nézet: szöveg / kotta / mindkettő (a tableten is választható)
          PopupMenuButton<ReaderView>(
            tooltip: tr('Nézet: szöveg, kotta vagy mindkettő'),
            initialValue: p.readerView,
            onSelected: _setView,
            itemBuilder: (_) => [
              PopupMenuItem(value: ReaderView.text, child: Text(tr('Szöveg és akkordok'))),
              PopupMenuItem(value: ReaderView.score, child: Text(tr('Kotta (dallam + akkordok)'))),
              PopupMenuItem(value: ReaderView.both, child: Text(tr('Kotta és szöveg együtt'))),
            ],
            icon: Icon(switch (p.readerView) {
              ReaderView.text => Icons.subject,
              ReaderView.score => Icons.music_note,
              ReaderView.both => Icons.view_agenda,
            }),
          ),
          if (s != null && s.scores.length > 1)
            PopupMenuButton<int>(
              tooltip: tr('Kotta-változat'),
              initialValue: s.activeScore,
              onSelected: (v) => setState(() {
                s.activeScore = v;
                _rebuildReader();
              }),
              itemBuilder: (_) => [for (var k = 0; k < s.scores.length; k++) PopupMenuItem(value: k, child: Text(s.scores[k].name))],
              icon: const Icon(Icons.library_music),
            ),
          IconButton(
            tooltip: player.playing ? tr('Lejátszás leállítása') : tr('Dal lejátszása a hangszeren (csatolt MIDI)'),
            onPressed: s?.score?.midiB64 == null ? null : _togglePlay,
            icon: Icon(player.playing ? Icons.stop_circle : Icons.play_circle_fill, color: player.playing ? Colors.greenAccent : null),
          ),
          IconButton(
            tooltip: tr('Elejére'),
            onPressed: () => setState(() {
              reader.reset();
              _scrolls[page]?.jumpTo(0);
            }),
            icon: const Icon(Icons.skip_previous),
          ),
          IconButton(
            tooltip: reader.running ? tr('Görgetés megállítása') : tr('Görgetés indítása (belső óra)'),
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
            tooltip: locked ? tr('Oldal feloldása') : tr('Oldal lezárása (nem lapoz el)'),
            isSelected: locked,
            style: locked ? IconButton.styleFrom(backgroundColor: Colors.orange.withValues(alpha: 0.3)) : null,
            onPressed: () => setState(() => locked = !locked),
            icon: Icon(locked ? Icons.lock : Icons.lock_open),
          ),
          if (_canEdit) ...[
            IconButton(tooltip: tr('Dal szerkesztése (Ctrl+E)'), onPressed: s == null ? null : _editSong, icon: const Icon(Icons.edit_note)),
            IconButton(tooltip: tr('Új dal'), onPressed: _addSong, icon: const Icon(Icons.add_circle_outline)),
          ],
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: n == 0
            ? Center(
                child: _canEdit
                    ? FilledButton.icon(onPressed: _addSong, icon: const Icon(Icons.add), label: Text(tr('Első dal hozzáadása')))
                    : Text(tr('Nincs dal. Fogadj egy csomagot a PC-ről.')),
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
                  onPageChanged: (k) {
                    player.stop();
                    setState(() {
                      page = k;
                      _rebuildReader();
                    });
                  },
                  itemBuilder: (ctx, k) => _songPage(k),
                ),
              ),
      ),
    ]);
  }

  // ---- alsó vezérlősáv (modulok a szerkesztett sorrendben) ----
  Widget _bottomBar() {
    final edit = editLayout && _canEdit;
    final compact = _compact || _phone;
    final ps = p.panels['bottom']!;
    final titleColor = (ps.buttonText ?? Colors.white).withValues(alpha: 0.7);
    Widget group(String title, Widget child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: titleColor)),
            const SizedBox(height: 6),
            child,
          ]),
        );
    Widget sep() => VerticalDivider(width: 18, indent: 14, endIndent: 14, color: Colors.white.withValues(alpha: 0.12));
    Widget btn(String id, String label, VoidCallback? onTap,
            {bool sel = false, double w = 44, double h = 44, IconData? icon, String? name}) =>
        AlsButton(
          project: p,
          panel: 'bottom',
          id: id,
          label: label,
          icon: icon,
          width: w,
          height: h,
          selected: sel,
          editMode: edit,
          onEdit: () => _editItem(id, name ?? label),
          onTap: onTap,
        );

    final bank0 = bank.clamp(0, p.banks.length - 1);
    Widget? module(String k) => switch (k) {
          'layers' => group(
              tr('Rétegek (V1–V4)'),
              compact
                  ? Column(children: [
                      Row(children: [_slotTile(0), _slotTile(1)]),
                      const SizedBox(height: 6),
                      Row(children: [_slotTile(2), _slotTile(3)]),
                    ])
                  : Row(children: [for (var i = 0; i < p.slots.length; i++) _slotTile(i)]),
            ),
          'ots' => group(
              compact ? 'OTS' : 'One Touch Settings',
              SizedBox(
                width: compact ? 88 : 196,
                child: Wrap(spacing: 4, runSpacing: 4, children: [
                  for (var i = 1; i <= 4; i++)
                    Tooltip(
                      message: tr('OTS-hívás MIDI-n: a modell Data List-je alapján kerül be'),
                      child: btn('ots:$i', '$i', null, w: compact ? 40 : 44, h: compact ? 40 : 44),
                    ),
                ]),
              ),
            ),
          'tempo' => group(
              tr('Tempó'),
              Row(children: [
                btn('btn:tempo-', '', () => _setTempo(bpm - 1), icon: Icons.remove, name: tr('Tempó −')),
                SizedBox(
                  width: 88,
                  child: Center(child: Text('${bpm.round()}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700))),
                ),
                btn('btn:tempo+', '', () => _setTempo(bpm + 1), icon: Icons.add, name: tr('Tempó +')),
                const SizedBox(width: 6),
                btn('btn:tap', 'TAP', _tapTempo, w: 60),
              ]),
            ),
          'regs' => group(
              tr('Regiszter bankok'),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  DropdownButton<int>(
                    value: bank0,
                    underline: const SizedBox(),
                    items: [for (var b = 0; b < p.banks.length; b++) DropdownMenuItem(value: b, child: Text(p.banks[b].name))],
                    onChanged: (v) => setState(() {
                      bank = v!;
                      activeReg = null;
                    }),
                  ),
                  if (_canEdit) ...[
                    IconButton(
                      tooltip: tr('Új bank'),
                      onPressed: () {
                        setState(() {
                          p.banks.add(RegBank(tr('Bank {0}', [p.banks.length + 1])));
                          bank = p.banks.length - 1;
                        });
                        _changed();
                      },
                      icon: const Icon(Icons.add, size: 18),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => saveMode = !saveMode),
                      icon: Icon(Icons.save, size: 18, color: saveMode ? Colors.orangeAccent : null),
                      label: Text(saveMode ? tr('Hová?') : tr('Mentés')),
                    ),
                  ],
                ]),
                SizedBox(
                  width: compact ? 176 : 360,
                  child: Wrap(spacing: 4, runSpacing: 4, children: [
                    for (var i = 0; i < 8; i++)
                      btn('reg:$i', '${i + 1}${p.banks[bank0].slots[i] != null ? '•' : ''}', () => _regButton(i),
                          sel: activeReg == i, w: 40, h: 34),
                  ]),
                ),
              ]),
            ),
          'startStop' => group(tr('Stílus'), Row(children: [
              btn('btn:start', 'Start', _start, sel: styleRunning, icon: Icons.play_arrow, w: 96),
              const SizedBox(width: 6),
              btn('btn:stop', 'Stop', _stop, icon: Icons.stop, w: 96),
            ])),
          'mains' => group('Main', Row(children: [
              for (final m in mains)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: btn('btn:${m.label}', m.label.replaceAll('Main ', ''), () => _section(m),
                      sel: lastSection == m.code || (lastSection == null && m.code == currentMain), name: m.label),
                ),
            ])),
          'sync' => group(tr('Hangszer'), btn('btn:sync', tr('Szinkron'), song == null ? null : _syncSong, icon: Icons.sync, w: 130)),
          'playScore' => group(tr('Dal'), btn('btn:play', player.playing ? tr('Leállítás') : tr('Lejátszás'), _togglePlay,
              sel: player.playing, icon: player.playing ? Icons.stop_circle : Icons.play_circle, w: 140)),
          'lock' => group(tr('Oldal'), btn('btn:lock', locked ? tr('Feloldás') : tr('Lakat'), () => setState(() => locked = !locked),
              sel: locked, icon: locked ? Icons.lock : Icons.lock_open, w: 120)),
          'spacer' => const SizedBox(width: 40),
          _ => null,
        };

    final widgets = <Widget>[];
    for (final k in p.bottomModules) {
      final w = module(k);
      if (w == null) continue;
      if (widgets.isNotEmpty && k != 'spacer') widgets.add(sep());
      widgets.add(w);
    }
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: widgets));
  }

  Widget _slotTile(int i) {
    final s = p.slots[i];
    final compact = _compact || _phone;
    final edit = editLayout && _canEdit;
    return DragTarget<VoicePreset>(
      onAcceptWithDetails: (d) => _assignVoice(i, d.data),
      builder: (ctx, cand, _) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: AlsButton(
          project: p,
          panel: 'bottom',
          id: 'v:$i',
          label: 'V${i + 1}',
          width: compact ? 140 : 148,
          height: compact ? 44 : 64,
          selected: s.enabled || cand.isNotEmpty,
          editMode: edit,
          onEdit: () => _editItem('v:$i', 'V${i + 1}'),
          onTap: _canEdit
              ? () => showSlotDialog(context, i, s, () {
                    setState(() {});
                    _applyZone(i);
                    _changed();
                  }, () => _sendVoice(i))
              : () {
                  setState(() => s.enabled = !s.enabled);
                  _applyZone(i);
                },
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('V${i + 1}  ${s.name}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('ch${s.channel + 1} · ${noteName(s.low)}–${noteName(s.high)}',
                    maxLines: 1,
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
              ]),
            ),
            Icon(s.enabled ? Icons.toggle_on : Icons.toggle_off_outlined, size: 26),
          ]),
        ),
      ),
    );
  }

  Widget _statusLine() => Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Text(
          '${p.name}${dirty && isDesktop ? ' •' : ''}   ·   ${logLines.last}${currentPath != null ? '      ·  $currentPath' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
        ),
      );
}
