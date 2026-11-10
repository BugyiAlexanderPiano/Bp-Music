// lib/ui/color_picker.dart — beépített HSV színválasztó (külső csomag nélkül)
import '../i18n/i18n.dart';
import 'package:flutter/material.dart';

const colorSwatches = <Color>[
  Color(0xFF0E1525), Color(0xFF1B1035), Color(0xFF0B2A2E), Color(0xFF2A0F17), Color(0xFF111111),
  Color(0xFF4F8CFF), Color(0xFF7C4DFF), Color(0xFF00BFA5), Color(0xFFFF6E40), Color(0xFFFFC34D),
  Color(0xFFE91E63), Color(0xFF43A047), Color(0xFFF2F4F8), Color(0xFF9E9E9E), Color(0xFF263238),
];

Future<Color?> pickColor(BuildContext context, Color initial, {String? title}) =>
    showDialog<Color>(context: context, builder: (_) => _ColorPickerDialog(initial: initial, title: title ?? tr('Szín kiválasztása')));

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial, required this.title});
  final Color initial;
  final String title;
  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor hsv = HSVColor.fromColor(widget.initial);
  late final hexCtrl = TextEditingController(text: _hex(widget.initial));

  static String _hex(Color c) => c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

  void _set(HSVColor v, {bool updateHex = true}) {
    setState(() => hsv = v);
    if (updateHex) hexCtrl.text = _hex(v.toColor());
  }

  @override
  void dispose() {
    hexCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = hsv.toColor();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Telítettség / fényerő mező
          SizedBox(
            height: 190,
            child: LayoutBuilder(builder: (ctx, box) {
              void pick(Offset p) => _set(hsv
                  .withSaturation((p.dx / box.maxWidth).clamp(0.0, 1.0))
                  .withValue(1 - (p.dy / box.maxHeight).clamp(0.0, 1.0)));
              return GestureDetector(
                onPanDown: (d) => pick(d.localPosition),
                onPanUpdate: (d) => pick(d.localPosition),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(fit: StackFit.expand, children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.white,
                          HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                        ]),
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black],
                        ),
                      ),
                    ),
                    Positioned(
                      left: hsv.saturation * box.maxWidth - 9,
                      top: (1 - hsv.value) * box.maxHeight - 9,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black54)],
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // Színárnyalat csúszka
          SizedBox(
            height: 22,
            child: LayoutBuilder(builder: (ctx, box) {
              void pick(Offset p) => _set(hsv.withHue((p.dx / box.maxWidth).clamp(0.0, 1.0) * 359.9));
              return GestureDetector(
                onPanDown: (d) => pick(d.localPosition),
                onPanUpdate: (d) => pick(d.localPosition),
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: LinearGradient(colors: [
                        for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble() % 360, 1, 1).toColor(),
                      ]),
                    ),
                  ),
                  Positioned(
                    left: hsv.hue / 360 * box.maxWidth - 6,
                    top: -2,
                    child: Container(
                      width: 12,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black54)],
                      ),
                    ),
                  ),
                ]),
              );
            }),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: TextField(
                controller: hexCtrl,
                decoration: const InputDecoration(prefixText: '#', labelText: 'HEX'),
                onSubmitted: (t) {
                  final v = int.tryParse(t.replaceAll('#', ''), radix: 16);
                  if (v != null && t.replaceAll('#', '').length == 6) {
                    _set(HSVColor.fromColor(Color(0xFF000000 | v)), updateHex: false);
                  }
                },
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in colorSwatches)
              InkWell(
                onTap: () => _set(HSVColor.fromColor(c)),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
              ),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Mégse'))),
        FilledButton(onPressed: () => Navigator.pop(context, color), child: Text(tr('Kiválaszt'))),
      ],
    );
  }
}

/// Kis színminta-gomb, amely megnyitja a színválasztót
class ColorButton extends StatelessWidget {
  const ColorButton({super.key, required this.color, required this.onChanged, this.label});
  final Color color;
  final ValueChanged<Color> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final c = await pickColor(context, color, title: label ?? tr('Szín kiválasztása'));
          if (c != null) onChanged(c);
        },
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: Colors.white38),
              ),
            ),
            if (label != null) ...[const SizedBox(width: 8), Text(label!)],
          ]),
        ),
      );
}
