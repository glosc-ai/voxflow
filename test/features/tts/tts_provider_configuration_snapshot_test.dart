import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/constants/app_constants.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/settings/services/settings_repository.dart';
import 'package:voxflow/features/tts/models/tts_state.dart';
import 'package:voxflow/features/tts/providers/tts_provider.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';
import 'package:voxflow/features/tts/services/tts_api_service.dart';

import '../../support/memory_api_key_store.dart';

void main() {
  test('TTS 固定当前生成配置且仅在下一次生成读取设置变更', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences, MemoryApiKeyStore());
    await repository.save(
      const SettingsState(
        apiKey: 'old-key',
        baseUrl: 'https://old.example/v1',
        ttsModel: 'tts-1',
      ),
    );

    final modelLoad = Completer<List<String>>();
    final settings = SettingsNotifier(
      repository,
      modelLoader: (_) => modelLoad.future,
    );
    final adapter = _ControllableSpeechAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final directory = await Directory.systemTemp.createTemp(
      'voxflow_tts_provider_snapshot_',
    );
    var outputIndex = 0;
    final service = TtsApiService(
      DioClient.withSettings(() => settings.state, dio: dio),
      writer: (bytes) async {
        final file = File(
          '${directory.path}${Platform.pathSeparator}'
          'generated_${++outputIndex}.mp3',
        );
        return file.writeAsBytes(bytes, flush: true);
      },
    );
    final playback = _ControllablePlayback();
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
        ttsApiServiceProvider.overrideWithValue(service),
        ttsPlaybackManagerProvider.overrideWithValue(playback),
        ttsHistoryWriterProvider.overrideWithValue(
          ({required text, required audioPath}) async {},
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await playback.dispose();
      await adapter.dispose();
      await directory.delete(recursive: true);
    });

    final notifier = container.read(ttsProvider.notifier)
      ..setVoice('nova')
      ..setSpeed(1.5);

    final firstRequestStarted = adapter.nextRequest;
    final firstSynthesis = notifier.synthesize('已有结果');
    await firstRequestStarted;
    adapter.completeNext();
    await firstSynthesis;
    await notifier.seek(const Duration(seconds: 3));
    final existingAudioPath = container.read(ttsProvider).audioPath;

    playback.delayNextStop();
    final secondRequestStarted = adapter.nextRequest;
    final secondSynthesis = notifier.synthesize('本次固定文本');
    await playback.stopStarted;
    final generatingBeforeSettingsChanges = container.read(ttsProvider);
    expect(generatingBeforeSettingsChanges.phase, TtsPhase.generating);
    expect(generatingBeforeSettingsChanges.audioPath, existingAudioPath);

    final transientSettingsChange = settings.fetchModels(
      apiKey: 'old-key',
      baseUrl: 'https://old.example/v1',
    );
    expect(settings.state.isBusy, isTrue);
    expect(container.read(ttsProvider).phase, TtsPhase.generating);
    expect(container.read(ttsProvider).audioPath, existingAudioPath);
    expect(
      container.read(ttsProvider).position,
      generatingBeforeSettingsChanges.position,
    );
    modelLoad.complete(['whisper-1', 'tts-1', 'gpt-4o-mini-tts']);
    await transientSettingsChange;

    await settings.save(
      apiKey: 'new-key',
      baseUrl: 'https://new.example/v1',
      sttModel: 'whisper-1',
      ttsModel: 'gpt-4o-mini-tts',
    );
    expect(container.read(ttsProvider).phase, TtsPhase.generating);
    expect(container.read(ttsProvider).audioPath, existingAudioPath);
    expect(
      container.read(ttsProvider).position,
      generatingBeforeSettingsChanges.position,
    );

    playback.releaseStop();
    final secondRequest = await secondRequestStarted;
    try {
      _expectSpeechRequest(
        secondRequest,
        uri: 'https://old.example/v1/audio/speech',
        apiKey: 'old-key',
        model: 'tts-1',
        voice: 'nova',
        text: '本次固定文本',
        speed: 1.5,
      );
    } finally {
      adapter.completeNext();
      await secondSynthesis;
    }

    expect(container.read(ttsProvider).phase, TtsPhase.ready);
    await notifier.seek(const Duration(seconds: 2));
    notifier
      ..setVoice('shimmer')
      ..setSpeed(0.75);

    final nextRequestStarted = adapter.nextRequest;
    final nextSynthesis = notifier.synthesize('下一次使用新配置');
    final nextRequest = await nextRequestStarted;
    try {
      _expectSpeechRequest(
        nextRequest,
        uri: 'https://new.example/v1/audio/speech',
        apiKey: 'new-key',
        model: 'gpt-4o-mini-tts',
        voice: 'shimmer',
        text: '下一次使用新配置',
        speed: 0.75,
      );
    } finally {
      adapter.completeNext();
      await nextSynthesis;
    }

    final failedRequestStarted = adapter.nextRequest;
    final failedSynthesis = notifier.synthesize('旧模型任务');
    final failedRequest = await failedRequestStarted;
    _expectSpeechRequest(
      failedRequest,
      uri: 'https://new.example/v1/audio/speech',
      apiKey: 'new-key',
      model: 'gpt-4o-mini-tts',
      voice: 'shimmer',
      text: '旧模型任务',
      speed: 0.75,
    );

    await settings.save(
      apiKey: 'new-key',
      baseUrl: 'https://new.example/v1',
      sttModel: 'whisper-1',
      ttsModel: AppConstants.seedTtsModel,
    );
    adapter.failNext();
    await failedSynthesis;

    expect(container.read(ttsProvider).phase, TtsPhase.failure);
    expect(
      AppConstants.ttsVoicesForModel(AppConstants.seedTtsModel),
      contains(container.read(ttsProvider).voice),
    );

    final seedRequestStarted = adapter.nextRequest;
    final seedSynthesis = notifier.synthesize('新模型任务');
    final seedRequest = await seedRequestStarted;
    expect(seedRequest.uri.toString(), 'https://new.example/v1/audio/speech');
    expect(seedRequest.headers['Authorization'], 'Bearer new-key');
    expect(seedRequest.data, {
      'model': AppConstants.seedTtsModel,
      'input': '新模型任务',
      'voice': AppConstants.defaultTtsVoiceForModel(AppConstants.seedTtsModel),
      'speed': 0.75,
    });
    adapter.completeNext();
    await seedSynthesis;

    expect(container.read(ttsProvider).phase, TtsPhase.ready);
  });
}

