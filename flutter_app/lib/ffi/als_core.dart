// flutter_app/lib/ffi/als_core.dart — a C++ mag (als_core_ffi) hívása Dartból
// A függvények az als_core_api.h deklarációit tükrözik.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _RealtimeNative = Void Function(Int32 status, Int64 tsUs);

class TrimResult {
  TrimResult(this.ok, this.json);
  final bool ok;
  final Map<String, dynamic> json;
}

class AlsCore {
  AlsCore._(DynamicLibrary lib)
      : _open = lib.lookupFunction<Int32 Function(Int32, Int32, Int32), int Function(int, int, int)>('als_open'),
        _close = lib.lookupFunction<Void Function(), void Function()>('als_close'),
        _nowUs = lib.lookupFunction<Int64 Function(), int Function()>('als_now_us'),
        _setRt = lib.lookupFunction<Void Function(Pointer<NativeFunction<_RealtimeNative>>),
            void Function(Pointer<NativeFunction<_RealtimeNative>>)>('als_set_realtime_callback'),
        _styleStart = lib.lookupFunction<Int32 Function(), int Function()>('als_style_start'),
        _styleStop = lib.lookupFunction<Int32 Function(), int Function()>('als_style_stop'),
        _section = lib.lookupFunction<Int32 Function(Int32), int Function(int)>('als_section'),
        _tempo = lib.lookupFunction<Int32 Function(Double), int Function(double)>('als_tempo'),
        _setZone = lib.lookupFunction<
            Int32 Function(Int32, Int32, Int32, Int32, Int32, Int32, Int32, Float, Int32),
            int Function(int, int, int, int, int, int, int, double, int)>('als_set_zone'),
        _voice = lib.lookupFunction<Int32 Function(Int32, Int32, Int32, Int32, Int32),
            int Function(int, int, int, int, int)>('als_voice'),
        _listPorts = lib.lookupFunction<Int32 Function(Pointer<Utf8>, Int32),
            int Function(Pointer<Utf8>, int)>('als_list_ports'),
        _fileDialog = lib.lookupFunction<Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32),
            int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int)>('als_open_file_dialog'),
        _trim = lib.lookupFunction<Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32),
            int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int)>('als_trim_wav');

  /// A program mappájából tölti be a magot. Hiba esetén kivételt dob.
  factory AlsCore.load() {
    final String name;
    if (Platform.isWindows) {
      name = 'als_core_ffi.dll';
    } else if (Platform.isMacOS) {
      name = 'libals_core_ffi.dylib';
    } else {
      name = 'libals_core_ffi.so';
    }
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final local = File('$exeDir${Platform.pathSeparator}$name');
    return AlsCore._(DynamicLibrary.open(local.existsSync() ? local.path : name));
  }

  final int Function(int, int, int) _open;
  final void Function() _close;
  final int Function() _nowUs;
  final void Function(Pointer<NativeFunction<_RealtimeNative>>) _setRt;
  final int Function() _styleStart, _styleStop;
  final int Function(int) _section;
  final int Function(double) _tempo;
  final int Function(int, int, int, int, int, int, int, double, int) _setZone;
  final int Function(int, int, int, int, int) _voice;
  final int Function(Pointer<Utf8>, int) _listPorts;
  final int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int) _fileDialog;
  final int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int) _trim;
  NativeCallable<_RealtimeNative>? _rtCallable;

  /// (bemenetek, kimenetek) a rendszer MIDI-portjairól
  (List<String>, List<String>) listPorts() {
    final need = _listPorts(nullptr, 0);
    final buf = calloc<Uint8>(need + 1).cast<Utf8>();
    try {
      _listPorts(buf, need + 1);
      final lines = buf.toDartString().split('\n').where((s) => s.isNotEmpty);
      return (
        [for (final l in lines) if (l.startsWith('IN:')) l.substring(3)],
        [for (final l in lines) if (l.startsWith('OUT:')) l.substring(4)],
      );
    } finally {
      calloc.free(buf);
    }
  }

  bool open({int inPort = -1, int outPort = 0, bool testMode = false}) =>
      _open(inPort, outPort, testMode ? 1 : 0) == 0;

  /// A MIDI-szálról érkező Clock/Start/Stop eseményeket a Dart eseményhurokba továbbítja.
  void onRealtime(void Function(int status, int tsUs) handler) {
    _rtCallable?.close();
    _rtCallable = NativeCallable<_RealtimeNative>.listener(handler);
    _setRt(_rtCallable!.nativeFunction);
  }

  /// A mag monoton órája (µs) — ezzel összevethetők a MIDI időbélyegek.
  int nowUs() => _nowUs();

  void styleStart() => _styleStart();
  void styleStop() => _styleStop();
  void section(int yamahaCode) => _section(yamahaCode);
  void tempo(double bpm) => _tempo(bpm);

  void setZone(int slot,
          {bool enabled = true, int low = 0, int high = 127, int velLow = 1, int velHigh = 127,
          int transpose = 0, double velCurve = 1.0, required int outChannel}) =>
      _setZone(slot, enabled ? 1 : 0, low, high, velLow, velHigh, transpose, velCurve, outChannel);

  void voice(int channel, int msb, int lsb, int program, int volume) =>
      _voice(channel, msb, lsb, program, volume);

  /// Windows fájlmegnyitó ablak; null, ha a felhasználó mégsem választott.
  String? pickFile(String title, String ext) {
    final t = title.toNativeUtf8(), e = ext.toNativeUtf8();
    final out = calloc<Uint8>(8192).cast<Utf8>();
    try {
      return _fileDialog(t, e, out, 8192) == 0 ? out.toDartString() : null;
    } finally {
      calloc.free(t);
      calloc.free(e);
      calloc.free(out);
    }
  }

  TrimResult trimWav(String inPath, String outPath) {
    final i = inPath.toNativeUtf8(), o = outPath.toNativeUtf8();
    final rep = calloc<Uint8>(1024).cast<Utf8>();
    try {
      final rc = _trim(i, o, rep, 1024);
      Map<String, dynamic> json;
      try {
        json = jsonDecode(rep.toDartString()) as Map<String, dynamic>;
      } catch (_) {
        json = {'error': 'ismeretlen hiba ($rc)'};
      }
      return TrimResult(rc == 0, json);
    } finally {
      calloc.free(i);
      calloc.free(o);
      calloc.free(rep);
    }
  }

  void close() {
    _setRt(nullptr);
    _rtCallable?.close();
    _rtCallable = null;
    _close();
  }
}
