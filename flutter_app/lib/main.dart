// lib/main.dart — ALS belépési pont
// Az utoljára használt projektet automatikusan visszatölti (automentésből),
// első indításkor egy bemutató projekttel indul.
import 'package:flutter/material.dart';

import 'model/project.dart';
import 'ui/home_page.dart';

void main() => runApp(const AlsApp());

class AlsApp extends StatefulWidget {
  const AlsApp({super.key});
  @override
  State<AlsApp> createState() => _AlsAppState();
}

class _AlsAppState extends State<AlsApp> {
  late Project project = _loadInitial();

  static Project _loadInitial() {
    try {
      for (final f in [Project.autosaveFile, Project.legacyAutosaveFile]) {
        if (f.existsSync()) return Project.fromFileString(f.readAsStringSync());
      }
    } catch (_) {}
    return Project.demo();
  }

  @override
  Widget build(BuildContext context) {
    final t = project.theme;
    return MaterialApp(
      title: 'SoundNexus Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: t.accent,
        useMaterial3: true,
        visualDensity: VisualDensity.compact,
        fontFamily: 'Segoe UI',
      ),
      home: HomePage(
        project: project,
        initialPath: null,
        onProjectReplaced: (p) => setState(() => project = p),
        onThemeChanged: () => setState(() {}),
      ),
    );
  }
}
