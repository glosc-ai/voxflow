import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/core/errors/app_exception.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/core/utils/transcript_exporter.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/stt/models/transcription_result.dart';
import 'package:voxflow/features/stt/services/audio_file_validator.dart';
import 'package:voxflow/features/stt/services/transcription_service.dart';
import 'package:voxflow/features/stt/services/whisper_api_service.dart';

void main() {
  group('TranscriptionResult', () {
    test('解析 verbose_json 片段并导出 SRT', () {
      final result = TranscriptionResult.fromJson({
        'text': '你好，声流',
        'duration': 2.5,
        'segments': [
          {'id': 0, 'start': 0.0, 'end': 1.25, 'text': '你好'},
          {'id': 1, 'start': 1.25, 'end': 2.5, 'text': '声流'},
        ],
      });

      expect(result.text, '你好，声流');
      expect(result.segments, hasLength(2));
      expect(
        TranscriptExporter.toSrt(result),
        '1\n00:00:00,000 --> 00:00:01,250\n你好\n\n'
        '2\n00:00:01,250 --> 00:00:02,500\n声流',
      );
    });

    test('无时间戳时拒绝 SRT', () {
      const result = TranscriptionResult(text: '只有全文', segments: []);
      expect(
        () => TranscriptExporter.toSrt(result),
        throwsA(isA<AppException>()),
      );
    });

    test('Windows 导出路径缺少扩展名时补齐目标格式', () {
      expect(
        TranscriptExporter.ensureExtension(r'C:\exports\transcript', 'txt'),
        r'C:\exports\transcript.txt',
      );
      expect(
        TranscriptExporter.ensureExtension(r'C:\exports\transcript.TXT', 'txt'),
        r'C:\exports\transcript.TXT',
      );
    });
  });

  group('AudioFileValidator', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('voxflow_audio_');
    });

    tearDown(() async {
      await directory.delete(recursive: true);
    });

    test('接受支持的小型音频并拒绝扩展名', () async {
      final valid = File(
        '${directory.path}${Platform.pathSeparator}sample.MP3',
      );
      await valid.writeAsBytes([1, 2, 3]);
      await const AudioFileValidator().validate(valid);

      final invalid = File(
        '${directory.path}${Platform.pathSeparator}sample.exe',
      );
      await invalid.writeAsBytes([1]);
      expect(
        const AudioFileValidator().validate(invalid),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            AppErrorCode.invalidFile,
          ),
        ),
      );
    });
  });

  test('Whisper 请求使用 multipart 与 segment 时间戳字段', () async {
    final directory = await Directory.systemTemp.createTemp('voxflow_stt_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}sample.wav');
    await file.writeAsBytes([1, 2, 3]);
    final adapter = _FakeAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    const settings = SettingsState(
      apiKey: 'test-key',
      baseUrl: 'https://api.openai.com/v1',
      sttModel: 'whisper-1',
      ttsModel: 'tts-1',
    );
    final service = WhisperApiService(DioClient(settings, dio: dio));

    final result = await service.transcribe(file);

    expect(result.text, '测试转录');
    expect(adapter.options!.path, endsWith('/audio/transcriptions'));
    final form = adapter.options!.data as FormData;
    final fields = Map<String, String>.fromEntries(form.fields);
    expect(fields['model'], 'whisper-1');
    expect(fields['response_format'], 'verbose_json');
    expect(fields['timestamp_granularities[]'], 'segment');
    expect(form.files.single.key, 'file');
    expect(adapter.options!.headers['Authorization'], 'Bearer test-key');
  });

  test('SeedASR 使用专属传输而不是 Whisper multipart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'voxflow_seed_asr_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}sample.wav');
    await file.writeAsBytes([1, 2, 3]);
    final adapter = _FakeAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    const settings = SettingsState(
      apiKey: 'test-key',
      baseUrl: 'https://one.gloscai.com/v1',
      sttModel: 'bytedance/volc.seedasr.sauc.duration',
      ttsModel: 'bytedance/seed-tts-2.0',
    );
    final seedAsr = _FakeTranscriptionService();
    final service = WhisperApiService(
      DioClient(settings, dio: dio),
      seedAsrService: seedAsr,
    );

    final result = await service.transcribe(file);

    expect(result.text, 'seed-asr-result');
    expect(seedAsr.calls, 1);
    expect(adapter.options, isNull);
  });
}

class _FakeTranscriptionService implements TranscriptionService {
  int calls = 0;

  @override
  Future<TranscriptionResult> transcribe(
    File file, {
    UploadProgressCallback? onUploadProgress,
    SettingsState? requestSettings,
  }) async {
    calls++;
    onUploadProgress?.call(1);
    return const TranscriptionResult(text: 'seed-asr-result', segments: []);
  }
}

class _FakeAdapter implements HttpClientAdapter {
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    await requestStream?.drain<void>();
    return ResponseBody.fromString(
      jsonEncode({
        'text': '测试转录',
        'duration': 1.0,
        'segments': [
          {'id': 0, 'start': 0.0, 'end': 1.0, 'text': '测试转录'},
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
