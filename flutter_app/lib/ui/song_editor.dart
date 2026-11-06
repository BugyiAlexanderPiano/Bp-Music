// lib/ui/song_editor.dart — dal-szerkesztő: szöveg + akkordok + tempó + hangnem (élő előnézettel)
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/chordpro.dart';
import '../model/project.dart';
import 'song_view.dart';

const keyChoices = [
  'C', 'C#', 'Db', 'D', 'Eb', 'E', 'F', 'F#', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B',
  'Cm', 'C#m', 'Dm', 'D#m', 'Ebm', 'Em', 'Fm', 'F#m', 'Gm', 'G#m', 'Am', 'Bbm', 'Bm',
];
const timeChoices = ['2/4', '3/4', '4/4', '6/8', '12/8'];
const mainChoices = {0x08: 'Main A', 0x09: 'Main B', 0x0A: 'Main C', 0x0B: 'Main D'};

/// A hangnem lépcsőfokain lévő akkordok (gyors beszúráshoz)
List<String> diatonicChords(String key) {
  final minor = key.endsWith('m');
  final root = minor ? key.substring(0, key.length - 1) : key;
  final base = minor
      ? const ['Am', 'C', 'Dm', 'Em', 'E7', 'F', 'G']
      : const ['C', 'Dm', 'Em', 'F', 'G', 'G7', 'Am'];
  final shift = _semitonesFrom(minor ? 'A' : 'C', root);
  return [for (final c in base) transposeChord(c, shift)];
}

int _semitonesFrom(String from, String to) {
  const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  const flats = {'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#'};
  final a = names.indexOf(flats[from] ?? from), b = names.indexOf(flats[to] ?? to);
  if (a < 0 || b < 0) return 0;
  return (b - a + 12) % 12;
}

Future<Song?> showSongEditor(BuildContext context, Song original, ThemeSettings theme, int bankCount) =>
    showDialog<Song>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: _SongEditor(original: original, theme: theme, bankCount: bankCount),
      ),
    );

class _SongEditor extends StatefulWidget {
  const _SongEditor({required this.original, required this.theme, required this.bankCount});
  final Song original;
  final ThemeSettings theme;
  final int bankCount;
  @override
  State<_SongEditor> createState() => _SongEditorState();
}

class _SongEditorState extends State<_SongEditor> {
  late final Song song = widget.original.copy();
  late final titleCtrl = TextEditingController(text: song.title);
  late final artistCtrl = TextEditingController(text: song.artist);
  late final styleCtrl = TextEditingController(text: song.style);
  late final bpmCtrl = TextEditingController(text: song.bpm.round().toString());
  late final bodyCtrl = TextEditingController(text: song.body);
  final previewScroll = ScrollController();

  @override
  void dispose() {
    for (final c in [titleCtrl, artistCtrl, styleCtrl, bpmCtrl, bodyCtrl]) {
      c.dispose();
    }
    previewScroll.dispose();
    super.dispose();
  }

