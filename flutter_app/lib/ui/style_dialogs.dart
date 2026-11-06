// lib/ui/style_dialogs.dart — panel- és gombstílus szerkesztők (csak PC-n), képfeltöltés
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../model/project.dart';
import 'als_button.dart';
import 'color_picker.dart';

const _imageTypes = [
  XTypeGroup(label: 'Képek', extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp']),
];
const maxImageBytes = 3 * 1024 * 1024;

/// Kép kiválasztása és beágyazása a projektbe; visszaadja az azonosítóját
Future<String?> pickImageInto(BuildContext context, Project p) async {
  final f = await openFile(acceptedTypeGroups: _imageTypes);
  if (f == null) return null;
  final bytes = await f.readAsBytes();
  if (bytes.length > maxImageBytes) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A kép túl nagy (legfeljebb 3 MB). Kicsinyítsd le, és próbáld újra.')),
      );
    }
    return null;
  }
  final id = 'img_${DateTime.now().microsecondsSinceEpoch}';
  p.images[id] = base64Encode(bytes);
  return id;
}

Widget _imagePreview(Project p, String? id) {
  final img = ImageStore.of(p, id);
  return Container(
    width: 64,
    height: 44,
    decoration: BoxDecoration(
      color: Colors.black26,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.white24),
      image: img == null ? null : DecorationImage(image: img, fit: BoxFit.cover),
    ),
    child: img == null ? const Icon(Icons.image_not_supported_outlined, size: 18) : null,
  );
}

Widget _row(String label, Widget child) => Row(children: [
      SizedBox(width: 150, child: Text(label)),
      Expanded(child: child),
    ]);

// ---------------------------------------------------------------------------
// Panel (sáv) stílusa
// ---------------------------------------------------------------------------
Future<void> showPanelStyleDialog(BuildContext context, Project p, String key, VoidCallback onChanged) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        final ps = p.panels[key]!;
        void upd(VoidCallback f) {
          f();
          setD(() {});
          onChanged();
        }

        return AlertDialog(
          title: Text('Stílus: ${panelNames[key]}'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Saját háttér ennek a sávnak'),
                  subtitle: const Text('Kikapcsolva a téma panelszínét használja'),
                  value: ps.useOwn,
                  onChanged: (v) => upd(() => ps.useOwn = v),
                ),
                if (ps.useOwn) ...[
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
                    for (var i = 0; i < ps.background.length; i++)
                      ColorButton(
                        color: ps.background[i],
                        label: ps.background.length == 1 ? 'Háttér' : '${i + 1}.',
                        onChanged: (c) => upd(() => ps.background[i] = c),
                      ),
                    if (ps.background.length < 4)
                      IconButton(
                        tooltip: 'Átmenet: szín hozzáadása',
                        onPressed: () => upd(() => ps.background.add(ps.background.last)),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    if (ps.background.length > 1)
                      IconButton(
                        tooltip: 'Szín törlése',
                        onPressed: () => upd(() => ps.background.removeLast()),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                  ]),
                  _row('Átlátszóság', Slider(value: ps.opacity, min: 0.1, max: 1, onChanged: (v) => upd(() => ps.opacity = v))),
                  _row('Sarkok kerekítése', Slider(value: ps.radius, max: 40, onChanged: (v) => upd(() => ps.radius = v))),
                  _row('Keret vastagsága', Slider(value: ps.borderWidth, max: 6, onChanged: (v) => upd(() => ps.borderWidth = v))),
                  ColorButton(color: ps.border, label: 'Keret színe', onChanged: (c) => upd(() => ps.border = c)),
                ],
                const Divider(height: 24),
                const Text('Háttérkép', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(children: [
                  _imagePreview(p, ps.backgroundImage),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final id = await pickImageInto(ctx, p);
                      if (id != null) upd(() => ps.backgroundImage = id);
                    },
                    icon: const Icon(Icons.upload),
                    label: const Text('Kép feltöltése'),
                  ),
                  if (ps.backgroundImage != null)
                    TextButton(onPressed: () => upd(() => ps.backgroundImage = null), child: const Text('Eltávolítás')),
                ]),
                if (ps.backgroundImage != null)
                  _row('Kép láthatósága', Slider(value: ps.imageOpacity, min: 0.05, max: 1, onChanged: (v) => upd(() => ps.imageOpacity = v))),
                if (key != 'center') ...[
                  const Divider(height: 24),
                  const Text('Gombok', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  SegmentedButton<ButtonShape>(
                    segments: [
                      for (final e in buttonShapeNames.entries) ButtonSegment(value: e.key, label: Text(e.value)),
                    ],
                    selected: {ps.shape},
                    onSelectionChanged: (s) => upd(() => ps.shape = s.first),
                  ),
                  _row('Gombméret', Slider(value: ps.buttonScale, min: 0.7, max: 1.8, divisions: 22, label: '${(ps.buttonScale * 100).round()}%', onChanged: (v) => upd(() => ps.buttonScale = v))),
                  _row('Betűméret', Slider(value: ps.fontSize, min: 10, max: 26, divisions: 16, label: '${ps.fontSize.round()}', onChanged: (v) => upd(() => ps.fontSize = v))),
                  Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    ColorButton(color: ps.buttonColor ?? p.theme.accent, label: 'Gombszín', onChanged: (c) => upd(() => ps.buttonColor = c)),
                    if (ps.buttonColor != null)
                      TextButton(onPressed: () => upd(() => ps.buttonColor = null), child: const Text('téma szerint')),
                    ColorButton(color: ps.buttonText ?? p.theme.textColor, label: 'Felirat színe', onChanged: (c) => upd(() => ps.buttonText = c)),
                    if (ps.buttonText != null)
                      TextButton(onPressed: () => upd(() => ps.buttonText = null), child: const Text('automatikus')),
                  ]),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => upd(() => p.panels[key] = PanelStyle()),
              child: const Text('Alaphelyzet'),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kész')),
          ],
        );
      }),
    );

