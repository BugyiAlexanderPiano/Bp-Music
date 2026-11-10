// lib/main.dart — SoundNexus Pro belépési pont
// Betölti a beállításokat (nyelv, megjelenési mód) és az utoljára használt projektet
// (automentésből); első indításkor bemutató projekttel indul.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'i18n/i18n.dart';
import 'model/project.dart';
import 'settings.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  runApp(const AlsApp());
}

class AlsApp extends StatefulWidget {
  const AlsApp({super.key});
  @override
  State<AlsApp> createState() => _AlsAppState();
}

class _AlsAppState extends State<AlsApp> {
  late Project project = _loadInitial();
  final _settings = AppSettings.instance;

  static Project _loadInitial() {
    try {
      for (final f in [Project.autosaveFile, Project.legacyAutosaveFile]) {
        if (f.existsSync()) return Project.fromFileString(f.readAsStringSync());
      }
    } catch (_) {}
    return Project.demo();
  }

  void _settingsChanged() {
    _settings.save();
    setState(() {});
  }

  /// PC-n a Tablet / Telefon mód előnézet: a felület a készülék méretében, keretben jelenik meg
  Widget _frame(BuildContext context, Widget child) {
    final mode = _settings.effective();
    if (!AppSettings.platformIsDesktop || mode == UiMode.pc) return child;
    final device = mode == UiMode.phone ? const Size(412, 892) : const Size(1280, 800);
    final mq = MediaQuery.of(context);
    return ColoredBox(
      color: const Color(0xFF0B0D12),
      child: Column(children: [
        Material(
          color: const Color(0xFF161A22),
          child: SizedBox(
            height: 40,
            child: Row(children: [
              const SizedBox(width: 12),
              Icon(mode == UiMode.phone ? Icons.smartphone : Icons.tablet_mac, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mode == UiMode.phone
                      ? tr('Telefon előnézet – így jelenik meg a felület telefonon (szerkesztés csak PC módban)')
                      : tr('Tablet előnézet – így jelenik meg a felület tableten (szerkesztés csak PC módban)'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  _settings.mode = UiMode.pc;
                  _settingsChanged();
                },
                icon: const Icon(Icons.desktop_windows, size: 18),
                label: Text(tr('Vissza PC módba')),
              ),
              const SizedBox(width: 8),
            ]),
          ),
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              child: Container(
                width: device.width + 24,
                height: device.height + 24,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF22262E),
                  borderRadius: BorderRadius.circular(mode == UiMode.phone ? 46 : 30),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(mode == UiMode.phone ? 36 : 20),
                  child: MediaQuery(
                    data: mq.copyWith(size: device, padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
                    child: SizedBox.fromSize(size: device, child: child),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = project.theme;
    return MaterialApp(
      title: 'SoundNexus Pro',
      debugShowCheckedModeBanner: false,
      locale: Locale(_settings.lang),
      supportedLocales: [for (final l in languages.keys) Locale(l)],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: t.accent,
        useMaterial3: true,
        visualDensity: VisualDensity.compact,
        fontFamily: 'Segoe UI',
      ),
      builder: (context, child) => _frame(context, child ?? const SizedBox()),
      home: HomePage(
        key: ValueKey('${_settings.lang}-${_settings.effective().name}'),
        project: project,
        initialPath: null,
        onProjectReplaced: (p) => setState(() => project = p),
        onThemeChanged: () => setState(() {}),
        onSettingsChanged: _settingsChanged,
      ),
    );
  }
}
