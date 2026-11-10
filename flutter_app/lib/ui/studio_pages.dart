// lib/ui/studio_pages.dart — SoundNexus Sample Studio és SoundNexus Loop Studio
//
// Önálló oldalak, élő folyamatjelzéssel. A feldolgozás a C++ magban, külön
// isolate-ban fut (a felület nem akad meg); a végén a program megkérdezi,
// hova mentse az eredményt.
import '../i18n/i18n.dart';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../audio/wav_peaks.dart';
import '../ffi/als_core.dart';
import '../model/project.dart';

List<XTypeGroup> get _wavTypes => [XTypeGroup(label: tr('WAV hangminta'), extensions: const ['wav'])];

// Háttérszálas hívások felső szintű függvényekben: a lezárás így csak az
// átadott értékeket viszi át az isolate-ba (a felület állapotát nem).
Future<WavInfo> _peaksIso(String path) => Isolate.run(() => readWavPeaks(path, 900));
Future<TrimResult> _trimIso(String src, String out, double sd, double td, bool th, bool tt, bool ft) =>
    Isolate.run(() => AlsCore.load().trimWavEx(src, out, startDb: sd, tailDb: td, trimHead: th, trimTail: tt, fadeTail: ft));
Future<TrimResult> _loopIso(String src, String out, double ml, double cf, int un) =>
    Isolate.run(() => AlsCore.load().loopWav(src, out, minLoopMs: ml, crossfadeMs: cf, unityNote: un));

String _base(String path) => path.split(RegExp(r'[\\/]')).last;
String _stem(String path) => _base(path).replaceAll(RegExp(r'\.wav$', caseSensitive: false), '');

// ---------------------------------------------------------------------------
// Közös elemek
// ---------------------------------------------------------------------------
enum StepState { waiting, running, done, error }

class _Step {
  _Step(this.label);
  final String label;
  StepState state = StepState.waiting;
  String detail = '';
  int ms = 0;
}

class _StudioScaffold extends StatelessWidget {
  const _StudioScaffold({required this.project, required this.title, required this.subtitle, required this.icon, required this.body});
  final Project project;
  final String title, subtitle;
  final IconData icon;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final t = project.theme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: t.backgroundDecoration,
        child: SafeArea(
          child: Column(children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [t.accent.withValues(alpha: 0.35), Colors.transparent]),
              ),
              child: Row(children: [
                IconButton(tooltip: tr('Vissza a SoundNexus Pro-hoz'), onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
                const SizedBox(width: 6),
                Icon(icon, color: t.accent, size: 30),
                const SizedBox(width: 12),
                Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65))),
                ]),
              ]),
            ),
            Expanded(child: body),
          ]),
        ),
      ),
    );
  }
}

Widget _card(Project p, Widget child, {EdgeInsets padding = const EdgeInsets.all(14)}) => Container(
      margin: const EdgeInsets.all(6),
      padding: padding,
      decoration: BoxDecoration(
        color: p.theme.panel.withValues(alpha: p.theme.panelOpacity),
        borderRadius: BorderRadius.circular(p.theme.radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: child,
    );

Widget _steps(List<_Step> steps, Color accent) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(
                width: 22,
                height: 22,
                child: switch (s.state) {
                  StepState.waiting => Icon(Icons.radio_button_unchecked, size: 18, color: Colors.white.withValues(alpha: 0.35)),
                  StepState.running => CircularProgressIndicator(strokeWidth: 2.5, color: accent),
                  StepState.done => const Icon(Icons.check_circle, size: 20, color: Colors.greenAccent),
                  StepState.error => const Icon(Icons.error, size: 20, color: Colors.redAccent),
                },
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600))),
              if (s.detail.isNotEmpty)
                Flexible(child: Text(s.detail, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)))),
              if (s.state == StepState.done) Text('  ${s.ms} ms', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45))),
            ]),
          ),
      ],
    );

