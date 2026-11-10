// lib/audio/wav_peaks.dart — WAV beolvasás a hullámforma-kijelzéshez (külön isolate-ban)
import 'dart:io';
import 'dart:typed_data';

class WavInfo {
  WavInfo({
    required this.sampleRate,
    required this.channels,
    required this.bits,
    required this.isFloat,
    required this.frames,
    required this.mins,
    required this.maxs,
    this.loopStart = -1,
    this.loopEnd = -1,
    this.seam,
  });

  final int sampleRate, channels, bits, frames;
  final bool isFloat;
  /// Oszloponkénti minimum/maximum (mono), a kijelző szélességére sűrítve
  final Float32List mins, maxs;
  final int loopStart, loopEnd;
  /// A loop varrata körüli minták (vég előtti rész + eleje utáni rész), nagyításhoz
  final Float32List? seam;

  double get seconds => frames / sampleRate;
  String get format => '${sampleRate / 1000} kHz · ${isFloat ? '32 bit float' : '$bits bit'} · ${channels == 1 ? 'mono' : channels == 2 ? 'sztereó' : '$channels csatorna'}';
}

/// Beolvas egy WAV-ot és `columns` oszlopra sűríti. Isolate.run-nal hívd.
WavInfo readWavPeaks(String path, int columns) {
  final b = File(path).readAsBytesSync();
  final bd = ByteData.sublistView(b);
  if (b.length < 12 || String.fromCharCodes(b.sublist(0, 4)) != 'RIFF' || String.fromCharCodes(b.sublist(8, 12)) != 'WAVE') {
    throw const FormatException('Nem WAV fájl');
  }
  var pos = 12, ch = 1, sr = 44100, bits = 16, fmt = 1, dataOff = -1, dataLen = 0, ls = -1, le = -1;
  while (pos + 8 <= b.length) {
    final id = String.fromCharCodes(b.sublist(pos, pos + 4));
    final size = bd.getUint32(pos + 4, Endian.little);
    final body = pos + 8;
    if (id == 'fmt ') {
      fmt = bd.getUint16(body, Endian.little);
      ch = bd.getUint16(body + 2, Endian.little);
      sr = bd.getUint32(body + 4, Endian.little);
      bits = bd.getUint16(body + 14, Endian.little);
      if (fmt == 0xFFFE && size >= 26) fmt = bd.getUint16(body + 24, Endian.little);
    } else if (id == 'data') {
      dataOff = body;
      dataLen = (size).clamp(0, b.length - body);
    } else if (id == 'smpl' && size >= 60 && bd.getUint32(body + 28, Endian.little) > 0) {
      ls = bd.getUint32(body + 44, Endian.little);
      le = bd.getUint32(body + 48, Endian.little);
    }
    pos = body + size + (size & 1);
  }
  if (dataOff < 0) throw const FormatException('Hiányzó data blokk');
  final bps = bits ~/ 8;
  final frames = dataLen ~/ (bps * ch);

  double sample(int frame, int c) {
    final o = dataOff + (frame * ch + c) * bps;
    if (fmt == 3) return bd.getFloat32(o, Endian.little);
    switch (bps) {
      case 2:
        return bd.getInt16(o, Endian.little) / 32768.0;
      case 3:
        final v = b[o] | (b[o + 1] << 8) | (b[o + 2] << 16);
        return (v >= 0x800000 ? v - 0x1000000 : v) / 8388608.0;
      default:
        return bd.getInt32(o, Endian.little) / 2147483648.0;
    }
  }

  double mono(int f) {
    var s = 0.0;
    for (var c = 0; c < ch; c++) {
      s += sample(f, c);
    }
    return s / ch;
  }

  final cols = columns.clamp(1, frames == 0 ? 1 : frames);
  final mins = Float32List(cols), maxs = Float32List(cols);
  for (var x = 0; x < cols; x++) {
    final a = (x * frames) ~/ cols, e = ((x + 1) * frames) ~/ cols;
    var lo = 0.0, hi = 0.0;
    // nagy fájlnál ritkított mintavétel (kijelzéshez elég)
    final step = ((e - a) ~/ 400).clamp(1, 1 << 20);
    for (var f = a; f < e; f += step) {
      final v = mono(f);
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    mins[x] = lo;
    maxs[x] = hi;
  }

  Float32List? seam;
  if (ls >= 0 && le > ls && le < frames) {
    final n = (sr * 0.012).round(); // 12 ms mindkét oldalon
    seam = Float32List(2 * n);
    for (var i = 0; i < n; i++) {
      final f1 = le - n + 1 + i;
      seam[i] = f1 >= 0 ? mono(f1) : 0;
      final f2 = ls + i;
      seam[n + i] = f2 < frames ? mono(f2) : 0;
    }
  }

  return WavInfo(
    sampleRate: sr,
    channels: ch,
    bits: bits,
    isFloat: fmt == 3,
    frames: frames,
    mins: mins,
    maxs: maxs,
    loopStart: ls,
    loopEnd: le,
    seam: seam,
  );
}
