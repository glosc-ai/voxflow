import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/core/constants/app_constants.dart';
import 'package:voxflow/core/errors/app_exception.dart';
import 'package:voxflow/features/stt/services/audio_normalization_service.dart';

void main() {
  late Directory directory;
  late File temporaryOutput;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('voxflow_normalize_');
    temporaryOutput = File(
      '${directory.path}${Platform.pathSeparator}seed_asr_normalized.wav',
    );
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('兼容的 PCM WAV 直接复用且不会删除源文件', () async {
    final source = File(
      '${directory.path}${Platform.pathSeparator}compatible.wav',
    );
    await source.writeAsBytes(_pcmWav(dataBytes: 3200));
    var runnerCalls = 0;
    final normalizer = FfmpegAudioNormalizationService(
      runTranscode: (arguments, timeout) async {
        runnerCalls++;
        return 0;
      },
      temporaryPath: _temporaryPathFor(temporaryOutput),
    );

    final selectedPath = await normalizer.withSeedAsrAudio(source, (
      file,
      audio,
    ) async {
      expect(audio.bytes, isNotEmpty);
      return file.path;
    });

    expect(selectedPath, source.path);
    expect(runnerCalls, 0);
    expect(await source.exists(), isTrue);
  });

  test('不兼容音频通过参数数组转换并在使用后清理临时文件', () async {
    final source = File(
      '${directory.path}${Platform.pathSeparator}source file.mp3',
    );
    await source.writeAsBytes([1, 2, 3]);
    List<String>? capturedArguments;
    Duration? capturedTimeout;
    final normalizer = FfmpegAudioNormalizationService(
      runTranscode: (arguments, timeout) async {
        capturedArguments = List.of(arguments);
        capturedTimeout = timeout;
        await File(arguments.last).writeAsBytes(_pcmWav(dataBytes: 6400));
        return 0;
      },
      temporaryPath: _temporaryPathFor(temporaryOutput),
    );
    String? normalizedPath;

    final value = await normalizer.withSeedAsrAudio(source, (
      file,
      audio,
    ) async {
      normalizedPath = file.path;
      expect(await file.exists(), isTrue);
      expect(file.path, temporaryOutput.path);
      expect(audio.bytes, isNotEmpty);
      return 'transcribed';
    });

    expect(value, 'transcribed');
    expect(capturedTimeout, const Duration(minutes: 5));
    expect(capturedArguments, [
      '-y',
      '-nostdin',
      '-hide_banner',
      '-nostats',
      '-loglevel',
      'quiet',
      '-i',
      source.path,
      '-map',
      '0:a:0',
      '-vn',
      '-ar',
      '16000',
      '-ac',
      '1',
      '-c:a',
      'pcm_s16le',
      '-f',
      'wav',
      '-fs',
      AppConstants.maxTranscriptionBytes.toString(),
      '${temporaryOutput.path}.part',
    ]);
    expect(normalizedPath, temporaryOutput.path);
    expect(await temporaryOutput.exists(), isFalse);
    expect(await File('${temporaryOutput.path}.part').exists(), isFalse);
    expect(await source.exists(), isTrue);
  });

  test('转录回调失败时仍清理规范化文件并保留源文件', () async {
    final source = File('${directory.path}${Platform.pathSeparator}source.m4a');
    await source.writeAsBytes([1, 2, 3]);
    final normalizer = FfmpegAudioNormalizationService(
      runTranscode: (arguments, timeout) async {
        await File(arguments.last).writeAsBytes(_pcmWav(dataBytes: 3200));
        return 0;
      },
      temporaryPath: _temporaryPathFor(temporaryOutput),
    );

    await expectLater(
      normalizer.withSeedAsrAudio<void>(
        source,
        (_, __) async => throw StateError('network failed'),
      ),
      throwsStateError,
    );

    expect(await temporaryOutput.exists(), isFalse);
    expect(await File('${temporaryOutput.path}.part').exists(), isFalse);
    expect(await source.exists(), isTrue);
  });

  test('FFmpeg 失败映射为不含本地路径的应用异常并清理残留', () async {
    final source = File(
      '${directory.path}${Platform.pathSeparator}sensitive-name.webm',
    );
    await source.writeAsBytes([1, 2, 3]);
    final normalizer = FfmpegAudioNormalizationService(
      runTranscode: (arguments, timeout) async {
        await File(arguments.last).writeAsBytes([1, 2, 3]);
        return 1;
      },
      temporaryPath: _temporaryPathFor(temporaryOutput),
    );

    late AppException exception;
    try {
      await normalizer.withSeedAsrAudio<void>(source, (_, __) async {});
      fail('Expected conversion to fail.');
    } on AppException catch (error) {
      exception = error;
    }

    expect(exception.code, AppErrorCode.invalidFile);
    expect(exception.message, contains('转换'));
    expect(exception.technicalDetail, 'ffmpeg_exit_code=1');
    expect(exception.toString(), isNot(contains(source.path)));
    expect(exception.toString(), isNot(contains(temporaryOutput.path)));
    expect(await temporaryOutput.exists(), isFalse);
    expect(await File('${temporaryOutput.path}.part').exists(), isFalse);
    expect(await source.exists(), isTrue);
  });

  test('转换超时会映射为可诊断错误', () async {
    final source = File('${directory.path}${Platform.pathSeparator}source.mp4');
    await source.writeAsBytes([1, 2, 3]);
    final normalizer = FfmpegAudioNormalizationService(
      runTranscode: (arguments, timeout) async {
        throw TimeoutException('timeout');
      },
      temporaryPath: _temporaryPathFor(temporaryOutput),
    );

    await expectLater(
      normalizer.withSeedAsrAudio<void>(source, (_, __) async {}),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.invalidFile)
            .having(
              (error) => error.technicalDetail,
              'technicalDetail',
              'ffmpeg_timeout',
            ),
      ),
    );
  });

  test('转换结果必须再次满足 SeedASR 格式并且不超过大小限制', () async {
    final source = File(
      '${directory.path}${Platform.pathSeparator}source.mpeg',
    );
    await source.writeAsBytes([1, 2, 3]);
    final invalidOutput = FfmpegAudioNormalizationService(
      runTranscode: (arguments, timeout) async {
        await File(arguments.last).writeAsBytes([1, 2, 3]);
        return 0;
      },
      temporaryPath: _temporaryPathFor(temporaryOutput),
    );

    await expectLater(
      invalidOutput.withSeedAsrAudio<void>(source, (_, __) async {}),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          AppErrorCode.invalidFile,
        ),
      ),
    );

    final cappedWav = _pcmWav(dataBytes: 3200);
    final oversizedOutput = FfmpegAudioNormalizationService(
      runTranscode: (arguments, timeout) async {
        await File(arguments.last).writeAsBytes(cappedWav);
        return 0;
      },
      temporaryPath: _temporaryPathFor(temporaryOutput),
      maxOutputBytes: cappedWav.length,
    );

    await expectLater(
      oversizedOutput.withSeedAsrAudio<void>(source, (_, __) async {}),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          AppErrorCode.fileTooLarge,
        ),
      ),
    );
  });
}

TemporaryAudioPathProvider _temporaryPathFor(File output) {
  return ({required String stem, required String extension}) async {
    expect(stem, 'seed_asr_normalized');
    expect(extension, 'wav');
    return output.path;
  };
}

Uint8List _pcmWav({required int dataBytes}) {
  final bytes = Uint8List(44 + dataBytes);
  final data = ByteData.sublistView(bytes);

  void writeAscii(int offset, String value) {
    bytes.setRange(offset, offset + value.length, ascii.encode(value));
  }

  writeAscii(0, 'RIFF');
  data.setUint32(4, 36 + dataBytes, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  data.setUint32(40, dataBytes, Endian.little);
  return bytes;
}
