// lib/midi/midi_backend.dart — egységes MIDI-réteg
//
//  Asztali gép (Windows, macOS): a C++ mag (als_core_ffi) — RtMidi, natív rétegmotor
//  Tablet, telefon (Android, iOS):  flutter_midi_command (USB/OTG és Bluetooth MIDI)
//                                    + Dart Yamaha üzenetek és rétegmotor
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command_ble/flutter_midi_command_ble.dart';

import '../ffi/als_core.dart';

class AlsMidiPort {
  const AlsMidiPort(this.id, this.name, {this.bluetooth = false});
  final String id;
  final String name;
  final bool bluetooth;
}

abstract class MidiBackend {
  static MidiBackend create() =>
      (Platform.isAndroid || Platform.isIOS) ? MobileMidiBackend() : DesktopMidiBackend();

  /// null = rendben; különben a hiba szövege (pl. a mag nem tölthető be)
  String? get error;
  bool get connected;
  bool get supportsTestMode;

  Future<(List<AlsMidiPort>, List<AlsMidiPort>)> ports({bool scanBluetooth = false});
  Future<bool> connect({AlsMidiPort? input, AlsMidiPort? output, bool testMode = false});
  void onRealtime(void Function(int status, int tsUs) handler);
  int nowUs();

  void styleStart();
  void styleStop();
  void section(int code);
  void tempo(double bpm);
  void voice(int channel, int msb, int lsb, int program, int volume);
  void setZone(int slot,
      {required bool enabled, required int low, required int high, required int velLow,
      required int transpose, required double velCurve, required int outChannel});
  void close();
}

// ---------------------------------------------------------------------------
// Asztali: C++ mag
// ---------------------------------------------------------------------------
class DesktopMidiBackend implements MidiBackend {
  DesktopMidiBackend() {
    try {
      core = AlsCore.load();
    } catch (e) {
      _error = 'A zenei mag (als_core_ffi) nem tölthető be: $e';
    }
  }

  AlsCore? core;
  String? _error;
  bool _connected = false;

  @override
  String? get error => _error;
  @override
  bool get connected => _connected;
  @override
  bool get supportsTestMode => true;

  @override
  Future<(List<AlsMidiPort>, List<AlsMidiPort>)> ports({bool scanBluetooth = false}) async {
    final c = core;
    if (c == null) return (<AlsMidiPort>[], <AlsMidiPort>[]);
    final (ins, outs) = c.listPorts();
    return (
      [for (var i = 0; i < ins.length; i++) AlsMidiPort('$i', ins[i])],
      [for (var i = 0; i < outs.length; i++) AlsMidiPort('$i', outs[i])],
    );
  }

  @override
  Future<bool> connect({AlsMidiPort? input, AlsMidiPort? output, bool testMode = false}) async {
    final c = core;
    if (c == null) return false;
    _connected = testMode
        ? c.open(testMode: true)
        : c.open(inPort: input == null ? -1 : int.parse(input.id), outPort: output == null ? 0 : int.parse(output.id));
    return _connected;
  }

  @override
  void onRealtime(void Function(int status, int tsUs) handler) => core?.onRealtime(handler);
  @override
  int nowUs() => core?.nowUs() ?? DateTime.now().microsecondsSinceEpoch;
  @override
  void styleStart() => core?.styleStart();
  @override
  void styleStop() => core?.styleStop();
  @override
  void section(int code) => core?.section(code);
  @override
  void tempo(double bpm) => core?.tempo(bpm);
  @override
  void voice(int channel, int msb, int lsb, int program, int volume) => core?.voice(channel, msb, lsb, program, volume);
  @override
  void setZone(int slot,
          {required bool enabled, required int low, required int high, required int velLow,
          required int transpose, required double velCurve, required int outChannel}) =>
      core?.setZone(slot,
          enabled: enabled, low: low, high: high, velLow: velLow, transpose: transpose, velCurve: velCurve, outChannel: outChannel);
  @override
  void close() => core?.close();
}

// ---------------------------------------------------------------------------
// Mobil: flutter_midi_command + Dart rétegmotor
// ---------------------------------------------------------------------------
class _Zone {
  bool enabled = false;
  int low = 0, high = 127, velLow = 1, transpose = 0, outChannel = 8;
  double curve = 1.0;
}

class MobileMidiBackend implements MidiBackend {
  MobileMidiBackend() {
    // Bluetooth MIDI (pl. Yamaha UD-BT01 / MD-BT01 adapter) a USB/OTG mellett
    try {
      _midi.configureBleTransport(UniversalBleMidiTransport());
    } catch (_) {}
  }

  final _midi = MidiCommand();
  final _clock = Stopwatch()..start();
  MidiDevice? _device;
  StreamSubscription<MidiPacket>? _sub;
  void Function(int, int)? _rt;
  final _zones = List.generate(4, (_) => _Zone());
  final _active = List.generate(4, (_) => List<int>.filled(128, -1));
  final int _inChannel = 0; // Right 1 küldési csatornája a hangszeren

  @override
  String? get error => null;
  @override
  bool get connected => _device != null;
  @override
  bool get supportsTestMode => false;

