// lib/ui/song_view.dart — egy dal oldala: fejléc (zenei adatok) + szöveg akkordokkal
import '../i18n/i18n.dart';
import 'package:flutter/material.dart';

import '../model/chordpro.dart';
import '../model/project.dart';
import '../reader/teleprompter_controller.dart';

/// Egy dal kiszámolt elrendezése: soronkénti magasság, y-pozíció, ütemek.
class SongLayout {
  SongLayout(Song song, ThemeSettings t) {
    final chordSize = t.fontSize * 0.55;
    var y = headerHeight;
    var bar = 0.0;
    for (final raw in song.body.split('\n')) {
      final l = parseLine(raw);
      if (l.kind == LineKind.comment) continue;
      final h = switch (l.kind) {
        LineKind.lyric => t.fontSize * 1.45 + (l.hasChords ? chordSize * 1.45 : 0),
        LineKind.section => 40.0,
        _ => t.fontSize * 0.5,
      };
      lines.add(l);
      heights.add(h);
      ys.add(y);
      if (l.kind == LineKind.lyric) {
        barStart.add(bar);
        anchors.add(Anchor(bar, y));
        bar += song.barsPerLine;
      } else {
        barStart.add(-1);
      }
      y += h;
    }
    anchors.add(Anchor(bar, y));
    if (anchors.length < 2) anchors.insert(0, const Anchor(0, 0));
    totalHeight = y;
    totalBars = bar;
  }

  static const headerHeight = 96.0;
  final lines = <SongLine>[];
  final heights = <double>[];
  final ys = <double>[];
  final barStart = <double>[];
  final anchors = <Anchor>[];
  late final double totalHeight, totalBars;

  int currentLine(double bar, int barsPerLine) {
    for (var i = 0; i < lines.length; i++) {
      final b = barStart[i];
      if (b >= 0 && bar >= b && bar < b + barsPerLine) return i;
    }
    return -1;
  }
}

class SongPage extends StatelessWidget {
  const SongPage({
    super.key,
    required this.song,
    required this.layout,
    required this.theme,
    required this.scroll,
    required this.reader,
  });

  final Song song;
  final SongLayout layout;
  final ThemeSettings theme;
  final ScrollController scroll;
  final TeleprompterController? reader;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return SingleChildScrollView(
      controller: scroll,
      padding: const EdgeInsets.only(bottom: 420),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: SongLayout.headerHeight, child: SongHeader(song: song, theme: t)),
        if (reader == null)
          ..._lines(context, -1)
        else
          AnimatedBuilder(
            animation: reader!,
            builder: (ctx, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _lines(ctx, layout.currentLine(reader!.currentBar, song.barsPerLine)),
            ),
          ),
      ]),
    );
  }

  List<Widget> _lines(BuildContext context, int current) {
    final t = theme;
    final chordSize = t.fontSize * 0.55;
    final family = t.fontFamily;
    return [
      for (var i = 0; i < layout.lines.length; i++)
        SizedBox(
          height: layout.heights[i],
          child: switch (layout.lines[i].kind) {
            LineKind.section => Padding(
                padding: const EdgeInsets.only(left: 24, top: 8),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.sectionColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: t.sectionColor.withValues(alpha: 0.6)),
                    ),
                    child: Text(layout.lines[i].label,
                        style: TextStyle(fontFamily: family, color: t.sectionColor, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            LineKind.lyric => Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.bottomLeft,
                decoration: i == current
                    ? BoxDecoration(
                        gradient: LinearGradient(colors: [
                          t.highlight.withValues(alpha: 0.28),
                          t.highlight.withValues(alpha: 0.04),
                        ]),
                        border: Border(left: BorderSide(color: t.highlight, width: 4)),
                      )
                    : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final seg in layout.lines[i].segments)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (layout.lines[i].hasChords)
                              Text(
                                seg.chord == null ? ' ' : '${transposeChord(seg.chord!, song.transpose)}  ',
                                style: TextStyle(
                                  fontFamily: family,
                                  color: t.chordColor,
                                  fontSize: chordSize,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            Text(
                              seg.text,
                              style: TextStyle(
                                fontFamily: family,
                                fontSize: t.fontSize,
                                fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
                                color: current > i && current >= 0
                                    ? t.textColor.withValues(alpha: 0.4)
                                    : t.textColor,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            _ => const SizedBox(),
          },
        ),
    ];
  }
}

/// A dal zenei paraméterei: a megnyitás pillanatában látszik minden
class SongHeader extends StatelessWidget {
  const SongHeader({super.key, required this.song, required this.theme});
  final Song song;
  final ThemeSettings theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final key = song.transpose == 0
        ? song.key
        : tr('{0} (eredeti: {1})', [transposeChord(song.key, song.transpose), song.key]);
    Widget chip(IconData ic, String label) => Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.accent.withValues(alpha: 0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 15, color: t.textColor.withValues(alpha: 0.8)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: t.textColor, fontSize: 14)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          song.artist.isEmpty ? song.title : '${song.title}  ·  ${song.artist}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: t.fontFamily, color: t.textColor, fontSize: 26, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            chip(Icons.music_note, tr('Hangnem: {0}', [key])),
            chip(Icons.speed, '${song.bpm.round()} BPM'),
            chip(Icons.straighten, song.timeSig),
            if (song.style.isNotEmpty) chip(Icons.queue_music, song.style),
            if (song.registration != null)
              chip(Icons.bookmark, 'Reg: ${song.registration!.bank + 1}/${song.registration!.slot + 1}'),
          ]),
        ),
      ]),
    );
  }
}
