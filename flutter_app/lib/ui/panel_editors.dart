// lib/ui/panel_editors.dart — külön szerkesztőablakok (csak PC-n):
//   Hangszín-panel · Ritmus-panel · Alsó vezérlősáv
import 'package:flutter/material.dart';

import '../model/project.dart';
import 'als_button.dart';
import 'style_dialogs.dart';

class _EditorScaffold extends StatelessWidget {
  const _EditorScaffold({required this.project, required this.title, required this.subtitle, required this.icon, required this.body, this.actions = const []});
  final Project project;
  final String title, subtitle;
  final IconData icon;
  final Widget body;
  final List<Widget> actions;

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
              decoration: BoxDecoration(gradient: LinearGradient(colors: [t.accent.withValues(alpha: 0.35), Colors.transparent])),
              child: Row(children: [
                IconButton(tooltip: 'Kész, vissza', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
                Icon(icon, color: t.accent, size: 28),
                const SizedBox(width: 12),
                Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65))),
                ]),
                const Spacer(),
                ...actions,
                const SizedBox(width: 8),
                FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.check), label: const Text('Kész')),
              ]),
            ),
            Expanded(child: body),
          ]),
        ),
      ),
    );
  }
}

Widget _box(Project p, Widget child, {double? width}) => Container(
      width: width,
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.theme.panel.withValues(alpha: p.theme.panelOpacity),
        borderRadius: BorderRadius.circular(p.theme.radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: child,
    );

Widget _head(String s) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(s, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    );

Widget _columnsPicker(int value, ValueChanged<int> onChanged) => Row(children: [
      const Text('Oszlopok: '),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 1, label: Text('1')),
          ButtonSegment(value: 2, label: Text('2')),
          ButtonSegment(value: 3, label: Text('3')),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    ]);

// ===========================================================================
// Hangszín-panel szerkesztő
// ===========================================================================
const _categories = {'piano': 'Zongora', 'organ': 'Orgona', 'lead': 'Szóló', 'bass': 'Basszus', 'pad': 'Pad / vonós', 'choir': 'Kórus', '': 'Egyéb'};

class VoicePanelEditorPage extends StatefulWidget {
  const VoicePanelEditorPage({super.key, required this.project, required this.onChanged});
  final Project project;
  final VoidCallback onChanged;
  @override
  State<VoicePanelEditorPage> createState() => _VoicePanelEditorPageState();
}

class _VoicePanelEditorPageState extends State<VoicePanelEditorPage> {
  int group = 0;
  Project get p => widget.project;