Future<T> _timed<T>(_Step s, void Function() refresh, Future<T> Function() work) async {
  s.state = StepState.running;
  refresh();
  final sw = Stopwatch()..start();
  try {
    final r = await work();
    s
      ..ms = sw.elapsedMilliseconds
      ..state = StepState.done;
    refresh();
    return r;
  } catch (e) {
    s
      ..state = StepState.error
      ..detail = '$e';
    refresh();
    rethrow;
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.info, this.color, {this.cutStart, this.cutEnd, this.loopStart, this.loopEnd});
  final WavInfo info;
  final Color color;
  final int? cutStart, cutEnd, loopStart, loopEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final n = info.mins.length;
    double xOf(int frame) => frame / math.max(1, info.frames) * size.width;
    // levágott részek
    final cut = Paint()..color = Colors.redAccent.withValues(alpha: 0.22);
    if (cutStart != null && cutStart! > 0) canvas.drawRect(Rect.fromLTWH(0, 0, xOf(cutStart!), size.height), cut);
    if (cutEnd != null && cutEnd! < info.frames) {
      canvas.drawRect(Rect.fromLTRB(xOf(cutEnd!), 0, size.width, size.height), cut);
    }
    // loop tartomány
    if (loopStart != null && loopEnd != null && loopStart! >= 0) {
      canvas.drawRect(Rect.fromLTRB(xOf(loopStart!), 0, xOf(loopEnd!), size.height), Paint()..color = color.withValues(alpha: 0.18));
      final m = Paint()
        ..color = color
        ..strokeWidth = 2;
      canvas.drawLine(Offset(xOf(loopStart!), 0), Offset(xOf(loopStart!), size.height), m);
      canvas.drawLine(Offset(xOf(loopEnd!), 0), Offset(xOf(loopEnd!), size.height), m);
    }
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), Paint()..color = Colors.white24);
    final wave = Paint()
      ..color = color
      ..strokeWidth = math.max(1, size.width / n);
    for (var i = 0; i < n; i++) {
      final x = (i + 0.5) / n * size.width;
      canvas.drawLine(Offset(x, mid - info.maxs[i] * mid * 0.95), Offset(x, mid - info.mins[i] * mid * 0.95), wave);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => true;
}

class _SeamPainter extends CustomPainter {
  _SeamPainter(this.seam, this.color);
  final Float32List seam;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    var peak = 1e-6;
    for (final v in seam) {
      peak = math.max(peak, v.abs());
    }
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), Paint()..color = Colors.white24);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height),
        Paint()
          ..color = Colors.orangeAccent
          ..strokeWidth = 1.5);
    final path = Path();
    for (var i = 0; i < seam.length; i++) {
      final x = i / (seam.length - 1) * size.width;
      final y = mid - seam[i] / peak * mid * 0.9;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _SeamPainter old) => true;
}

Widget _wave(String label, WavInfo? info, Color color, {int? cutStart, int? cutEnd, int? loopStart, int? loopEnd, double height = 140}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        if (info != null)
          Text(tr('{0} s · {1} minta · {2}', [info.seconds.toStringAsFixed(3), info.frames, info.format]),
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
      ]),
      const SizedBox(height: 6),
      Container(
        height: height,
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
        child: info == null
            ? Center(child: Text('—', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))))
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _WavePainter(info, color, cutStart: cutStart, cutEnd: cutEnd, loopStart: loopStart, loopEnd: loopEnd),
                ),
              ),
      ),
    ]);

Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 190, child: Text(k, style: TextStyle(color: Colors.white.withValues(alpha: 0.7)))),
        Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );

Widget _slider(String label, double v, double min, double max, String unit, ValueChanged<double>? onChanged, {int? divisions}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label: ${v.toStringAsFixed(v.abs() < 10 && unit == 'ms' ? 1 : 0)} $unit'),
      Slider(value: v, min: min, max: max, divisions: divisions, onChanged: onChanged),
    ]);

