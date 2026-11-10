// lib/score/lead_sheet.dart — dallamkotta akkordjelekkel (lead sheet), tempóval görgetve
import '../i18n/i18n.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/chordpro.dart';
import '../model/project.dart';
import '../reader/teleprompter_controller.dart';

/// Az akkordok időzítése a dalszövegből: egy sor = barsPerLine ütem,
/// a sor akkordjai egyenletesen oszlanak el ezeken az ütemeken.
List<(double bar, String chord)> chordTimeline(Song song) {
  final out = <(double, String)>[];
  var bar = 0.0;
  for (final raw in song.body.split('\n')) {
    final l = parseLine(raw);
    if (l.kind != LineKind.lyric) continue;
    final chords = [for (final s in l.segments) if (s.chord != null) transposeChord(s.chord!, song.transpose)];
    for (var i = 0; i < chords.length; i++) {
      out.add((bar + i * song.barsPerLine / chords.length, chords[i]));
    }
    bar += song.barsPerLine;
  }
  return out;
}

class LeadSheetLayout {
  LeadSheetLayout(this.song, this.theme, {this.barsPerSystem = 4}) {
    final sc = song.score;
    beatsPerBar = sc?.beatsPerBar ?? song.beatsPerBar;
    lineSpace = (theme.fontSize / 3).clamp(7.0, 15.0);
    systemHeight = lineSpace * 15;
    var lastBeat = 0.0;
    for (final n in sc?.notes ?? const <ScoreNote>[]) {
      lastBeat = math.max(lastBeat, n.start + n.beats);
    }
    final chords = chordTimeline(song);
    final lastChordBar = chords.isEmpty ? 0.0 : chords.last.$1 + 1;
    totalBars = math.max((lastBeat / beatsPerBar).ceil(), lastChordBar.ceil()).clamp(1, 2000);
    systems = (totalBars / barsPerSystem).ceil();
    for (var i = 0; i <= systems; i++) {
      anchors.add(Anchor((i * barsPerSystem).toDouble(), i * systemHeight));
    }
  }

  final Song song;
  final ThemeSettings theme;
  final int barsPerSystem;
  late final int beatsPerBar, totalBars, systems;
  late final double lineSpace, systemHeight;
  final anchors = <Anchor>[];
  double get totalHeight => systems * systemHeight;
}

class ScoreView extends StatelessWidget {
  const ScoreView({super.key, required this.layout, required this.scroll, this.reader, this.header});
  final LeadSheetLayout layout;
  final ScrollController scroll;
  final TeleprompterController? reader;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    if (layout.song.score == null) {
      return Center(
        child: Text(tr('Ehhez a dalhoz még nincs kotta.\nA PC-n: Dal szerkesztése → Kotta → MIDI importálása.'),
            textAlign: TextAlign.center, style: TextStyle(color: layout.theme.textColor.withValues(alpha: 0.7))),
      );
    }
    return SingleChildScrollView(
      controller: scroll,
      padding: const EdgeInsets.only(bottom: 300),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (header != null) header!,
        LayoutBuilder(
          builder: (ctx, box) => reader == null
              ? CustomPaint(size: Size(box.maxWidth, layout.totalHeight), painter: LeadSheetPainter(layout, -1))
              : AnimatedBuilder(
                  animation: reader!,
                  builder: (_, __) => CustomPaint(
                    size: Size(box.maxWidth, layout.totalHeight),
                    painter: LeadSheetPainter(layout, reader!.currentBar),
                  ),
                ),
        ),
      ]),
    );
  }
}

class LeadSheetPainter extends CustomPainter {
  LeadSheetPainter(this.l, this.currentBar);
  final LeadSheetLayout l;
  final double currentBar;

