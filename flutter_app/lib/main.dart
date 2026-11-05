// flutter_app/lib/main.dart — a Stage/Studio felület belépési pontja (minimális váz)
// Összeköti: C++ mag (FFI) → 6. modul (Smart Reader) és 7. modul (Wi-Fi szinkron).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';

import 'ffi/als_core.dart';
import 'reader/teleprompter_controller.dart'; // 6. modul
import 'sync/sync_client.dart';               // 7. modul

void main() => runApp(const AlsApp());

class AlsApp extends StatelessWidget {
  const AlsApp({super.key});
  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: 'ALS Stage', theme: ThemeData.dark(), home: const StageScreen());
}

class StageScreen extends StatefulWidget {
  const StageScreen({super.key});
  @override
  State<StageScreen> createState() => _StageScreenState();
}

class _StageScreenState extends State<StageScreen> with SingleTickerProviderStateMixin {
  final core = AlsCore.load();
  final reader = TeleprompterController(const [
    Anchor(0, 0), Anchor(8, 400), Anchor(16, 800), Anchor(32, 1600), // dalonként a kottából
  ]);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    // 1) Hangszer: első kimeneti port; console: true = teszt hangszer nélkül
    core.open(inPort: 0, outPort: 0);
    // 2) A mag MIDI Clock / Start / Stop eseményei a Smart Readerhez
    core.onRealtime((status, tsUs) => reader.onMidiRealtime(status, tsUs));
    // 3) Virtuális réteg V1 a 9-es csatornán (0-alapú: 8)
    core.setZone(0, low: 60, high: 108, velCurve: 0.8, outChannel: 8);
    // 4) Képkockánkénti frissítés: a görgetés a BPM-et követi
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      reader.tick(dt, core.nowUs()); // ugyanaz az óra, mint a MIDI időbélyegeké
    })..start();
  }

  Future<void> _syncFromStudio() async {
    final dir = await getApplicationSupportDirectory();
    final http = HttpClient(); // éles: a párosításkor rögzített tanúsítvány ellenőrzése
    final client = SyncClient(Uri.parse('https://192.168.1.20:47800'), http, dir);
    await client.pull(onProgress: (d, t) => debugPrint('Szinkron: $d / $t'));
  }

  @override
  void dispose() {
    _ticker.dispose();
    core.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Row(children: [
          SizedBox(width: 220, child: _VoicePanel(core: core)),                   // bal sáv
          Expanded(child: AnimatedBuilder(                                        // középső sáv
            animation: reader,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, -reader.scrollY),
              child: const Text('… dalszöveg / kotta …', style: TextStyle(fontSize: 28)),
            ),
          )),
          SizedBox(width: 220, child: _StylePanel(core: core)),                   // jobb sáv
        ]),
        bottomNavigationBar: Row(children: [                                      // alsó sáv
          for (var i = 1; i <= 4; i++) TextButton(onPressed: () {}, child: Text('OTS $i')),
          const Spacer(),
          TextButton(onPressed: _syncFromStudio, child: const Text('Szinkron a PC-ről')),
        ]),
      );
}

class _VoicePanel extends StatelessWidget {
  const _VoicePanel({required this.core});
  final AlsCore core;
  @override
  Widget build(BuildContext context) => const Center(child: Text('Hangszínek (8 slot)'));
}

class _StylePanel extends StatelessWidget {
  const _StylePanel({required this.core});
  final AlsCore core;
  @override
  Widget build(BuildContext context) => Column(children: [
        ElevatedButton(onPressed: core.styleStart, child: const Text('Start')),
        ElevatedButton(onPressed: core.styleStop, child: const Text('Stop')),
        for (final (name, code) in const [('Main A', 0x08), ('Main B', 0x09), ('Main C', 0x0A), ('Main D', 0x0B)])
          ElevatedButton(onPressed: () => core.section(code), child: Text(name)),
      ]);
}