// ---------------------------------------------------------------------------
// SoundNexus Sample Studio
// ---------------------------------------------------------------------------
class _TrimJob {
  _TrimJob(this.path);
  final String path;
  WavInfo? before, after;
  TrimResult? result;
  String? temp;
  final steps = [_Step(tr('Beolvasás és hullámforma')), _Step(tr('Csend és lecsengés elemzése, vágás')), _Step(tr('Ellenőrzés: formátum, bitmélység'))];
}

class SampleStudioPage extends StatefulWidget {
  const SampleStudioPage({super.key, required this.project});
  final Project project;
  @override
  State<SampleStudioPage> createState() => _SampleStudioPageState();
}

class _SampleStudioPageState extends State<SampleStudioPage> {
  final jobs = <_TrimJob>[];
  int selected = 0;
  bool running = false;
  double startDb = -60, tailDb = -70;
  bool trimHead = true, trimTail = true, fadeTail = true;
  String? savedInfo;

  Future<void> _pick() async {
    final files = await openFiles(acceptedTypeGroups: _wavTypes);
    if (files.isEmpty) return;
    setState(() {
      jobs
        ..clear()
        ..addAll(files.map((f) => _TrimJob(f.path)));
      selected = 0;
      savedInfo = null;
    });
  }

  Future<void> _run() async {
    if (jobs.isEmpty) return;
    setState(() {
      running = true;
      savedInfo = null;
    });
    final tmpDir = await Directory.systemTemp.createTemp('snx_trim_');
    final sd = startDb, td = tailDb, th = trimHead, tt = trimTail, ft = fadeTail;
    for (var k = 0; k < jobs.length; k++) {
      final j = jobs[k];
      for (final s in j.steps) {
        s
          ..state = StepState.waiting
          ..detail = '';
      }
      setState(() => selected = k);
      try {
        final path = j.path;
        j.before = await _timed(j.steps[0], () => setState(() {}), () => _peaksIso(path));
        j.steps[0].detail = j.before!.format;
        final out = '${tmpDir.path}${Platform.pathSeparator}${_stem(path)}_vagott.wav';
        j.result = await _timed(j.steps[1], () => setState(() {}),
            () => _trimIso(path, out, sd, td, th, tt, ft));
        if (!j.result!.ok) throw '${j.result!.json['error']}';
        j.temp = out;
        j.steps[1].detail = tr('eleje −{0} ms · vége −{1} ms', [(j.result!.json['cutHeadMs'] as num).toStringAsFixed(2), (j.result!.json['cutTailMs'] as num).toStringAsFixed(1)]);
        j.after = await _timed(j.steps[2], () => setState(() {}), () => _peaksIso(out));
        final same = j.after!.sampleRate == j.before!.sampleRate && j.after!.bits == j.before!.bits && j.after!.channels == j.before!.channels;
        j.steps[2].detail = same ? tr('formátum változatlan ✓') : tr('FIGYELEM: formátum eltér');
      } catch (_) {
        // a hibát a lépés mutatja
      }
      setState(() {});
    }
    setState(() => running = false);
    await _save();
  }

