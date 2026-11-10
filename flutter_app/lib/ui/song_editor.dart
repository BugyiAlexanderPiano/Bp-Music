// lib/ui/song_editor.dart — dal-szerkesztő: szöveg + akkordok + tempó + hangnem (élő előnézettel)
import '../i18n/i18n.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:file_selector/file_selector.dart';

import '../model/chordpro.dart';
import '../model/project.dart';
import '../score/lead_sheet.dart';
import '../score/midi_file.dart';
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
  bool previewScore = false;

  /// MIDI import: sáv- és rácsválasztás, majd kotta létrehozása
  Future<void> _importMidi() async {
    final f = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'MIDI', extensions: ['mid', 'midi', 'kar'])]);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    MidiFile mf;
    try {
      mf = MidiFile.parse(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('A MIDI fájl nem olvasható: {0}', [e]))));
      }
      return;
    }
    var track = mf.guessMelodyTrack();
    var grid = 0.5;
    var takeTempo = true;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(tr('Kotta: {0}', [f.name])),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Melyik sáv a dallam?')),
              DropdownButton<int>(
                isExpanded: true,
                value: track,
                items: [
                  for (final t in mf.tracks)
                    if (t.noteCount > 0) DropdownMenuItem(value: t.index, child: Text(t.label)),
                ],
                onChanged: (v) => setD(() => track = v!),
              ),
              const SizedBox(height: 10),
              Text(tr('Ritmikai rács (kvantálás):')),
              SegmentedButton<double>(
                segments: [
                  ButtonSegment(value: 0.5, label: Text(tr('Nyolcad'))),
                  ButtonSegment(value: 0.25, label: Text(tr('Tizenhatod'))),
                ],
                selected: {grid},
                onSelectionChanged: (v) => setD(() => grid = v.first),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Tempó és ütemmutató átvétele ({0} BPM, {1}/4)', [mf.firstBpm.round(), mf.beatsPerBar])),
                value: takeTempo,
                onChanged: (v) => setD(() => takeTempo = v ?? true),
              ),
              Text(tr('A teljes MIDI a dalhoz csatolódik: a tableten a „Dal lejátszása” gomb ezt játssza le a hangszeren.'),
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Mégse'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Kotta létrehozása'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() {
      song.scores.add(SongScore(
        name: f.name.replaceAll(RegExp(r'\.(mid|midi|kar)$', caseSensitive: false), ''),
        midiB64: base64Encode(bytes),
        melodyTrack: track,
        notes: mf.melody(track, grid: grid),
        beatsPerBar: mf.beatsPerBar,
        bpm: mf.firstBpm,
      ));
      song.activeScore = song.scores.length - 1;
      if (takeTempo) {
        song.bpm = mf.firstBpm.roundToDouble();
        bpmCtrl.text = song.bpm.round().toString();
        song.timeSig = '${mf.beatsPerBar}/4';
        if (!timeChoices.contains(song.timeSig)) song.timeSig = '4/4';
      }
      previewScore = true;
    });
  }

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
            Text(tr('Dal szerkesztése'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Mégse'))),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () {
                song
                  ..title = titleCtrl.text.trim().isEmpty ? tr('Névtelen dal') : titleCtrl.text.trim()
                  ..artist = artistCtrl.text.trim()
                  ..style = styleCtrl.text.trim()
                  ..bpm = (double.tryParse(bpmCtrl.text) ?? song.bpm).clamp(30.0, 300.0)
                  ..body = bodyCtrl.text;
                Navigator.pop(context, song);
              },
              icon: const Icon(Icons.check),
              label: Text(tr('Mentés')),
            ),
          ]),
        ),
        // Zenei adatok
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: [
            _field(tr('Cím'), TextField(controller: titleCtrl, onChanged: (v) => setState(() => song.title = v)), width: 230),
            _field(tr('Előadó'), TextField(controller: artistCtrl, onChanged: (v) => setState(() => song.artist = v)), width: 170),
            _field(
              tr('Hangnem'),
              DropdownButton<String>(
                isExpanded: true,
                value: keyChoices.contains(song.key) ? song.key : 'C',
                items: [for (final k in keyChoices) DropdownMenuItem(value: k, child: Text(k))],
                onChanged: (v) => setState(() => song.key = v!),
              ),
              width: 90,
            ),
            _field(
              tr('Tempó (BPM)'),
              TextField(
                controller: bpmCtrl,
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(() => song.bpm = (double.tryParse(v) ?? song.bpm).clamp(30.0, 300.0)),
              ),
              width: 90,
            ),
            _field(
              tr('Ütemmutató'),
              DropdownButton<String>(
                isExpanded: true,
                value: timeChoices.contains(song.timeSig) ? song.timeSig : '4/4',
                items: [for (final t in timeChoices) DropdownMenuItem(value: t, child: Text(t))],
                onChanged: (v) => setState(() => song.timeSig = v!),
              ),
              width: 90,
            ),
            _field(tr('Stílus (a hangszeren)'), TextField(controller: styleCtrl, onChanged: (v) => setState(() => song.style = v)), width: 170),
            _field(
              tr('Indító szakasz'),
              DropdownButton<int>(
                isExpanded: true,
                value: song.mainSection,
                items: [for (final e in mainChoices.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => song.mainSection = v!),
              ),
              width: 110,
            ),
            _field(
              tr('Ütem / sor'),
              DropdownButton<int>(
                isExpanded: true,
                value: song.barsPerLine,
                items: [for (final v in [1, 2, 4, 8]) DropdownMenuItem(value: v, child: Text('$v'))],
                onChanged: (v) => setState(() => song.barsPerLine = v!),
              ),
              width: 80,
            ),
            _field(
              tr('Transzponálás'),
              Row(children: [
                IconButton(onPressed: () => setState(() => song.transpose--), icon: const Icon(Icons.remove, size: 18)),
                Text('${song.transpose > 0 ? '+' : ''}${song.transpose}'),
                IconButton(onPressed: () => setState(() => song.transpose++), icon: const Icon(Icons.add, size: 18)),
              ]),
              width: 130,
            ),
            _field(
              tr('Regisztráció'),
              DropdownButton<int>(
                isExpanded: true,
                value: regValue < widget.bankCount * 8 ? regValue : -1,
                items: [
                  const DropdownMenuItem(value: -1, child: Text('nincs')),
                  for (var b = 0; b < widget.bankCount; b++)
                    for (var s = 0; s < 8; s++)
                      DropdownMenuItem(value: b * 8 + s, child: Text(tr('Bank {0} / {1}', [b + 1, s + 1]))),
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
            Text(tr('Akkord beszúrása: '), style: TextStyle(fontSize: 12)),
            for (final c in diatonicChords(song.key))
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ActionChip(label: Text(c), onPressed: () => _insert('[$c]')),
              ),
            const SizedBox(width: 12),
            Text(tr('Szakasz: '), style: TextStyle(fontSize: 12)),
            for (final s in ['Intro', 'Main A', 'Main B', 'Main C', 'Main D', 'Break', 'Ending'])
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ActionChip(label: Text(s), onPressed: () => _insert('{$s}\n')),
              ),
          ])),
        ),
        // Kották
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              Text(tr('Kotta: '), style: TextStyle(fontSize: 12)),
              for (var k = 0; k < song.scores.length; k++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InputChip(
                    selected: k == song.activeScore,
                    label: Text(tr('{0} ({1} hang)', [song.scores[k].name, song.scores[k].notes.length])),
                    onPressed: () => setState(() => song.activeScore = k),
                    onDeleted: () => setState(() {
                      song.scores.removeAt(k);
                      song.activeScore = 0;
                    }),
                  ),
                ),
              ActionChip(avatar: const Icon(Icons.library_music, size: 16), label: Text(tr('MIDI importálása…')), onPressed: _importMidi),
              const SizedBox(width: 12),
              Text(tr('Automatikus kottázás MP3/MP4-ből: B. szakasz'),
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45))),
            ]),
          ),
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
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: tr('[G]Szöveg [D]akkordokkal\n{Main A} szakasz\n# megjegyzés'),
                  ),
                  onChanged: (v) => setState(() => song.body = v),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 20, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (song.score != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(value: false, label: Text(tr('Előnézet: szöveg'))),
                          ButtonSegment(value: true, label: Text(tr('Előnézet: kotta'))),
                        ],
                        selected: {previewScore},
                        onSelectionChanged: (v) => setState(() => previewScore = v.first),
                      ),
                    ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: DecoratedBox(
                        decoration: widget.theme.backgroundDecoration,
                        child: previewScore && song.score != null
                            ? ScoreView(layout: LeadSheetLayout(song, widget.theme), scroll: previewScroll)
                            : SongPage(
                                song: song,
                                layout: SongLayout(song, widget.theme),
                                theme: widget.theme,
                                scroll: previewScroll,
                                reader: null,
                              ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