// ---------------------------------------------------------------------------
// Egy gomb stílusa (kép, felirat, szín, méret)
// ---------------------------------------------------------------------------
Future<void> showItemStyleDialog(BuildContext context, Project p, String id, String defaultLabel, VoidCallback onChanged) {
  final labelCtrl = TextEditingController(text: p.items[id]?.label ?? '');
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black26,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
      final it = p.itemFor(id);
      void upd(VoidCallback f) {
        f();
        setD(() {});
        onChanged();
      }

      return AlertDialog(
        title: Text('Gomb: $defaultLabel'),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Kép a gombon', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(children: [
              _imagePreview(p, it.image),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final img = await pickImageInto(ctx, p);
                  if (img != null) upd(() => it.image = img);
                },
                icon: const Icon(Icons.upload),
                label: const Text('Kép feltöltése'),
              ),
              if (it.image != null)
                TextButton(onPressed: () => upd(() => it.image = null), child: const Text('Eltávolítás')),
            ]),
            if (it.image != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Csak a kép (felirat nélkül)'),
                value: it.imageOnly,
                onChanged: (v) => upd(() => it.imageOnly = v),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(labelText: 'Felirat', hintText: defaultLabel),
              onChanged: (v) => upd(() => it.label = v.trim().isEmpty ? null : v.trim()),
            ),
            const SizedBox(height: 8),
            Row(children: [
              ColorButton(color: it.color ?? p.theme.accent, label: 'Szín', onChanged: (c) => upd(() => it.color = c)),
              if (it.color != null) TextButton(onPressed: () => upd(() => it.color = null), child: const Text('panel szerint')),
            ]),
            _row('Méret', Slider(value: it.scale, min: 0.6, max: 2.0, divisions: 14, label: '${(it.scale * 100).round()}%', onChanged: (v) => upd(() => it.scale = v))),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () {
              upd(() => p.items.remove(id));
              Navigator.pop(ctx);
            },
            child: const Text('Alaphelyzet'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kész')),
        ],
      );
    }),
  );
}