  void _ch(VoidCallback f) {
    setState(f);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final groups = p.voiceGroups;
    if (groups.isNotEmpty) group = group.clamp(0, groups.length - 1);
    final g = groups.isEmpty ? null : groups[group];
    return _EditorScaffold(
      project: p,
      title: 'Hangszín-panel szerkesztő',
      subtitle: 'Csoportok, hangszínek, sorrend, oszlopok, gombok kinézete',
      icon: Icons.piano,
      actions: [
        TextButton.icon(
          onPressed: () => showPanelStyleDialog(context, p, 'left', () => _ch(() {})),
          icon: const Icon(Icons.format_paint),
          label: const Text('Sáv stílusa'),
        ),
        TextButton.icon(
          onPressed: () => _ch(() {
            p.voiceGroups
              ..clear()
              ..addAll(defaultVoiceGroups());
            group = 0;
          }),
          icon: const Icon(Icons.restart_alt),
          label: const Text('Alap hangszín-tár'),
        ),
      ],
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Csoportok
        _box(p, width: 330, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _head('Hangszíncsoportok (húzással átrendezhető)'),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: groups.length,
              onReorder: (a, b) => _ch(() {
                if (b > a) b--;
                final x = groups.removeAt(a);
                groups.insert(b, x);
                group = b;
              }),
              itemBuilder: (ctx, i) => ListTile(
                key: ValueKey(groups[i]),
                selected: i == group,
                leading: ReorderableDragStartListener(index: i, child: Icon(groups[i].icon)),
                title: Text(groups[i].name),
                subtitle: Text('${groups[i].voices.length} hangszín'),
                onTap: () => setState(() => group = i),
                trailing: IconButton(
                  tooltip: 'Csoport törlése',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _ch(() => groups.removeAt(i)),
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _ch(() {
              groups.add(VoiceGroup('Új csoport', 'folder', []));
              group = groups.length - 1;
            }),
            icon: const Icon(Icons.add),
            label: const Text('Új csoport'),
          ),
          const SizedBox(height: 10),
          _columnsPicker(p.leftColumns, (v) => _ch(() => p.leftColumns = v)),
        ])),
        // Kiválasztott csoport hangszínei
        Expanded(
          child: _box(p, g == null
              ? const Center(child: Text('Nincs csoport.'))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('gname$group'),
                        initialValue: g.name,
                        decoration: const InputDecoration(labelText: 'Csoport neve'),
                        onChanged: (v) => _ch(() => g.name = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: groupIcons.containsKey(g.iconKey) ? g.iconKey : 'folder',
                      items: [for (final e in groupIcons.entries) DropdownMenuItem(value: e.key, child: Icon(e.value))],
                      onChanged: (v) => _ch(() => g.iconKey = v!),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => showItemStyleDialog(context, p, 'group:${g.name}', g.name, () => _ch(() {})),
                      icon: const Icon(Icons.brush),
                      label: const Text('Gomb kinézete'),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _head('Hangszínek (Bank MSB / LSB / Program a hangszer listájából)'),
                  Expanded(
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: g.voices.length,
                      onReorder: (a, b) => _ch(() {
                        if (b > a) b--;
                        final x = g.voices.removeAt(a);
                        g.voices.insert(b, x);
                      }),
                      itemBuilder: (ctx, i) {
                        final v = g.voices[i];
                        Widget numField(String label, int value, ValueChanged<int> set, {int min = 0, int max = 127}) => SizedBox(
                              width: 74,
                              child: TextFormField(
                                key: ValueKey('$label$i${v.hashCode}'),
                                initialValue: '$value',
                                decoration: InputDecoration(labelText: label, isDense: true),
                                keyboardType: TextInputType.number,
                                onChanged: (t) {
                                  final n = int.tryParse(t);
                                  if (n != null) _ch(() => set(n.clamp(min, max)));
                                },
                              ),
                            );
                        return Padding(
                          key: ValueKey(v),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('vn$i${v.hashCode}'),
                                initialValue: v.name,
                                decoration: const InputDecoration(labelText: 'Név', isDense: true),
                                onChanged: (t) => _ch(() => v.name = t),
                              ),
                            ),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: _categories.containsKey(v.category) ? v.category : '',
                              items: [for (final e in _categories.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                              onChanged: (c) => _ch(() => v.category = c!),
                            ),
                            const SizedBox(width: 8),
                            numField('MSB', v.msb, (n) => v.msb = n),
                            const SizedBox(width: 6),
                            numField('LSB', v.lsb, (n) => v.lsb = n),
                            const SizedBox(width: 6),
                            numField('Prg', v.program + 1, (n) => v.program = n - 1, min: 1, max: 128),
                            IconButton(
                              tooltip: 'Gomb kinézete',
                              icon: const Icon(Icons.brush),
                              onPressed: () => showItemStyleDialog(context, p, 'voice:${v.name}', v.name, () => _ch(() {})),
                            ),
                            IconButton(
                              tooltip: 'Törlés',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _ch(() => g.voices.removeAt(i)),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _ch(() => g.voices.add(VoicePreset('Új hangszín', '', 0))),
                      icon: const Icon(Icons.add),
                      label: const Text('Új hangszín'),
                    ),
                  ),
                ])),
        ),
        // Előnézet
        _box(p, width: 300, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _head('Előnézet'),
          Expanded(
            child: LayoutBuilder(builder: (ctx, box) {
              final w = (box.maxWidth - (p.leftColumns - 1) * 6) / p.leftColumns;
              return SingleChildScrollView(
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final gg in groups)
                    AlsButton(project: p, panel: 'left', id: 'group:${gg.name}', label: gg.name, icon: gg.icon,
                        width: w, height: 42, alignLeft: p.leftColumns == 1, selected: g == gg, onTap: () {}),
                ]),
              );
            }),
          ),
        ])),
      ]),
    );
  }
}

// ===========================================================================
// Ritmus-panel szerkesztő
// ===========================================================================
class RhythmPanelEditorPage extends StatefulWidget {
  const RhythmPanelEditorPage({super.key, required this.project, required this.onChanged});
  final Project project;
  final VoidCallback onChanged;
  @override
  State<RhythmPanelEditorPage> createState() => _RhythmPanelEditorPageState();
}