  Future<void> _save() async {
    final ok = jobs.where((j) => j.temp != null).toList();
    if (ok.isEmpty) return;
    if (ok.length == 1) {
      final j = ok.first;
      final loc = await getSaveLocation(
        suggestedName: '${_stem(j.path)}_vagott.wav',
        acceptedTypeGroups: _wavTypes,
        confirmButtonText: tr('Mentés'),
      );
      if (loc == null) return;
      final dest = loc.path.toLowerCase().endsWith('.wav') ? loc.path : '${loc.path}.wav';
      await File(j.temp!).copy(dest);
      setState(() => savedInfo = tr('Mentve: {0}', [dest]));
    } else {
      final dir = await getDirectoryPath(confirmButtonText: tr('Mentés ide'));
      if (dir == null) return;
      for (final j in ok) {
        await File(j.temp!).copy('$dir${Platform.pathSeparator}${_stem(j.path)}_vagott.wav');
      }
      setState(() => savedInfo = tr('{0} fájl mentve ide: {1}', [ok.length, dir]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    final accent = p.theme.accent;
    final j = jobs.isEmpty ? null : jobs[selected.clamp(0, jobs.length - 1)];
    final r = j?.result?.json;
    return _StudioScaffold(
      project: p,
      title: 'SoundNexus Sample Studio',
      subtitle: tr('Mintapontos csend- és lecsengés-vágás · a megmaradó minták bitre változatlanok'),
      icon: Icons.content_cut,
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 330,
          child: _card(
            p,
            ListView(children: [
              FilledButton.icon(onPressed: running ? null : _pick, icon: const Icon(Icons.library_music), label: Text(tr('WAV fájlok megnyitása'))),
              const SizedBox(height: 6),
              Text(jobs.isEmpty ? tr('Egy vagy több fájl választható (kötegelt feldolgozás).') : tr('{0} fájl kiválasztva', [jobs.length]),
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
              const Divider(height: 26),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(tr('Csend vágása az elejéről')), value: trimHead,
                  onChanged: running ? null : (v) => setState(() => trimHead = v)),
              _slider(tr('Kezdőpont küszöb'), startDb, -90, -30, 'dBFS', running ? null : (v) => setState(() => startDb = v.roundToDouble()), divisions: 60),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(tr('Utózengés, zaj vágása a végéről')), value: trimTail,
                  onChanged: running ? null : (v) => setState(() => trimTail = v)),
              _slider(tr('Lecsengés küszöb'), tailDb, -100, -40, 'dBFS', running || !trimTail ? null : (v) => setState(() => tailDb = v.roundToDouble()), divisions: 60),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(tr('Kattanásmentes lezárás (5–20 ms fade)')), value: fadeTail,
                  onChanged: running || !trimTail ? null : (v) => setState(() => fadeTail = v)),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: running || jobs.isEmpty ? null : _run,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(running ? tr('Feldolgozás…') : tr('Vágás indítása')),
                ),
              ),
              if (jobs.length > 1) ...[
                const Divider(height: 26),
                for (var k = 0; k < jobs.length; k++)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    selected: k == selected,
                    leading: Icon(jobs[k].temp != null
                        ? Icons.check_circle
                        : jobs[k].steps.any((s) => s.state == StepState.error)
                            ? Icons.error
                            : Icons.audio_file),
                    title: Text(_base(jobs[k].path), maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => setState(() => selected = k),
                  ),
              ],
            ]),
          ),
        ),
        Expanded(
          child: ListView(children: [
            _card(p, j == null
                ? Text(tr('Nyiss meg egy vagy több WAV fájlt a bal oldalon.'))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_base(j.path), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    _steps(j.steps, accent),
                  ])),
            _card(p, Column(children: [
              _wave(tr('Eredeti (piros = levágott rész)'), j?.before, Colors.white70,
                  cutStart: r?['startFrame'] as int?, cutEnd: r?['endFrame'] as int?),
              const SizedBox(height: 14),
              _wave(tr('Eredmény'), j?.after, accent),
            ])),
            if (r != null && j?.result?.ok == true)
              _card(p, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _kv(tr('Levágva az elejéről'), tr('{0} ms ({1} minta)', [(r['cutHeadMs'] as num).toStringAsFixed(3), r['cutHeadSamples']])),
                _kv(tr('Levágva a végéről'), '${(r['cutTailMs'] as num).toStringAsFixed(2)} ms'),
                _kv(tr('Csúcsszint'), '${(r['peakDb'] as num).toStringAsFixed(2)} dBFS'),
                _kv(tr('Zajpadló'), '${(r['noiseFloorDb'] as num).toStringAsFixed(1)} dBFS'),
                _kv(tr('Lezáró fade'), (r['fadeMs'] as num) > 0 ? '${(r['fadeMs'] as num).toStringAsFixed(2)} ms' : tr('nincs')),
                _kv(tr('Minőség'), tr('a megmaradó minták bitre azonosak az eredetivel; nincs újramintavételezés, nincs bitmélység-váltás')),
                if (r['needsReview'] == true)
                  Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(tr('Figyelem: lassú felfutású hang (pl. pad) – hallgasd meg, nem vágott-e bele a hang elejébe.'),
                        style: TextStyle(color: Colors.orangeAccent)),
                  ),
              ])),
            if (!running && jobs.any((j) => j.temp != null))
              _card(p, Row(children: [
                Expanded(child: Text(savedInfo ?? tr('Kész. Még nincs mentve.'))),
                FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_alt), label: Text(tr('Mentés…'))),
              ])),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// SoundNexus Loop Studio