  @override
  Future<(List<AlsMidiPort>, List<AlsMidiPort>)> ports({bool scanBluetooth = false}) async {
    if (scanBluetooth) {
      try {
        await _midi.startBluetooth();
        await _midi.startScanningForBluetoothDevices();
        await Future<void>.delayed(const Duration(seconds: 4));
        _midi.stopScanningForBluetoothDevices();
      } catch (_) {}
    }
    final devs = await _midi.devices ?? <MidiDevice>[];
    final list = [for (final d in devs) AlsMidiPort(d.id, d.name, bluetooth: d.type == MidiDeviceType.ble)];
    return (list, list);
  }

  @override
  Future<bool> connect({AlsMidiPort? input, AlsMidiPort? output, bool testMode = false}) async {
    final target = output ?? input;
    if (target == null) return false;
    final devs = await _midi.devices ?? <MidiDevice>[];
    MidiDevice? dev;
    for (final d in devs) {
      if (d.id == target.id) dev = d;
    }
    if (dev == null) return false;
    try {
      if (_device != null) _midi.disconnectDevice(_device!);
      await _midi.connectToDevice(dev);
      _device = dev;
      await _sub?.cancel();
      _sub = _midi.onMidiPacketReceived?.listen(_onPacket);
      return true;
    } catch (_) {
      _device = null;
      return false;
    }
  }

  void _send(List<int> bytes) {
    final d = _device;
    if (d == null) return;
    _midi.sendData(Uint8List.fromList(bytes), deviceId: d.id);
  }

  // ---- bejövő üzenetek: real-time a Smart Readernek, hangjegyek a rétegmotornak ----
  void _onPacket(MidiPacket p) {
    final data = p.data; // a csomag pontosan egy teljes MIDI-üzenet
    if (data.isEmpty) return;
    final b = data[0];
    if (b >= 0xF8) {
      _rt?.call(b, nowUs());
    } else if (b != 0xF0 && b & 0x80 != 0 && data.length >= 2) {
      _onChannelMessage(data);
    }
  }

  void _onChannelMessage(List<int> m) {
    final st = m[0] & 0xF0, ch = m[0] & 0x0F;
    if (ch != _inChannel) return;
    if (st == 0x90 && m[2] > 0) {
      for (var i = 0; i < 4; i++) {
        final z = _zones[i];
        if (!z.enabled || m[1] < z.low || m[1] > z.high || m[2] < z.velLow) continue;
        final note = m[1] + z.transpose;
        if (note < 0 || note > 127) continue;
        final vel = (math.pow(m[2] / 127, z.curve) * 127).round().clamp(1, 127);
        _active[i][m[1]] = note;
        _send([0x90 | z.outChannel, note, vel]);
      }
    } else if (st == 0x80 || st == 0x90) {
      for (var i = 0; i < 4; i++) {
        final n = _active[i][m[1]];
        if (n < 0) continue;
        _send([0x80 | _zones[i].outChannel, n, 0x40]);
        _active[i][m[1]] = -1;
      }
    } else if (st == 0xB0 || st == 0xE0 || st == 0xD0) {
      for (final z in _zones) {
        if (z.enabled) _send([st | z.outChannel, ...m.sublist(1)]);
      }
    }
  }

  @override
  void onRealtime(void Function(int status, int tsUs) handler) => _rt = handler;
  @override
  int nowUs() => _clock.elapsedMicroseconds;

  // ---- Yamaha üzenetek (ugyanazok, mint a C++ magban) ----
  @override
  void styleStart() => _send(const [0xF0, 0x43, 0x60, 0x7A, 0xF7]);
  @override
  void styleStop() => _send(const [0xF0, 0x43, 0x60, 0x7D, 0xF7]);
  @override
  void section(int code) => _send([0xF0, 0x43, 0x7E, 0x00, code & 0x7F, 0x7F, 0xF7]);
  @override
  void tempo(double bpm) {
    final us = (60000000 / bpm).round();
    _send([0xF0, 0x43, 0x7E, 0x01, (us >> 21) & 0x7F, (us >> 14) & 0x7F, (us >> 7) & 0x7F, us & 0x7F, 0xF7]);
  }

  @override
  void voice(int channel, int msb, int lsb, int program, int volume) {
    final c = channel & 0x0F;
    _send([0xB0 | c, 0x00, msb & 0x7F]);
    _send([0xB0 | c, 0x20, lsb & 0x7F]);
    _send([0xC0 | c, program & 0x7F]);
    _send([0xB0 | c, 0x07, volume & 0x7F]);
  }

  @override
  void setZone(int slot,
      {required bool enabled, required int low, required int high, required int velLow,
      required int transpose, required double velCurve, required int outChannel}) {
    if (slot < 0 || slot >= 4) return;
    // a régi zóna szóló hangjainak elengedése
    for (var n = 0; n < 128; n++) {
      final a = _active[slot][n];
      if (a >= 0) {
        _send([0x80 | _zones[slot].outChannel, a, 0x40]);
        _active[slot][n] = -1;
      }
    }
    _zones[slot]
      ..enabled = enabled
      ..low = low
      ..high = high
      ..velLow = velLow
      ..transpose = transpose
      ..curve = velCurve
      ..outChannel = outChannel & 0x0F;
  }

  @override
  void close() {
    _sub?.cancel();
    if (_device != null) _midi.disconnectDevice(_device!);
    _device = null;
  }
}
