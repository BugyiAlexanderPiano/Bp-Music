// lib/ui/dialogs.dart — beállító ablakok: téma, betűtípus, V-slot, normalizálás
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/project.dart';
import 'color_picker.dart';

// ---------------------------------------------------------------------------
// Téma és színek (élő előnézettel: minden változás azonnal látszik)
// ---------------------------------------------------------------------------
class _Preset {
  const _Preset(this.name, this.bg, this.accent, this.panel);
  final String name;
  final List<Color> bg;
  final Color accent, panel;
}

const _themePresets = [
  _Preset('Éjkék', [Color(0xFF0E1525), Color(0xFF1B1035)], Color(0xFF4F8CFF), Color(0xFF151B2B)),
  _Preset('Bíbor', [Color(0xFF240B36), Color(0xFFC31432)], Color(0xFFFF7AA2), Color(0xFF1E0B22)),
  _Preset('Óceán', [Color(0xFF02111B), Color(0xFF0B4F6C)], Color(0xFF00C2D1), Color(0xFF0A1D2A)),
  _Preset('Napnyugta', [Color(0xFF2B1B17), Color(0xFF9E3A12), Color(0xFFE0A100)], Color(0xFFFFB347), Color(0xFF231511)),
  _Preset('Szén', [Color(0xFF111111), Color(0xFF1F1F1F)], Color(0xFF9E9E9E), Color(0xFF1A1A1A)),
  _Preset('Smaragd', [Color(0xFF071A12), Color(0xFF14532D)], Color(0xFF34D399), Color(0xFF0C2018)),
];

Future<void> showThemeDialog(BuildContext context, ThemeSettings t, VoidCallback onChanged) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        void upd(VoidCallback f) {
          f();
          setD(() {});
          onChanged();
        }

        return AlertDialog(
          title: const Text('Téma és színek'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Kész témák', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in _themePresets)
                    InkWell(
                      onTap: () => upd(() {
                        t.background = List.of(p.bg);
                        t.accent = p.accent;
                        t.panel = p.panel;
                        t.highlight = p.accent;
                        t.mode = BackgroundMode.gradient;
                      }),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 96,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(colors: p.bg.length > 1 ? p.bg : [p.bg.first, p.bg.first]),
                          border: Border.all(color: p.accent, width: 2),
                        ),
                        child: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ]),
                const SizedBox(height: 18),
                const Text('Háttér', style: TextStyle(fontWeight: FontWeight.w600)),
                SegmentedButton<BackgroundMode>(
                  segments: const [
                    ButtonSegment(value: BackgroundMode.solid, label: Text('Egyszínű')),
                    ButtonSegment(value: BackgroundMode.gradient, label: Text('Átmenetes')),
                  ],
                  selected: {t.mode},
                  onSelectionChanged: (s) => upd(() {
                    t.mode = s.first;
                    if (t.mode == BackgroundMode.gradient && t.background.length < 2) {
                      t.background.add(t.background.first);
                    }
                  }),
                ),
                const SizedBox(height: 8),
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
                  for (var i = 0; i < (t.mode == BackgroundMode.solid ? 1 : t.background.length); i++)
                    ColorButton(
                      color: t.background[i],
                      label: t.mode == BackgroundMode.solid ? 'Háttérszín' : '${i + 1}. szín',
                      onChanged: (c) => upd(() => t.background[i] = c),
                    ),
                  if (t.mode == BackgroundMode.gradient && t.background.length < 4)
                    IconButton(
                      tooltip: 'Szín hozzáadása',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => upd(() => t.background.add(t.background.last)),
                    ),
                  if (t.mode == BackgroundMode.gradient && t.background.length > 2)
                    IconButton(
                      tooltip: 'Utolsó szín törlése',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => upd(() => t.background.removeLast()),
                    ),
                ]),
                if (t.mode == BackgroundMode.gradient) ...[
                  const SizedBox(height: 6),
                  const Text('Átmenet iránya'),
                  Wrap(spacing: 4, children: [
                    for (final (a, ic) in const [
                      (Alignment.topCenter, Icons.south),
                      (Alignment.topLeft, Icons.south_east),
                      (Alignment.centerLeft, Icons.east),
                      (Alignment.bottomLeft, Icons.north_east),
                    ])
                      IconButton.outlined(
                        isSelected: t.gradientBegin == a,
                        icon: Icon(ic),
                        onPressed: () => upd(() => t.gradientBegin = a),
                      ),
                  ]),
                ],
                const SizedBox(height: 14),
                const Text('Felület', style: TextStyle(fontWeight: FontWeight.w600)),
                Wrap(spacing: 8, children: [
                  ColorButton(color: t.accent, label: 'Kiemelőszín', onChanged: (c) => upd(() => t.accent = c)),
                  ColorButton(color: t.panel, label: 'Panelszín', onChanged: (c) => upd(() => t.panel = c)),
                ]),
                Row(children: [
                  const SizedBox(width: 130, child: Text('Panel átlátszóság')),
                  Expanded(
                    child: Slider(
                      value: t.panelOpacity,
                      min: 0.3,
                      max: 1,
                      onChanged: (v) => upd(() => t.panelOpacity = v),
                    ),
                  ),
                ]),
                Row(children: [
                  const SizedBox(width: 130, child: Text('Sarkok kerekítése')),
                  Expanded(
                    child: Slider(
                      value: t.radius,
                      max: 32,
                      onChanged: (v) => upd(() => t.radius = v),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kész'))],
        );
      }),
    );

