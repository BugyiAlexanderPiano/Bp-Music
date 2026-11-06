// lib/ui/transfer_dialogs.dart — küldés a PC-ről, fogadás a tableten / telefonon
import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../model/project.dart';
import '../transfer/transfer.dart';

const _showTypes = [XTypeGroup(label: 'ALS fellépő csomag', extensions: [showExtension])];

// ---------------------------------------------------------------------------
// PC: küldés tabletre / telefonra
// ---------------------------------------------------------------------------
Future<void> showSendDialog(BuildContext context, Project p) async {
  p.pruneImages();
  final payload = buildShowPackage(p, from: Platform.localHostname);
  final server = ShowServer();
  List<String>? ips;
  String? error;
  var downloads = 0;
  final sizeKb = (payload.length / 1024).toStringAsFixed(0);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
      server.onDownload = (_) => setD(() => downloads = server.downloads);
      Future<void> start() async {
        try {
          final list = await server.start(payload, p.name);
          setD(() => ips = list);
        } catch (e) {
          setD(() => error = 'A küldés nem indítható: $e');
        }
      }

      Future<void> saveFile() async {
        final loc = await getSaveLocation(
          suggestedName: '${p.name}.$showExtension',
          acceptedTypeGroups: _showTypes,
        );
        if (loc == null) return;
        final path = loc.path.toLowerCase().endsWith('.$showExtension') ? loc.path : '${loc.path}.$showExtension';
        await File(path).writeAsBytes(payload, flush: true);
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Mentve: $path')));
        }
      }

      return AlertDialog(
        title: const Text('Küldés tabletre / telefonra'),
        content: SizedBox(
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('A fellépő csomag: ${p.songs.length} dal, ${p.banks.length} bank, $sizeKb KB. '
                'A mobilon csak használni lehet, szerkeszteni nem.'),
            const SizedBox(height: 16),
            const Text('1. Wi-Fi (ajánlott)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.redAccent))
            else if (ips == null)
              FilledButton.icon(onPressed: start, icon: const Icon(Icons.wifi_tethering), label: const Text('Küldés indítása'))
            else ...[
              const Text('A tableten / telefonon: ALS → Fogadás PC-ről, majd add meg ezt a kódot:'),
              const SizedBox(height: 8),
              Center(
                child: SelectableText(
                  server.code.replaceAllMapped(RegExp(r'(\d{3})(\d{3})'), (m) => '${m[1]} ${m[2]}'),
                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: 4),
                ),
              ),
              const SizedBox(height: 6),
              Text('Ha a mobil nem találja magától a gépet, írd be ezt a címet: ${ips!.isEmpty ? '(nincs hálózat)' : ips!.join('  vagy  ')}'),
              const SizedBox(height: 6),
              Row(children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text(downloads == 0 ? 'Várakozás a mobilra…' : 'Letöltve $downloads eszközre ✓'),
              ]),
              if (Platform.isWindows)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Ha a Windows tűzfal rákérdez, engedélyezd a „Magánhálózat” hozzáférést.',
                      style: TextStyle(fontSize: 12)),
                ),
            ],
            const SizedBox(height: 18),
            const Text('2. Fájlként (USB-kábel, Bluetooth, AirDrop)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Mentsd a csomagot, másold a mobilra (Androidon a Letöltések mappába, iPhone/iPaden a Fájlok appba), '
                'majd a mobilon: Fogadás → Megnyitás fájlból.'),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: saveFile, icon: const Icon(Icons.save_alt), label: const Text('Csomag mentése (.alsshow)')),
          ]),
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              await server.stop();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Bezárás'),
          ),
        ],
      );
    }),
  );
  await server.stop();
}

// ---------------------------------------------------------------------------
// Mobil: fogadás a PC-ről
// ---------------------------------------------------------------------------
Future<Project?> showReceiveDialog(BuildContext context) async {
  final discovery = PcDiscovery();
  await discovery.start();
  final ipCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  var found = <FoundPc>[];
  String? status;
  var busy = false;
  StreamSubscription<List<FoundPc>>? sub;

  if (!context.mounted) return null;
  final result = await showDialog<Project>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
      sub ??= discovery.stream.listen((l) {
        found = l;
        if (ipCtrl.text.isEmpty && l.isNotEmpty) ipCtrl.text = l.first.address;
        setD(() {});
      });

      Future<void> download() async {
        if (ipCtrl.text.trim().isEmpty || codeCtrl.text.replaceAll(' ', '').length != 6) {
          setD(() => status = 'Add meg a PC címét és a 6 jegyű kódot.');
          return;
        }
        setD(() {
          busy = true;
          status = 'Letöltés…';
        });
        try {
          final p = await downloadShow(ipCtrl.text, codeCtrl.text.replaceAll(' ', ''));
          await saveShowOnDevice(p);
          if (ctx.mounted) Navigator.pop(ctx, p);
        } catch (e) {
          setD(() {
            busy = false;
            status = '$e';
          });
        }
      }

      Future<void> fromFile() async {
        try {
          final f = await openFile(acceptedTypeGroups: _showTypes);
          if (f == null) return;
          final p = parseShowPackage(await f.readAsBytes())..readOnly = true;
          await saveShowOnDevice(p);
          if (ctx.mounted) Navigator.pop(ctx, p);
        } catch (e) {
          setD(() => status = 'A fájl nem nyitható meg: $e');
        }
      }

      return AlertDialog(
        title: const Text('Fogadás PC-ről'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('A PC-n: Fájl → Küldés tabletre / telefonra → Küldés indítása.'),
              const SizedBox(height: 12),
              if (found.isEmpty)
                const Row(children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Expanded(child: Text('PC keresése a Wi-Fi hálózaton…')),
                ])
              else
                for (final pc in found)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.computer),
                    title: Text(pc.name),
                    subtitle: Text(pc.address),
                    selected: ipCtrl.text == pc.address,
                    onTap: () => setD(() => ipCtrl.text = pc.address),
                  ),
              TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'PC címe (pl. 192.168.1.20)')),
              TextField(
                controller: codeCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 24, letterSpacing: 4),
                decoration: const InputDecoration(labelText: 'Kód (6 számjegy)'),
              ),
              if (status != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(status!)),
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: fromFile, icon: const Icon(Icons.folder_open), label: const Text('Megnyitás fájlból (.alsshow)')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mégse')),
          FilledButton.icon(
            onPressed: busy ? null : download,
            icon: const Icon(Icons.download),
            label: const Text('Letöltés'),
          ),
        ],
      );
    }),
  );
  await sub?.cancel();
  discovery.stop();
  return result;
}