  static const _steps = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6];
  static const _black = [false, true, false, true, false, false, true, false, true, false, true, false];

  void _text(Canvas c, String s, Offset at, TextStyle st, {bool center = false}) {
    final tp = TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = l.theme;
    final ls = l.lineSpace;
    final ink = Paint()
      ..color = t.textColor
      ..strokeWidth = 1.2;
    final thin = Paint()
      ..color = t.textColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    const left = 16.0;
    final clefW = ls * 3.2;
    final barW = (size.width - left * 2 - clefW) / l.barsPerSystem;
    final sc = l.song.score!;
    final chords = chordTimeline(l.song);

    for (var sys = 0; sys < l.systems; sys++) {
      final top = sys * l.systemHeight + ls * 5; // felső vonal
      final bottom = top + ls * 4;
      // aktuális ütem kiemelése
      final curSys = (currentBar / l.barsPerSystem).floor();
      if (currentBar >= 0 && curSys == sys) {
        final b = currentBar.floor() - sys * l.barsPerSystem;
        canvas.drawRect(Rect.fromLTWH(left + clefW + b * barW, top - ls * 3, barW, ls * 10),
            Paint()..color = t.highlight.withValues(alpha: 0.18));
      }
      for (var k = 0; k < 5; k++) {
        canvas.drawLine(Offset(left, top + k * ls), Offset(size.width - left, top + k * ls), thin);
      }
      _text(canvas, '𝄞', Offset(left - ls * 0.2, top - ls * 2.6),
          TextStyle(fontSize: ls * 6.8, color: t.textColor, fontFamilyFallback: const ['Segoe UI Symbol', 'Noto Music', 'Apple Symbols', 'Bravura']));
      for (var b = 0; b <= l.barsPerSystem; b++) {
        final x = left + clefW + b * barW;
        canvas.drawLine(Offset(x, top), Offset(x, bottom), ink);
        final barNo = sys * l.barsPerSystem + b + 1;
        if (b < l.barsPerSystem && barNo <= l.totalBars) {
          _text(canvas, '$barNo', Offset(x + 2, bottom + ls * 0.6), TextStyle(fontSize: ls * 1.1, color: t.textColor.withValues(alpha: 0.4)));
        }
      }

      double xOfBeat(double beat) {
        final bar = beat / l.beatsPerBar - sys * l.barsPerSystem;
        final inBar = bar - bar.floor();
        return left + clefW + bar.floor() * barW + ls * 1.6 + inBar * (barW - ls * 2.4);
      }

      // akkordjelek
      for (final (bar, chord) in chords) {
        if (bar < sys * l.barsPerSystem || bar >= (sys + 1) * l.barsPerSystem) continue;
        _text(canvas, chord, Offset(xOfBeat(bar * l.beatsPerBar) - ls * 0.6, top - ls * 3.6),
            TextStyle(fontFamily: t.fontFamily, fontSize: ls * 1.9, fontWeight: FontWeight.w700, color: t.chordColor));
      }

      // hangjegyek
      for (final n in sc.notes) {
        final bar = n.start / l.beatsPerBar;
        if (bar < sys * l.barsPerSystem || bar >= (sys + 1) * l.barsPerSystem) continue;
        final pc = n.pitch % 12, oct = n.pitch ~/ 12 - 1;
        final pos = oct * 7 + _steps[pc] - (4 * 7 + 2); // 0 = alsó vonal (E4)
        final y = bottom - pos * ls / 2;
        final x = xOfBeat(n.start);
        final active = currentBar >= 0 && currentBar * l.beatsPerBar >= n.start && currentBar * l.beatsPerBar < n.start + n.beats;
        final col = active ? t.highlight : t.textColor;
        final p = Paint()
          ..color = col
          ..strokeWidth = 1.4;
        // pótvonalak
        for (var q = -2; q >= pos; q -= 2) {
          final ly = bottom - q * ls / 2;
          canvas.drawLine(Offset(x - ls * 0.9, ly), Offset(x + ls * 0.9, ly), thin);
        }
        for (var q = 10; q <= pos; q += 2) {
          final ly = bottom - q * ls / 2;
          canvas.drawLine(Offset(x - ls * 0.9, ly), Offset(x + ls * 0.9, ly), thin);
        }
        final d = n.beats;
        final hollow = d >= 2;
        final head = Rect.fromCenter(center: Offset(x, y), width: ls * 1.35, height: ls * 0.95);
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-0.35);
        canvas.translate(-x, -y);
        canvas.drawOval(head, hollow ? (Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6) : p);
        canvas.restore();
        if (_black[pc]) {
          _text(canvas, '♯', Offset(x - ls * 2.1, y - ls * 1.1), TextStyle(fontSize: ls * 1.7, color: col));
        }
        // szár és zászló
        if (d < 4) {
          final up = pos < 4;
          final sx = up ? x + ls * 0.62 : x - ls * 0.62;
          final sy2 = up ? y - ls * 3.3 : y + ls * 3.3;
          canvas.drawLine(Offset(sx, y), Offset(sx, sy2), p);
          final flags = d < 0.5 ? 2 : (d < 1 ? 1 : 0);
          for (var f = 0; f < flags; f++) {
            final fy = sy2 + (up ? f * ls * 0.8 : -f * ls * 0.8);
            canvas.drawLine(Offset(sx, fy), Offset(sx + ls * 0.9, fy + (up ? ls * 1.2 : -ls * 1.2)), p);
          }
        }
        // pont (pontozott érték)
        const dotted = [3.0, 1.5, 0.75];
        if (dotted.any((v) => (v - d).abs() < 1e-6)) {
          canvas.drawCircle(Offset(x + ls * 1.1, y - (pos.isEven ? ls * 0.4 : 0)), ls * 0.18, p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant LeadSheetPainter old) => old.currentBar != currentBar || !identical(old.l, l);
}