// ---------------------------------------------------------------------------
const _noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'H'];
String _note(int n) => '${_noteNames[n % 12]}${n ~/ 12 - 2}';

class LoopStudioPage extends StatefulWidget {
  const LoopStudioPage({super.key, required this.project});
  final Project project;
  @override
  State<LoopStudioPage> createState() => _LoopStudioPageState();
}

class _LoopStudioPageState extends State<LoopStudioPage> {
  String? path, temp, savedInfo;
  WavInfo? before, after;
  TrimResult? result;
  bool running = false;
  double minLoopMs = 400, crossfadeMs = 0;
  int unityNote = 60;
  var steps = <_Step>[];

  List<_Step> _newSteps() => [_Step(tr('Beolvasás és hullámforma')), _Step(tr('Stabil szakasz és loop pontok keresése')), _Step(tr('Ellenőrzés: varrat, formátum'))];

  Future<void> _pick() async {
    final f = await openFile(acceptedTypeGroups: _wavTypes);
    if (f == null) return;
    setState(() {
      path = f.path;
      before = after = null;
      result = null;
      temp = savedInfo = null;
      steps = _newSteps();
    });
  }

  Future<void> _run() async {
    final src = path;
    if (src == null) return;
    setState(() {
      running = true;
      steps = _newSteps();
      savedInfo = null;
    });
    final ml = minLoopMs, cf = crossfadeMs, un = unityNote;
    try {
      before = await _timed(steps[0], () => setState(() {}), () => _peaksIso(src));
      steps[0].detail = before!.format;
      final tmpDir = await Directory.systemTemp.createTemp('snx_loop_');
      final out = '${tmpDir.path}${Platform.pathSeparator}${_stem(src)}_loop.wav';
      result = await _timed(steps[1], () => setState(() {}),
          () => _loopIso(src, out, ml, cf, un));
      if (!result!.ok) throw '${result!.json['error']}';
      temp = out;
      final r = result!.json;
      steps[1].detail = tr('{0} ms hosszú loop', [(r['lengthMs'] as num).toStringAsFixed(1)]);
      after = await _timed(steps[2], () => setState(() {}), () => _peaksIso(out));
      steps[2].detail = tr('varrat-egyezés {0}%', [((r['score'] as num) * 100).toStringAsFixed(2)]);
    } catch (_) {
      // a lépés mutatja a hibát
    }
    setState(() => running = false);
    if (temp != null) await _save();
  }

