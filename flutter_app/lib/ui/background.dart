// lib/ui/background.dart — háttér: egyszínű / átmenetes / mozgó átmenet + saját háttérkép
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../model/project.dart';
import 'als_button.dart';

class AppBackground extends StatefulWidget {
  const AppBackground({super.key, required this.project, required this.child});
  final Project project;
  final Widget child;
  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _phase = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) {
      final t = widget.project.theme;
      if (!t.animate) return;
      _phase.value = (e.inMilliseconds / 1000.0) / math.max(2.0, t.animSeconds);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _phase.dispose();
    super.dispose();
  }

  Decoration _decoration(ThemeSettings t, double phase) {
    if (t.mode == BackgroundMode.solid || t.background.length < 2) return BoxDecoration(color: t.background.first);
    if (!t.animate) return t.backgroundDecoration;
    final a = phase * 2 * math.pi;
    final begin = Alignment(math.cos(a), math.sin(a));
    var colors = t.background;
    if (t.animateHue) {
      final shift = (phase * 360) % 360;
      colors = [for (final c in colors) HSVColor.fromColor(c).withHue((HSVColor.fromColor(c).hue + shift) % 360).toColor()];
    }
    return BoxDecoration(gradient: LinearGradient(begin: begin, end: -begin, colors: colors));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.project.theme;
    final img = ImageStore.of(widget.project, t.bgImage);
    return Stack(fit: StackFit.expand, children: [
      ValueListenableBuilder<double>(
        valueListenable: _phase,
        builder: (_, phase, __) => DecoratedBox(decoration: _decoration(t, phase)),
      ),
      if (img != null)
        Opacity(
          opacity: t.bgOpacity.clamp(0.0, 1.0),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: t.bgBlur, sigmaY: t.bgBlur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: img,
                  fit: t.bgFit == 'contain' ? BoxFit.contain : (t.bgFit == 'tile' ? BoxFit.none : BoxFit.cover),
                  repeat: t.bgFit == 'tile' ? ImageRepeat.repeat : ImageRepeat.noRepeat,
                ),
              ),
            ),
          ),
        ),
      if (img != null && t.bgDarken > 0) ColoredBox(color: Colors.black.withValues(alpha: t.bgDarken.clamp(0.0, 0.95))),
      widget.child,
    ]);
  }
}
