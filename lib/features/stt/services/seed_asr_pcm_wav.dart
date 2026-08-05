import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../core/errors/app_exception.dart';

/// A WAV payload that is safe to stream through the SeedASR transport.
class SeedAsrPcmWavAudio {
  const SeedAsrPcmWavAudio({required this.bytes, required this.duration});

  final Uint8List bytes;
  final Duration duration;

  static Future<SeedAsrPcmWavAudio?> tryRead(File file) async {
    final bytes = await file.readAsBytes();
    try {
      return _parse(bytes);
    } on FormatException {
      return null;
    }
  }

  static Future<SeedAsrPcmWavAudio> read(File file) async {
    final audio = await tryRead(file);
    if (audio != null) {
      return audio;
    }
    throw const AppException(
      AppErrorCode.invalidFile,
      '无法准备符合 SeedASR 要求的 16 kHz、16-bit、单声道 PCM WAV。',
      englishMessage:
          'Unable to prepare the 16 kHz, 16-bit, mono PCM WAV required by SeedASR.',
    );
  }

  static SeedAsrPcmWavAudio _parse(Uint8List bytes) {
    if (bytes.length < 44 ||
        _ascii(bytes, 0, 4) != 'RIFF' ||
        _ascii(bytes, 8, 4) != 'WAVE') {
      throw const FormatException('not a RIFF WAVE file');
    }
    final data = ByteData.sublistView(bytes);
    int? format;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    int? dataLength;
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunkId = _ascii(bytes, offset, 4);
      final chunkLength = data.getUint32(offset + 4, Endian.little);
      final chunkStart = offset + 8;
      if (chunkStart + chunkLength > bytes.length) {
        throw const FormatException('truncated WAV chunk');
      }
      if (chunkId == 'fmt ' && chunkLength >= 16) {
        format = data.getUint16(chunkStart, Endian.little);
        channels = data.getUint16(chunkStart + 2, Endian.little);
        sampleRate = data.getUint32(chunkStart + 4, Endian.little);
        bitsPerSample = data.getUint16(chunkStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataLength = chunkLength;
      }
      offset = chunkStart + chunkLength + (chunkLength.isOdd ? 1 : 0);
    }
    if (format != 1 ||
        channels != 1 ||
        sampleRate != 16000 ||
        bitsPerSample != 16 ||
        dataLength == null ||
        dataLength <= 0) {
      throw const FormatException('unsupported PCM WAV parameters');
    }
    final microseconds =
        dataLength * Duration.microsecondsPerSecond ~/ (16000 * 2);
    return SeedAsrPcmWavAudio(
      bytes: bytes,
      duration: Duration(microseconds: microseconds),
    );
  }

  static String _ascii(Uint8List bytes, int offset, int length) {
    return ascii.decode(bytes.sublist(offset, offset + length));
  }
}
