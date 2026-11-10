// lib/settings.dart — alkalmazás-beállítások (nyelv, megjelenési mód); nem a projekt része
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import 'i18n/i18n.dart';
import 'model/project.dart';

/// Megjelenési mód. PC: szerkesztő; Tablet és Telefon: fellépő mód.
/// PC-n a Tablet és Telefon mód előnézet: pontosan úgy mutatja a felületet, ahogy a mobilon lesz.
enum UiMode { auto, pc, tablet, phone }

class AppSettings {
  AppSettings._();
  static final instance = AppSettings._();

  String lang = I18n.bestFor(ui.PlatformDispatcher.instance.locale.languageCode);
  UiMode mode = UiMode.auto;

  static bool get platformIsDesktop =>
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux) && Platform.environment['SNX_FORCE_MOBILE'] != '1';

  /// A ténylegesen használt mód (auto: PC-n PC, mobilon tablet vagy telefon a képernyő szerint)
  UiMode effective({double? width}) {
    if (mode == UiMode.pc && !platformIsDesktop) return UiMode.tablet; // mobilon nincs szerkesztő mód
    if (mode != UiMode.auto) return mode;
    if (platformIsDesktop) return UiMode.pc;
    return (width ?? 1000) < 700 ? UiMode.phone : UiMode.tablet;
  }

  Future<File> _file() async {
    if (platformIsDesktop) {
      return File('${Project.appDataDir.path}${Platform.pathSeparator}beallitasok.json');
    }
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}beallitasok.json');
  }

  Future<void> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final l = j['lang'] as String?;
        if (l != null && languages.containsKey(l)) lang = l;
        mode = UiMode.values.firstWhere((m) => m.name == j['mode'], orElse: () => UiMode.auto);
      }
    } catch (_) {}
    // Teszteléshez (CI): SNX_LANG=en, SNX_MODE=phone …
    final envLang = Platform.environment['SNX_LANG'];
    if (envLang != null && languages.containsKey(envLang)) lang = envLang;
    final envMode = Platform.environment['SNX_MODE'];
    if (envMode != null) mode = UiMode.values.firstWhere((m) => m.name == envMode, orElse: () => mode);
    I18n.lang = lang;
  }

  Future<void> save() async {
    I18n.lang = lang;
    try {
      final f = await _file();
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode({'lang': lang, 'mode': mode.name}));
    } catch (_) {}
  }
}