// ---------------------------------------------------------------------------
// Betűtípus és szövegszínek
// ---------------------------------------------------------------------------
const fontChoices = <String>[
  'Segoe UI', 'Arial', 'Calibri', 'Verdana', 'Tahoma', 'Trebuchet MS', 'Georgia',
  'Times New Roman', 'Garamond', 'Cambria', 'Consolas', 'Courier New', 'Comic Sans MS',
  'Impact', 'Helvetica Neue', 'Avenir Next', 'Futura', 'Gill Sans', 'Palatino', 'Menlo',
];

Future<void> showFontDialog(BuildContext context, ThemeSettings t, VoidCallback onChanged) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        void upd(VoidCallback f) {
          f();
          setD(() {});
          onChanged();
        }

        return AlertDialog(
          title: const Text('Betűtípus és szövegszínek'),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Betűtípus'),
              DropdownButton<String>(
                isExpanded: true,
                value: fontChoices.contains(t.fontFamily) ? t.fontFamily : fontChoices.first,
                items: [
                  for (final f in fontChoices)
                    DropdownMenuItem(value: f, child: Text(f, style: TextStyle(fontFamily: f, fontSize: 16))),
                ],
                onChanged: (v) => upd(() => t.fontFamily = v!),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Betűméret'),
                Expanded(
                  child: Slider(
                    value: t.fontSize,
                    min: 16,
                    max: 64,
                    divisions: 48,
                    label: t.fontSize.round().toString(),
                    onChanged: (v) => upd(() => t.fontSize = v),
                  ),
                ),
                Text('${t.fontSize.round()} pt'),
              ]),
              Wrap(spacing: 8, children: [
                ColorButton(color: t.textColor, label: 'Szöveg', onChanged: (c) => upd(() => t.textColor = c)),
                ColorButton(color: t.chordColor, label: 'Akkordok', onChanged: (c) => upd(() => t.chordColor = c)),
                ColorButton(color: t.sectionColor, label: 'Szakaszok', onChanged: (c) => upd(() => t.sectionColor = c)),
                ColorButton(color: t.highlight, label: 'Aktuális sor', onChanged: (c) => upd(() => t.highlight = c)),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('G            D', style: TextStyle(fontFamily: t.fontFamily, color: t.chordColor, fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('Minta dalszöveg sor', style: TextStyle(fontFamily: t.fontFamily, color: t.textColor, fontSize: 26)),
                ]),
              ),
            ]),
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kész'))],
        );
      }),
    );

// ---------------------------------------------------------------------------
// V-slot szerkesztő
// ---------------------------------------------------------------------------
const _noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'H'];
/// Yamaha jelölés: 60 = C3
String noteName(int n) => '${_noteNames[n % 12]}${n ~/ 12 - 2}';

