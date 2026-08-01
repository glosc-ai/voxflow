import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/core/constants/app_constants.dart';
import 'package:voxflow/core/errors/app_exception.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/tts/models/tts_request.dart';
import 'package:voxflow/features/tts/models/tts_state.dart';
import 'package:voxflow/features/tts/providers/tts_provider.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';
import 'package:voxflow/features/tts/services/tts_api_service.dart';

const _settings = SettingsState(
  apiKey: 'test-key',
  baseUrl: 'https://api.openai.com/v1',
  sttModel: 'whisper-1',
  ttsModel: 'tts-1',
);

void main() {
  group('TtsRequest', () {
    test('验证并生成 OpenAI 请求字段', () {
      const request = TtsRequest(
        text: ' 你好 ',
        model: 'tts-1',
        voice: 'nova',
        speed: 1.25,
      );
      final valid = request.validated();

      expect(valid.text, '你好');
      expect(valid.toJson(), {
        'model': 'tts-1',
        'input': '你好',
        'voice': 'nova',
        'speed': 1.25,
      });
    });

    test('Seed TTS 默认参数生成文档规定的最小请求', () {
      const request = TtsRequest(
        text: '你好，欢迎使用 GLOSC AI。',
        model: 'bytedance/seed-tts-2.0',
        voice: 'zh_female_cancan_uranus_bigtts',
        speed: 1,
      );

      expect(request.validated().toJson(), {
        'model': 'bytedance/seed-tts-2.0',
        'input': '你好，欢迎使用 GLOSC AI。',
        'voice': 'zh_female_cancan_uranus_bigtts',
      });
    });

    test('非默认语速仍写入请求', () {
      const request = TtsRequest(
        text: '测试',
        model: 'tts-1',
        voice: 'alloy',
        speed: 1.5,
      );

      expect(request.validated().toJson(), {
        'model': 'tts-1',
        'input': '测试',
        'voice': 'alloy',
        'speed': 1.5,
      });
    });

    test('拒绝空文本、无效音色、越界语速和非 MP3 格式', () {
      expect(
        () => const TtsRequest(
          text: '测试',
          model: 'bytedance/seed-tts-2.0',
          voice: 'alloy',
          speed: 1,
        ).validated(),
        throwsA(isA<AppException>()),
      );
      expect(
        () => const TtsRequest(
          text: '',
          model: 'tts-1',
          voice: 'alloy',
          speed: 1,
        ).validated(),
        throwsA(isA<AppException>()),
      );
      expect(
        () => const TtsRequest(
          text: '测试',
          model: 'tts-1',
          voice: 'invalid',
          speed: 5,
        ).validated(),
        throwsA(isA<AppException>()),
      );
      expect(
        () => const TtsRequest(
          text: '测试',
          model: 'tts-1',
          voice: 'alloy',
          speed: 1,
          responseFormat: 'wav',
        ).validated(),
        throwsA(isA<AppException>()),
      );
    });
  });

  test('TTS 服务发送 JSON 并保存字节响应', () async {
    final directory = await Directory.systemTemp.createTemp('voxflow_tts_');
    addTearDown(() => directory.delete(recursive: true));
    final adapter = _BytesAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final service = TtsApiService(
      DioClient(_settings, dio: dio),
      writer: (bytes) async {
        final file =
            File('${directory.path}${Platform.pathSeparator}voice.mp3');
        return file.writeAsBytes(bytes, flush: true);
      },
    );

    final file = await service.synthesize(
      const TtsRequest(
        text: '测试语音',
        model: 'tts-1',
        voice: 'alloy',
        speed: 1,
      ),
    );

    expect(await file.readAsBytes(), [73, 68, 51]);
    expect(adapter.options!.path, endsWith('/audio/speech'));
    expect(adapter.options!.headers['Authorization'], 'Bearer test-key');
    expect(adapter.options!.data, {
      'model': 'tts-1',
      'input': '测试语音',
      'voice': 'alloy',
    });
  });

  test('TTS Notifier 完成合成、播放和结束状态转换', () async {
    final directory =
        await Directory.systemTemp.createTemp('voxflow_tts_state_');
    addTearDown(() => directory.delete(recursive: true));
    final audioFile = File(
      '${directory.path}${Platform.pathSeparator}generated.mp3',
    );
    await audioFile.writeAsBytes([1, 2, 3]);
    final playback = _FakePlayback();
    addTearDown(playback.dispose);
    String? historyText;
    final notifier = TtsNotifier(
      apiService: _FakeTtsService(audioFile),
      playback: playback,
      historyWriter: ({required text, required audioPath}) async {
        historyText = text;
      },
      model: 'tts-1',
    );
    addTearDown(notifier.dispose);

    await notifier.synthesize('需要播放的内容');
    expect(notifier.state.phase, TtsPhase.ready);
    expect(notifier.state.audioPath, audioFile.path);
    expect(historyText, '需要播放的内容');

    await notifier.playOrPause();
    expect(notifier.state.phase, TtsPhase.playing);
    expect(playback.playCalled, isTrue);

    playback.complete();
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.phase, TtsPhase.completed);
  });

  test('Seed TTS Notifier 默认使用模型专属 Speaker ID', () async {
    final directory =
        await Directory.systemTemp.createTemp('voxflow_seed_tts_state_');
    addTearDown(() => directory.delete(recursive: true));
    final audioFile = File(
      '${directory.path}${Platform.pathSeparator}generated.mp3',
    );
    await audioFile.writeAsBytes([1, 2, 3]);
    final playback = _FakePlayback();
    addTearDown(playback.dispose);
    final notifier = TtsNotifier(
      apiService: _FakeTtsService(audioFile),
      playback: playback,
      historyWriter: ({required text, required audioPath}) async {},
      model: AppConstants.seedTtsModel,
    );
    addTearDown(notifier.dispose);

    expect(notifier.state.voice, 'zh_female_cancan_uranus_bigtts');
    expect(notifier.availableVoices, [
      'zh_female_cancan_uranus_bigtts',
    ]);

    notifier.setVoice('alloy');
    expect(notifier.state.voice, 'zh_female_cancan_uranus_bigtts');
  });

  test('未知合成错误保留中英文 fallback', () async {
    final playback = _FakePlayback();
    addTearDown(playback.dispose);
    final notifier = TtsNotifier(
      apiService: _FailingTtsService(),
      playback: playback,
      historyWriter: ({required text, required audioPath}) async {},
      model: 'tts-1',
    );
    addTearDown(notifier.dispose);

    await notifier.synthesize('测试');

    expect(notifier.state.errorMessage, '语音合成失败，请稍后重试。');
    expect(
      notifier.state.errorMessageFor(const Locale('en')),
      'Speech synthesis failed. Try again later.',
    );
  });
}