  void _insert(String text) {
    final sel = bodyCtrl.selection;
    final s = bodyCtrl.text;
    final start = sel.isValid ? sel.start : s.length;
    final end = sel.isValid ? sel.end : s.length;
    bodyCtrl.value = TextEditingValue(
      text: s.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    setState(() => song.body = bodyCtrl.text);
  }

  Widget _field(String label, Widget child, {double width = 140}) => SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          child,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final regValue = song.registration == null ? -1 : song.registration!.bank * 8 + song.registration!.slot;
    final screen = MediaQuery.sizeOf(context);
    return SizedBox(
      width: math.min(1180, screen.width - 48),
      height: math.min(760, screen.height - 48),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(children: [
            const Text('Dal szerkesztése', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Mégse')),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () {
                song
                  ..title = titleCtrl.text.trim().isEmpty ? 'Névtelen dal' : titleCtrl.text.trim()
                  ..artist = artistCtrl.text.trim()
                  ..style = styleCtrl.text.trim()
                  ..bpm = (double.tryParse(bpmCtrl.text) ?? song.bpm).clamp(30.0, 300.0)
                  ..body = bodyCtrl.text;
                Navigator.pop(context, song);
              },
              icon: const Icon(Icons.check),
              label: const Text('Mentés'),
            ),
          ]),
        ),
        // Zenei adatok
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: [
            _field('Cím', TextField(controller: titleCtrl, onChanged: (v) => setState(() => song.title = v)), width: 230),
            _field('Előadó', TextField(controller: artistCtrl, onChanged: (v) => setState(() => song.artist = v)), width: 170),
            _field(
              'Hangnem',
              DropdownButton<String>(
                isExpanded: true,
                value: keyChoices.contains(song.key) ? song.key : 'C',
                items: [for (final k in keyChoices) DropdownMenuItem(value: k, child: Text(k))],
                onChanged: (v) => setState(() => song.key = v!),
              ),
              width: 90,
            ),
            _field(
              'Tempó (BPM)',
              TextField(
                controller: bpmCtrl,
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(() => song.bpm = (double.tryParse(v) ?? song.bpm).clamp(30.0, 300.0)),
              ),
              width: 90,
            ),
            _field(
              'Ütemmutató',
              DropdownButton<String>(
                isExpanded: true,
                value: timeChoices.contains(song.timeSig) ? song.timeSig : '4/4',
                items: [for (final t in timeChoices) DropdownMenuItem(value: t, child: Text(t))],
                onChanged: (v) => setState(() => song.timeSig = v!),
              ),
              width: 90,
            ),
            _field('Stílus (a hangszeren)', TextField(controller: styleCtrl, onChanged: (v) => setState(() => song.style = v)), width: 170),
            _field(
              'Indító szakasz',
              DropdownButton<int>(
                isExpanded: true,
                value: song.mainSection,
                items: [for (final e in mainChoices.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => song.mainSection = v!),
              ),
              width: 110,
            ),
            _field(
              'Ütem / sor',
              DropdownButton<int>(
                isExpanded: true,
                value: song.barsPerLine,
                items: [for (final v in [1, 2, 4, 8]) DropdownMenuItem(value: v, child: Text('$v'))],
                onChanged: (v) => setState(() => song.barsPerLine = v!),
              ),
              width: 80,
            ),
            _field(
              'Transzponálás',
              Row(children: [
                IconButton(onPressed: () => setState(() => song.transpose--), icon: const Icon(Icons.remove, size: 18)),
                Text('${song.transpose > 0 ? '+' : ''}${song.transpose}'),
                IconButton(onPressed: () => setState(() => song.transpose++), icon: const Icon(Icons.add, size: 18)),
              ]),
              width: 130,
            ),
            _field(
              'Regisztráció',
              DropdownButton<int>(
                isExpanded: true,
                value: regValue < widget.bankCount * 8 ? regValue : -1,
                items: [
                  const DropdownMenuItem(value: -1, child: Text('nincs')),
                  for (var b = 0; b < widget.bankCount; b++)
                    for (var s = 0; s < 8; s++)
                      DropdownMenuItem(value: b * 8 + s, child: Text('Bank ${b + 1} / ${s + 1}')),
                ],
                onChanged: (v) => setState(() => song.registration = v == null || v < 0 ? null : (bank: v ~/ 8, slot: v % 8)),
              ),
              width: 150,
            ),
          ]),
        ),
        const SizedBox(height: 10),
        // Gyors beszúrás
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            const Text('Akkord beszúrása: ', style: TextStyle(fontSize: 12)),
            for (final c in diatonicChords(song.key))
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ActionChip(label: Text(c), onPressed: () => _insert('[$c]')),
              ),
            const SizedBox(width: 12),
            const Text('Szakasz: ', style: TextStyle(fontSize: 12)),
            for (final s in ['Intro', 'Main A', 'Main B', 'Main C', 'Main D', 'Break', 'Ending'])
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ActionChip(label: Text(s), onPressed: () => _insert('{$s}\n')),
              ),
          ])),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 10, 20),
                child: TextField(
                  controller: bodyCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 15, height: 1.5),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '[G]Szöveg [D]akkordokkal\n{Main A} szakasz\n# megjegyzés',
                  ),
                  onChanged: (v) => setState(() => song.body = v),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 20, 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: DecoratedBox(
                    decoration: widget.theme.backgroundDecoration,
                    child: SongPage(
                      song: song,
                      layout: SongLayout(song, widget.theme),
                      theme: widget.theme,
                      scroll: previewScroll,
                      reader: null,
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
