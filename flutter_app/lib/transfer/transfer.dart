// lib/transfer/transfer.dart — fellépő csomag átvitele PC → tablet / telefon
//
//  Wi-Fi:  a PC HTTP-szervert indít (47800-as port) és másodpercenként UDP-jeladást küld
//          (47801-es port). A mobil felderíti a gépet, majd a 6 jegyű kóddal letölti a
//          csomagot. A letöltés SHA-256 ellenőrzéssel történik, és csak hibátlan csomag
//          kerül mentésre.
//  Fájl:   ugyanaz a csomag .alsshow fájlként (USB-kábel, Bluetooth, AirDrop, felhő).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../model/project.dart';

const showExtension = 'alsshow';
const transferPort = 47800;
const beaconPort = 47801;

/// A PC-n véglegesített projektből fellépő csomag: csak olvasható, beágyazott képekkel.
Uint8List buildShowPackage(Project p, {required String from}) {
  final show = Project.fromJson(p.toJson())
    ..readOnly = true
    ..sourceInfo = '$from · ${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')}';
  return Uint8List.fromList(utf8.encode(show.toFileString()));
}

Project parseShowPackage(List<int> bytes) => Project.fromFileString(utf8.decode(bytes));

String sha256Hex(List<int> data) => sha256.convert(data).toString();

// ---------------------------------------------------------------------------
// PC oldal: szerver + jeladó
// ---------------------------------------------------------------------------
class ShowServer {
  HttpServer? _server;
  RawDatagramSocket? _beacon;
  Timer? _timer;
  late Uint8List _payload;
  late String _sha;
  final code = (100000 + math.Random.secure().nextInt(900000)).toString();
  int downloads = 0;
  void Function(String clientAddress)? onDownload;

  bool get running => _server != null;

  /// Elindítja a szervert; visszaadja a gép helyi IP-címeit
  Future<List<String>> start(Uint8List payload, String name) async {
    _payload = payload;
    _sha = sha256Hex(payload);
    _server = await HttpServer.bind(InternetAddress.anyIPv4, transferPort, shared: true);
    _server!.listen(_handle);

    try {
      _beacon = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
        ..broadcastEnabled = true;
      final msg = utf8.encode('ALS|$transferPort|$name');
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        try {
          _beacon?.send(msg, InternetAddress('255.255.255.255'), beaconPort);
        } catch (_) {}
      });
    } catch (_) {}

    final ips = <String>[];
    for (final ni in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final a in ni.addresses) {
        if (!a.isLoopback) ips.add(a.address);
      }
    }
    return ips;
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    if (req.uri.path == '/show' && req.uri.queryParameters['code'] == code) {
      res.headers
        ..contentType = ContentType('application', 'octet-stream')
        ..set('x-als-sha256', _sha)
        ..contentLength = _payload.length;
      res.add(_payload);
      downloads++;
      onDownload?.call(req.connectionInfo?.remoteAddress.address ?? '?');
    } else if (req.uri.path == '/ping') {
      res.write('ALS');
    } else {
      res.statusCode = HttpStatus.forbidden;
      res.write('Hibás kód');
    }
    await res.close();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _beacon?.close();
    await _server?.close(force: true);
    _server = null;
  }
}

// ---------------------------------------------------------------------------
// Mobil oldal: felderítés + letöltés + mentés
// ---------------------------------------------------------------------------
class FoundPc {
  FoundPc(this.address, this.port, this.name);
  final String address, name;
  final int port;
}

class PcDiscovery {
  RawDatagramSocket? _sock;
  final _found = <String, FoundPc>{};
  final _ctrl = StreamController<List<FoundPc>>.broadcast();

  Stream<List<FoundPc>> get stream => _ctrl.stream;

  Future<void> start() async {
    try {
      _sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, beaconPort, reuseAddress: true);
      _sock!.listen((e) {
        if (e != RawSocketEvent.read) return;
        final d = _sock!.receive();
        if (d == null) return;
        final parts = utf8.decode(d.data, allowMalformed: true).split('|');
        if (parts.length < 3 || parts[0] != 'ALS') return;
        final pc = FoundPc(d.address.address, int.tryParse(parts[1]) ?? transferPort, parts.sublist(2).join('|'));
        if (!_found.containsKey(pc.address)) {
          _found[pc.address] = pc;
          _ctrl.add(_found.values.toList());
        }
      });
    } catch (_) {
      // pl. iOS-en a broadcast fogadásához külön Apple-engedély kell: ilyenkor kézi IP-cím
    }
  }

  void stop() {
    _sock?.close();
    _ctrl.close();
  }
}

class TransferException implements Exception {
  TransferException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Letölti és ellenőrzi a csomagot
Future<Project> downloadShow(String host, String code, {int port = transferPort}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final req = await client.getUrl(Uri(scheme: 'http', host: host.trim(), port: port, path: '/show', queryParameters: {'code': code.trim()}));
    final res = await req.close();
    if (res.statusCode == HttpStatus.forbidden) throw TransferException('Hibás kód.');
    if (res.statusCode != HttpStatus.ok) throw TransferException('A PC hibát jelzett (${res.statusCode}).');
    final bytes = <int>[];
    await for (final chunk in res) {
      bytes.addAll(chunk);
    }
    final expected = res.headers.value('x-als-sha256');
    if (expected != null && sha256Hex(bytes) != expected) {
      throw TransferException('Sérült átvitel (ellenőrzőösszeg eltér). Próbáld újra.');
    }
    return parseShowPackage(bytes);
  } on SocketException catch (e) {
    throw TransferException('Nem érhető el a PC (${e.message}). Ugyanazon a Wi-Fin vagytok? A PC-n fut a küldés?');
  } finally {
    client.close(force: true);
  }
}

/// A fellépő csomag helye a mobilon (atomikus csere: előbb ideiglenes fájl, aztán átnevezés)
Future<File> _showFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}${Platform.pathSeparator}aktualis.$showExtension');
}

Future<void> saveShowOnDevice(Project p) async {
  final f = await _showFile();
  final tmp = File('${f.path}.tmp');
  await tmp.writeAsString(p.toFileString(), flush: true);
  await tmp.rename(f.path);
}

Future<Project?> loadShowOnDevice() async {
  try {
    final f = await _showFile();
    if (!await f.exists()) return null;
    return Project.fromFileString(await f.readAsString());
  } catch (_) {
    return null;
  }
}