  Future<void> _save() async {
    final src = path, tmp = temp;
    if (src == null || tmp == null) return;
    final loc = await getSaveLocation(suggestedName: '${_stem(src)}_loop.wav', acceptedTypeGroups: _wavTypes, confirmButtonText: tr('Mentés'));
    if (loc == null) return;
    final dest = loc.path.toLowerCase().endsWith('.wav') ? loc.path : '${loc.path}.wav';
    await File(tmp).copy(dest);
    setState(() => savedInfo = tr('Mentve: {0}', [dest]));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    final accent = p.theme.accent;
    final r = result?.json;
    final ok = result?.ok == true;
    return _StudioScaffold(
      project: p,
      title: 'SoundNexus Loop Studio',
      subtitle: tr('Kattanásmentes loop pontok kitartott hangmintákhoz · smpl blokk (Yamaha Expansion Manager, samplerek)'),
      icon: Icons.all_inclusive,
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 330,
          child: _card(
            p,
            ListView(children: [
              FilledButton.icon(onPressed: running ? null : _pick, icon: const Icon(Icons.audio_file), label: Text(tr('WAV megnyitása'))),
              const SizedBox(height: 6),
              Text(path == null ? tr('Kitartott hang (vonós, pad, orgona, kórus) a legjobb.') : _base(path!),
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
              const Divider(height: 26),
              _slider(tr('Legrövidebb loop'), minLoopMs, 100, 3000, 'ms', running ? null : (v) => setState(() => minLoopMs = v.roundToDouble()), divisions: 58),
              _slider('Crossfade', crossfadeMs, 0, 300, 'ms', running ? null : (v) => setState(() => crossfadeMs = v.roundToDouble()), divisions: 60),
              Text(crossfadeMs == 0
                  ? tr('Crossfade nélkül a minták érintetlenek maradnak.')
                  : tr('A loop vége előtti rész átkeveredik a loop eleje előtti résszel (equal-power).'),
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
              const SizedBox(height: 12),
              Row(children: [
                Text(tr('Alaphang (MIDI): ')),
                IconButton(onPressed: running ? null : () => setState(() => unityNote = (unityNote - 1).clamp(0, 127)), icon: const Icon(Icons.remove)),
                Text('${_note(unityNote)} ($unityNote)', style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(onPressed: running ? null : () => setState(() => unityNote = (unityNote + 1).clamp(0, 127)), icon: const Icon(Icons.add)),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: running || path == null ? null : _run,
                  icon: const Icon(Icons.search),
                  label: Text(running ? tr('Keresés…') : tr('Loop pontok keresése')),
                ),
              ),
            ]),
          ),
        ),
        Expanded(
          child: ListView(children: [
            _card(p, steps.isEmpty ? Text(tr('Nyiss meg egy WAV hangmintát a bal oldalon.')) : _steps(steps, accent)),
            _card(p, Column(children: [
              _wave(tr('Hangminta (kiemelve: a loop)'), after ?? before, accent,
                  loopStart: ok ? r!['loopStart'] as int : null, loopEnd: ok ? r!['loopEnd'] as int : null, height: 170),
            ])),
            if (ok && after?.seam != null)
              _card(p, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('A varrat nagyítva: a loop vége (balra) → a loop eleje (jobbra). Egyenletes átmenet = nincs kattanás.'),
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  height: 140,
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                  child: CustomPaint(size: Size.infinite, painter: _SeamPainter(after!.seam!, accent)),
                ),
              ])),
            if (ok)
              _card(p, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _kv(tr('Loop kezdete'), tr('{0}. minta ({1} ms)', [r!['loopStart'], ((r['loopStart'] as int) / (r['sampleRate'] as int) * 1000).toStringAsFixed(2)])),
                _kv(tr('Loop vége'), tr('{0}. minta', [r['loopEnd']])),
                _kv(tr('Loop hossza'), '${(r['lengthMs'] as num).toStringAsFixed(2)} ms'),
                _kv(tr('Varrat-egyezés'), '${((r['score'] as num) * 100).toStringAsFixed(2)}%'),
                _kv(tr('Hangerő-eltérés a két vég között'), '${(r['levelDiffDb'] as num).toStringAsFixed(2)} dB'),
                _kv('Crossfade', (r['crossfadeMs'] as num) > 0 ? '${(r['crossfadeMs'] as num).toStringAsFixed(1)} ms' : tr('nincs (a minták érintetlenek)')),
                _kv(tr('Alaphang'), '${_note(unityNote)} (MIDI $unityNote)'),
              ])),
            if (temp != null && !running)
              _card(p, Row(children: [
                Expanded(child: Text(savedInfo ?? tr('Kész. Még nincs mentve.'))),
                FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_alt), label: Text(tr('Mentés…'))),
              ])),
          ]),
        ),
      ]),
    );
  }
}