class _BytesAdapter implements HttpClientAdapter {
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    await requestStream?.drain<void>();
    return ResponseBody.fromBytes(
      [73, 68, 51],
      200,
      headers: {
        Headers.contentTypeHeader: ['audio/mpeg'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeTtsService extends TtsApiService {
  _FakeTtsService(this.file) : super(DioClient(_settings));

  final File file;

  @override
  Future<File> synthesize(TtsRequest request) async => file;
}

class _FailingTtsService extends TtsApiService {
  _FailingTtsService() : super(DioClient(_settings));

  @override
  Future<File> synthesize(TtsRequest request) async {
    throw StateError('internal failure');
  }
}

class _FakePlayback implements PlaybackController {
  final _positions = StreamController<Duration>.broadcast();
  final _durations = StreamController<Duration>.broadcast();
  final _completions = StreamController<void>.broadcast();
  bool playCalled = false;

  @override
  Stream<void> get completions => _completions.stream;

  @override
  Stream<Duration> get durationChanges => _durations.stream;

  @override
  Stream<Duration> get positionChanges => _positions.stream;

  @override
  Future<void> load(String path) async {
    _durations.add(const Duration(seconds: 2));
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {
    playCalled = true;
  }

  @override
  Future<void> seek(Duration position) async {
    _positions.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}

  void complete() => _completions.add(null);

  Future<void> dispose() async {
    await _positions.close();
    await _durations.close();
    await _completions.close();
  }
}