Future<void> showSlotDialog(BuildContext context, int index, VSlot s, VoidCallback onChanged, VoidCallback onSendVoice) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        void upd(VoidCallback f) {
          f();
          setD(() {});
          onChanged();
        }

        return AlertDialog(
          title: Text('V${index + 1} – ${s.name}'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bekapcsolva'),
                value: s.enabled,
                onChanged: (v) => upd(() => s.enabled = v),
              ),
              Row(children: [
                const Text('MIDI csatorna: '),
                DropdownButton<int>(
                  value: s.channel,
                  items: [for (var c = 0; c < 16; c++) DropdownMenuItem(value: c, child: Text('${c + 1}'))],
                  onChanged: (v) => upd(() => s.channel = v!),
                ),
              ]),
              Text('Billentyűzóna: ${noteName(s.low)} – ${noteName(s.high)}'),
              RangeSlider(
                values: RangeValues(s.low.toDouble(), s.high.toDouble()),
                min: 21,
                max: 108,
                divisions: 87,
                onChanged: (v) => upd(() {
                  s.low = v.start.round();
                  s.high = v.end.round();
                }),
              ),
              Row(children: [
                const Text('Oktáv'),
                IconButton(onPressed: () => upd(() => s.transpose = (s.transpose - 12).clamp(-24, 24)), icon: const Icon(Icons.remove)),
                Text('${s.transpose ~/ 12}'),
                IconButton(onPressed: () => upd(() => s.transpose = (s.transpose + 12).clamp(-24, 24)), icon: const Icon(Icons.add)),
                const Spacer(),
                Text('Csak erős leütésre (vel ≥ ${s.velLow})'),
              ]),
              Slider(value: s.velLow.toDouble(), min: 1, max: 127, onChanged: (v) => upd(() => s.velLow = v.round())),
              Row(children: [
                const SizedBox(width: 110, child: Text('Velocity-görbe')),
                Expanded(child: Slider(value: s.curve, min: 0.5, max: 2, onChanged: (v) => upd(() => s.curve = v))),
                Text(s.curve.toStringAsFixed(2)),
              ]),
              Row(children: [
                const SizedBox(width: 110, child: Text('Hangerő')),
                Expanded(child: Slider(value: s.volume.toDouble(), max: 127, onChanged: (v) => upd(() => s.volume = v.round()))),
                Text('${s.volume}'),
              ]),
              const Divider(),
              const Text('Hangszín (Bank MSB / LSB / Program)'),
              Row(children: [
                for (final (label, getter, setter) in [
                  ('MSB', () => s.msb, (int v) => s.msb = v),
                  ('LSB', () => s.lsb, (int v) => s.lsb = v),
                  ('Program', () => s.program + 1, (int v) => s.program = v - 1),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextFormField(
                        initialValue: '${getter()}',
                        decoration: InputDecoration(labelText: label),
                        keyboardType: TextInputType.number,
                        onChanged: (t) {
                          final v = int.tryParse(t);
                          if (v != null) upd(() => setter(v.clamp(label == 'Program' ? 1 : 0, label == 'Program' ? 128 : 127)));
                        },
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
          actions: [
            TextButton.icon(onPressed: onSendVoice, icon: const Icon(Icons.send), label: const Text('Hangszín küldése')),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kész')),
          ],
        );
      }),
    );

// ---------------------------------------------------------------------------
// Hangerő-normalizálás (ugyanaz a képlet, mint a C++ magban)
// ---------------------------------------------------------------------------
String normalizeText(String lufsText, String ccText) {
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

Future<void> showNormalizeDialog(BuildContext context) {
  final lufsCtrl = TextEditingController(text: '-22.5');
  final ccCtrl = TextEditingController(text: '100 90 110 80');
  var result = '';
  return showDialog<void>(
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
            onPressed: () => setD(() => result = normalizeText(lufsCtrl.text, ccCtrl.text)),
            child: const Text('Számítás'),
          ),
        ],
      ),
    ),
  );
}