void _expectSpeechRequest(
  RequestOptions request, {
  required String uri,
  required String apiKey,
  required String model,
  required String voice,
  required String text,
  required double speed,
}) {
  expect(request.uri.toString(), uri);
  expect(request.headers['Authorization'], 'Bearer $apiKey');
  expect(request.data, {
    'model': model,
    'input': text,
    'voice': voice,
    'speed': speed,
  });
}

class _ControllableSpeechAdapter implements HttpClientAdapter {
  final _requests = StreamController<RequestOptions>.broadcast();
  final _responses = Queue<Completer<ResponseBody>>();

  Future<RequestOptions> get nextRequest => _requests.stream.first;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await requestStream?.drain<void>();
    final response = Completer<ResponseBody>();
    _responses.addLast(response);
    _requests.add(options);
    return response.future;
  }

  void completeNext() {
    _responses.removeFirst().complete(
      ResponseBody.fromBytes(
        [73, 68, 51],
        200,
        headers: {
          Headers.contentTypeHeader: ['audio/mpeg'],
        },
      ),
    );
  }

  void failNext() {
    _responses.removeFirst().complete(
      ResponseBody.fromString(
        'controlled failure',
        500,
        headers: {
          Headers.contentTypeHeader: ['text/plain'],
        },
      ),
    );
  }

  @override
  void close({bool force = false}) {}

  Future<void> dispose() async {
    for (final response in _responses) {
      if (!response.isCompleted) {
        response.completeError(StateError('test disposed'));
      }
    }
    await _requests.close();
  }
}

class _ControllablePlayback implements PlaybackController {
  final _positions = StreamController<Duration>.broadcast();
  final _durations = StreamController<Duration>.broadcast();
  final _completions = StreamController<void>.broadcast();
  Completer<void>? _stopStarted;
  Completer<void>? _allowStop;

  Future<void> get stopStarted => _stopStarted!.future;

  void delayNextStop() {
    _stopStarted = Completer<void>();
    _allowStop = Completer<void>();
  }

  void releaseStop() => _allowStop!.complete();

  @override
  Stream<void> get completions => _completions.stream;

  @override
  Stream<Duration> get durationChanges => _durations.stream;

  @override
  Stream<Duration> get positionChanges => _positions.stream;

  @override
  Future<void> load(String path) async {
    _durations.add(const Duration(seconds: 10));
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {
    _positions.add(position);
  }

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {
    final started = _stopStarted;
    final allow = _allowStop;
    if (started == null || allow == null) {
      return;
    }
    started.complete();
    await allow.future;
    if (identical(_stopStarted, started)) {
      _stopStarted = null;
      _allowStop = null;
    }
  }

  Future<void> dispose() async {
    await _positions.close();
    await _durations.close();
    await _completions.close();
  }
}