class _RhythmPanelEditorPageState extends State<RhythmPanelEditorPage> {
  Project get p => widget.project;
  void _ch(VoidCallback f) {
    setState(f);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final items = p.rhythmItems;
    final missing = [for (final k in rhythmCatalog.keys) if (!items.contains(k)) k];
    return _EditorScaffold(
      project: p,
      title: 'Ritmus-panel szerkesztő',
      subtitle: 'Gombok sorrendje, hozzáadás, eltávolítás, oszlopok, kinézet',
      icon: Icons.queue_music,
      actions: [
        TextButton.icon(
          onPressed: () => showPanelStyleDialog(context, p, 'right', () => _ch(() {})),
          icon: const Icon(Icons.format_paint),
          label: const Text('Sáv stílusa'),
        ),
        TextButton.icon(
          onPressed: () => _ch(() => items
            ..clear()
            ..addAll(defaultRhythmItems)),
          icon: const Icon(Icons.restart_alt),
          label: const Text('Alap elrendezés'),
        ),
      ],
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: _box(p, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _head('Gombok (húzással átrendezhető)'),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: items.length,
                onReorder: (a, b) => _ch(() {
                  if (b > a) b--;
                  final x = items.removeAt(a);
                  items.insert(b, x);
                }),
                itemBuilder: (ctx, i) => ListTile(
                  key: ValueKey(items[i]),
                  leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator)),
                  title: Text(rhythmCatalog[items[i]] ?? items[i]),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Gomb kinézete',
                      icon: const Icon(Icons.brush),
                      onPressed: () => showItemStyleDialog(context, p, 'r:${items[i]}', rhythmCatalog[items[i]] ?? items[i], () => _ch(() {})),
                    ),
                    IconButton(tooltip: 'Eltávolítás', icon: const Icon(Icons.remove_circle_outline), onPressed: () => _ch(() => items.removeAt(i))),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Hozzáadás: '),
              Expanded(
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final k in missing)
                    ActionChip(avatar: const Icon(Icons.add, size: 16), label: Text(rhythmCatalog[k]!), onPressed: () => _ch(() => items.add(k))),
                  if (missing.isEmpty) const Text('minden gomb a panelen van'),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            _columnsPicker(p.rhythmColumns, (v) => _ch(() => p.rhythmColumns = v)),
          ])),
        ),
        _box(p, width: 320, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _head('Előnézet'),
          Expanded(
            child: LayoutBuilder(builder: (ctx, box) {
              final w = (box.maxWidth - (p.rhythmColumns - 1) * 8) / p.rhythmColumns;
              return SingleChildScrollView(
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final k in items)
                    AlsButton(project: p, panel: 'right', id: 'r:$k', label: rhythmCatalog[k] ?? k, width: w, height: 40, onTap: () {}),
                ]),
              );
            }),
          ),
        ])),
      ]),
    );
  }
}

// ===========================================================================
// Alsó vezérlősáv szerkesztő
// ===========================================================================
class BottomBarEditorPage extends StatefulWidget {
  const BottomBarEditorPage({super.key, required this.project, required this.onChanged});
  final Project project;
  final VoidCallback onChanged;
  @override
  State<BottomBarEditorPage> createState() => _BottomBarEditorPageState();
}

class _BottomBarEditorPageState extends State<BottomBarEditorPage> {
  Project get p => widget.project;
  void _ch(VoidCallback f) {
    setState(f);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final mods = p.bottomModules;
    return _EditorScaffold(
      project: p,
      title: 'Alsó vezérlősáv szerkesztő',
      subtitle: 'Elemek sorrendje (balról jobbra), hozzáadás, eltávolítás, kinézet',
      icon: Icons.view_day,
      actions: [
        TextButton.icon(
          onPressed: () => showPanelStyleDialog(context, p, 'bottom', () => _ch(() {})),
          icon: const Icon(Icons.format_paint),
          label: const Text('Sáv stílusa'),
        ),
        TextButton.icon(
          onPressed: () => _ch(() => mods
            ..clear()
            ..addAll(defaultBottomModules)),
          icon: const Icon(Icons.restart_alt),
          label: const Text('Alap elrendezés'),
        ),
      ],
      body: _box(p, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _head('Elemek – a lista sorrendje = a sáv sorrendje balról jobbra'),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: mods.length,
            onReorder: (a, b) => _ch(() {
              if (b > a) b--;
              final x = mods.removeAt(a);
              mods.insert(b, x);
            }),
            itemBuilder: (ctx, i) => ListTile(
              key: ValueKey('$i-${mods[i]}'),
              leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator)),
              title: Text(bottomCatalog[mods[i]] ?? mods[i]),
              trailing: IconButton(tooltip: 'Eltávolítás', icon: const Icon(Icons.remove_circle_outline), onPressed: () => _ch(() => mods.removeAt(i))),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Hozzáadás: '),
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in bottomCatalog.entries)
                if (e.key == 'spacer' || !mods.contains(e.key))
                  ActionChip(avatar: const Icon(Icons.add, size: 16), label: Text(e.value), onPressed: () => _ch(() => mods.add(e.key))),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Text('Az egyes gombok (pl. OTS 1–4, regiszter 1–8, V1–V4) kinézetét a fő ablakban, '
            'a Nézet → Felület szerkesztése módban, a gombra kattintva állíthatod.',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
      ])),
    );
  }
}
