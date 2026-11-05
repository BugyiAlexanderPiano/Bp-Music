// flutter_app/lib/sync/sync_client.dart — 7. modul: Wi-Fi szinkron kliens a tableten
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class ManifestEntry {
  ManifestEntry(this.hash, this.size, this.type, this.path);
  factory ManifestEntry.fromJson(Map<String, dynamic> j) =>
      ManifestEntry(j['hash'] as String, j['size'] as int, j['type'] as String, j['path'] as String);
  final String hash, type, path;
  final int size;
}

class SyncException implements Exception {
  SyncException(this.message);
  final String message;
  @override
  String toString() => 'SyncException: $message';
}

class SyncClient {
  SyncClient(this.base, this.http, this.root);
  final Uri base;            // pl. https://192.168.1.20:47800 (párosított, pinned TLS)
  final HttpClient http;     // badCertificateCallback: csak a párosított ujjlenyomat
  final Directory root;      // alkalmazás-adatkönyvtár

  Directory get _objects => Directory('${root.path}/objects');
  File _obj(String h) => File('${_objects.path}/${h.substring(0, 2)}/$h');

  Future<void> pull({void Function(int done, int total)? onProgress}) async {
    final manifestJson = await _getJson('/v1/manifest');
    final entries = (manifestJson['entries'] as List)
        .map((e) => ManifestEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    final missing = <ManifestEntry>[];
    for (final e in entries) {
      if (!await _obj(e.hash).exists()) missing.add(e);
    }

    var done = 0;
    for (final e in missing) {
      await _download(e);
      onProgress?.call(++done, missing.length);
    }

    // Atomikus váltás: az objektumok már helyben vannak, csak az indexet cseréljük.
    final active = File('${root.path}/active.json');
    final staging = File('${root.path}/active.json.staging');
    if (await active.exists()) await active.copy('${root.path}/previous.json');
    await staging.writeAsString(jsonEncode(manifestJson), flush: true);
    await staging.rename(active.path); // POSIX rename: atomikus csere
  }

  Future<void> _download(ManifestEntry e) async {
    final part = File('${_obj(e.hash).path}.part');
    await part.parent.create(recursive: true);
    final have = await part.exists() ? await part.length() : 0;   // folytatás
    final req = await http.getUrl(base.resolve('/v1/objects/${e.hash}'));
    if (have > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$have-');
    final res = await req.close();
    if (res.statusCode != 200 && res.statusCode != 206) {
      throw SyncException('HTTP ${res.statusCode}: ${e.path}');
    }
    final sink = part.openWrite(mode: have > 0 && res.statusCode == 206 ? FileMode.append : FileMode.write);
    await res.pipe(sink);

    final digest = await sha256.bind(part.openRead()).first;
    if (digest.toString() != e.hash) {
      await part.delete();
      throw SyncException('Hash eltérés, újrapróbálkozás szükséges: ${e.path}');
    }
    await part.rename(_obj(e.hash).path);
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final res = await (await http.getUrl(base.resolve(path))).close();
    if (res.statusCode != 200) throw SyncException('HTTP ${res.statusCode}: $path');
    return jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
  }
}
