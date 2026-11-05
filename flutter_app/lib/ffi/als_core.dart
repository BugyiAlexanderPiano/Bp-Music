// flutter_app/lib/ffi/als_core.dart — a C++ mag (als_core_ffi) hívása Dartból
// A függvények az als_core_api.h deklarációit tükrözik.
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _RealtimeNative = Void Function(Int32 status, Int64 tsUs);

class AlsCore {
  AlsCore._(this._lib)
      : _open = _lib.lookupFunction<Int32 Function(Int32, Int32, Int32), int Function(int, int, int)>('als_open'),
        _close = _lib.lookupFunction<Void Function(), void Function()>('als_close'),
        _nowUs = _lib.lookupFunction<Int64 Function(), int Function()>('als_now_us'),
        _setRt = _lib.lookupFunction<Void Function(Pointer<NativeFunction<_RealtimeNative>>),
            void Function(Pointer<NativeFunction<_RealtimeNative>>)>('als_set_realtime_callback'),
        _styleStart = _lib.lookupFunction<Int32 Function(), int Function()>('als_style_start'),
        _styleStop = _lib.lookupFunction<Int32 Function(), int Function()>('als_style_stop'),
        _section = _lib.lookupFunction<Int32 Function(Int32), int Function(int)>('als_section'),
        _tempo = _lib.lookupFunction<Int32 Function(Double), int Function(double)>('als_tempo'),
        _setZone = _lib.lookupFunction<
            Int32 Function(Int32, Int32, Int32, Int32, Int32, Int32, Int32, Float, Int32),
            int Function(int, int, int, int, int, int, int, double, int)>('als_set_zone'),
        _listPorts = _lib.lookupFunction<Int32 Function(Pointer<Utf8>, Int32),
            int Function(Pointer<Utf8>, int)>('als_list_ports');

  /// Platformonként a megfelelő könyvtárat tölti be.
  factory AlsCore.load() {
    final DynamicLibrary lib;
    if (Platform.isWindows) {
      lib = DynamicLibrary.open('als_core_ffi.dll');
    } else if (Platform.isMacOS) {
      lib = DynamicLibrary.open('libals_core_ffi.dylib');
    } else if (Platform.isAndroid) {
      lib = DynamicLibrary.open('libals_core_ffi.so');
    } else {
      lib = DynamicLibrary.open('libals_core_ffi.so');
    }
    return AlsCore._(lib);
  }

  final DynamicLibrary _lib;
  final int Function(int, int, int) _open;
  final void Function() _close;
  final int Function() _nowUs;
  final void Function(Pointer<NativeFunction<_RealtimeNative>>) _setRt;
  final int Function() _styleStart, _styleStop;
  final int Function(int) _section;
  final int Function(double) _tempo;
  final int Function(int, int, int, int, int, int, int, double, int) _setZone;
  final int Function(Pointer<Utf8>, int) _listPorts;
  NativeCallable<_RealtimeNative>? _rtCallable;

  List<String> listPorts() {
    final need = _listPorts(nullptr, 0);
    final buf = calloc<Uint8>(need).cast<Utf8>();
    try {
      _listPorts(buf, need);
      return buf.toDartString().split('\n').where((s) => s.isNotEmpty).toList();
    } finally {
      calloc.free(buf);
    }
  }

  bool open({int inPort = -1, int outPort = 0, bool console = false}) =>
      _open(inPort, outPort, console ? 1 : 0) == 0;

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

  void close() {
    _setRt(nullptr);
    _rtCallable?.close();
    _rtCallable = null;
    _close();
  }
}
