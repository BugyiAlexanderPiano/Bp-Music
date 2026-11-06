// lib/ui/als_button.dart — testreszabható gomb és panel (forma, méret, szín, kép)
import 'dart:convert';

import 'package:flutter/material.dart';

import '../model/project.dart';

/// Beágyazott képek gyorsítótára (a base64 csak egyszer dekódolódik)
class ImageStore {
  static final _cache = <String, MemoryImage>{};

  static ImageProvider? of(Project p, String? id) {
    if (id == null) return null;
    final data = p.images[id];
    if (data == null) return null;
    return _cache.putIfAbsent(id, () => MemoryImage(base64Decode(data)));
  }
}

/// Egy sáv háttere a projekt panelstílusa szerint
BoxDecoration panelDecoration(Project p, String key, {bool editMode = false}) {
  final ps = p.panels[key]!;
  final t = p.theme;
  final img = ImageStore.of(p, ps.backgroundImage);
  final colors = ps.useOwn ? ps.background : [t.panel];
  final opacity = ps.useOwn ? ps.opacity : t.panelOpacity;
  final radius = ps.useOwn ? ps.radius : t.radius;
  return BoxDecoration(
    color: colors.length == 1 ? colors.first.withValues(alpha: opacity) : null,
    gradient: colors.length > 1
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [for (final c in colors) c.withValues(alpha: opacity)],
          )
        : null,
    image: img == null
        ? null
        : DecorationImage(image: img, fit: BoxFit.cover, opacity: ps.imageOpacity),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: editMode ? t.accent.withValues(alpha: 0.8) : (ps.useOwn ? ps.border : Colors.white.withValues(alpha: 0.07)),
      width: editMode ? 1.5 : (ps.useOwn ? ps.borderWidth : 1),
    ),
    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
  );
}

double panelRadius(Project p, String key) {
  final ps = p.panels[key]!;
  return ps.useOwn ? ps.radius : p.theme.radius;
}

Color _onColor(Color c) => c.computeLuminance() > 0.5 ? Colors.black : Colors.white;

class AlsButton extends StatelessWidget {
  const AlsButton({
    super.key,
    required this.project,
    required this.panel,
    required this.id,
    required this.label,
    this.icon,
    this.onTap,
    this.selected = false,
    this.width,
    this.height = 40,
    this.editMode = false,
    this.onEdit,
    this.alignLeft = false,
    this.child,
    this.trailing,
  });

  final Project project;
  final String panel, id, label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected, editMode, alignLeft;
  final double? width;
  final double height;
  /// Szerkesztő módban a kattintás ezt hívja (gomb stílusa)
  final VoidCallback? onEdit;
  /// Egyedi tartalom (pl. V-réteg csempe); a stílus ekkor is érvényes
  final Widget? child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ps = project.panels[panel]!;
    final it = project.items[id];
    final t = project.theme;
    final scale = ps.buttonScale * (it?.scale ?? 1.0);
    final base = it?.color ?? ps.buttonColor ?? t.accent;
    final fg = ps.buttonText ?? (selected ? _onColor(base) : t.textColor);
    final h = height * scale;
    final circle = ps.shape == ButtonShape.circle;
    final radius = switch (ps.shape) {
      ButtonShape.rounded => 10.0 * scale,
      ButtonShape.pill => h / 2,
      ButtonShape.square => 3.0,
      ButtonShape.circle => h / 2,
    };
    final img = ImageStore.of(project, it?.image);
    final text = (it?.label?.isNotEmpty ?? false) ? it!.label! : label;
    final showText = (!(it?.imageOnly ?? false) || img == null) && text.isNotEmpty;
    final enabled = editMode || onTap != null;

    final labelText = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: fg,
        fontSize: ps.fontSize * scale,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        shadows: img != null ? const [Shadow(blurRadius: 4, color: Colors.black)] : null,
      ),
    );

    final content = child ??
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: alignLeft ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18 * scale, color: fg),
              if (showText) const SizedBox(width: 8),
            ],
            if (showText && trailing != null) Expanded(child: labelText),
            if (showText && trailing == null) Flexible(child: labelText),
            if (trailing != null) ...[if (!showText) const Spacer(), trailing!],
          ],
        );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SizedBox(
        width: circle ? h : width,
        height: h,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? base : base.withValues(alpha: 0.13),
              image: img == null
                  ? null
                  : DecorationImage(
                      image: img,
                      fit: BoxFit.cover,
                      colorFilter: showText
                          ? ColorFilter.mode(Colors.black.withValues(alpha: 0.25), BlendMode.darken)
                          : null,
                    ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: editMode ? Colors.orangeAccent : base.withValues(alpha: selected ? 1 : 0.55),
                width: editMode ? 1.5 : 1.2,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: editMode ? onEdit : onTap,
              child: Stack(children: [
                if (width == null && !circle)
                  // szélesség nélkül (pl. Wrap-ben) a gomb a tartalmához igazodik
                  Align(
                    widthFactor: 1,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                      child: content,
                    ),
                  )
                else
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: circle ? 2 : 10 * scale),
                      child: Align(alignment: alignLeft ? Alignment.centerLeft : Alignment.center, child: content),
                    ),
                  ),
                if (editMode)
                  const Positioned(
                    right: 3,
                    top: 3,
                    child: Icon(Icons.brush, size: 12, color: Colors.orangeAccent),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
