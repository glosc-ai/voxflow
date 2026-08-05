import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/settings/services/settings_repository.dart';
import 'package:voxflow/features/stt/models/stt_state.dart';
import 'package:voxflow/features/stt/providers/stt_provider.dart';
import 'package:voxflow/features/stt/services/audio_record_manager.dart';

import '../../support/memory_api_key_store.dart';

void main() {
  test('录音任务固定启动配置且下一任务读取新设置', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences, MemoryApiKeyStore());
    await repository.save(
      const SettingsState(
        apiKey: 'old-key',
        baseUrl: 'https://old.example/v1',
        sttModel: 'whisper-1',
        ttsModel: 'tts-1',
      ),
    );
    final modelLoad = Completer<List<String>>();
    final settings = SettingsNotifier(
      repository,
      modelLoader: (_) => modelLoad.future,
    );
    final directory = await Directory.systemTemp.createTemp(
      'voxflow_stt_runtime_configuration_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final recordings = [
      File('${directory.path}${Platform.pathSeparator}first.wav'),
    ];
    for (final recording in recordings) {
      await recording.writeAsBytes([1, 2, 3]);
    }
    final recorder = _ControlledRecorder(recordings);
    final clock = _ControlledClock(DateTime.utc(2026, 8, 6));
    final adapter = _CapturingFailureAdapter();
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
        dioClientProvider.overrideWith((ref) {
          final dio = Dio()..httpClientAdapter = adapter;
          return DioClient.withSettings(
            () => ref.read(settingsProvider),
            dio: dio,
          );
        }),
        audioRecordManagerProvider.overrideWithValue(recorder),
        sttUtcNowProvider.overrideWithValue(clock.read),
        historyWriterProvider.overrideWithValue(
          ({required type, required text, required audioPath}) async {},
        ),
      ],
    );
    addTearDown(container.dispose);
    final stt = container.read(sttProvider.notifier);

    await stt.startRecording();
    clock.autoAdvance = false;
    clock.advance(const Duration(seconds: 2));
    await stt.pauseRecording();
    await stt.resumeRecording();
    expect(container.read(sttProvider).phase, SttPhase.recording);
    expect(container.read(sttProvider).elapsed, const Duration(seconds: 2));
    expect(recorder.startCalls, 1);
    expect(recorder.cancelCalls, 0);
    expect(recorder.disposeCalls, 0);

    final fetchModels = settings.fetchModels(
      apiKey: 'old-key',
      baseUrl: 'https://old.example/v1',
    );
    expect(settings.state.isBusy, isTrue);
    expect(container.read(sttProvider).phase, SttPhase.recording);
    expect(container.read(sttProvider).elapsed, const Duration(seconds: 2));
    expect(recorder.startCalls, 1);
    expect(recorder.cancelCalls, 0);
    expect(recorder.disposeCalls, 0);

    modelLoad.complete(['whisper-1', 'gpt-4o-transcribe', 'tts-1']);
    final catalog = await fetchModels;
    expect(catalog.stt, ['gpt-4o-transcribe', 'whisper-1']);
    expect(catalog.tts, ['tts-1']);
    expect(settings.state.message, '已获取 2 个语音转文字模型、1 个文字转语音模型；选择后请保存设置。');
    expect(container.read(sttProvider).phase, SttPhase.recording);
    expect(container.read(sttProvider).elapsed, const Duration(seconds: 2));
    expect(recorder.startCalls, 1);
    expect(recorder.cancelCalls, 0);
    expect(recorder.disposeCalls, 0);

    await container
        .read(settingsProvider.notifier)
        .save(
          apiKey: 'new-key',
          baseUrl: 'https://new.example/v1',
          sttModel: 'gpt-4o-transcribe',
          ttsModel: 'tts-1',
        );

    expect(container.read(sttProvider).phase, SttPhase.recording);
    expect(container.read(sttProvider).elapsed, const Duration(seconds: 2));
    clock.advance(const Duration(seconds: 3));
    await stt.stopRecording();

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.first.host, 'old.example');
    expect(adapter.requests.first.authorization, 'Bearer old-key');
    expect(adapter.requests.first.model, 'whisper-1');

    await stt.retrySelectedSource();

    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.last.host, 'new.example');
    expect(adapter.requests.last.authorization, 'Bearer new-key');
    expect(adapter.requests.last.model, 'gpt-4o-transcribe');
  });
}

class _ControlledClock {
  _ControlledClock(this.current);

  DateTime current;
  bool autoAdvance = true;

  Future<DateTime> read() async {
    if (autoAdvance) {
      current = current.add(const Duration(seconds: 1));
    }
    return current;
  }

  void advance(Duration duration) {
    current = current.add(duration);
  }
}

class _ControlledRecorder implements AudioRecordManager {
  _ControlledRecorder(this.recordings);

  final List<File> recordings;
  int startCalls = 0;
  int cancelCalls = 0;
  int disposeCalls = 0;
  int _stopIndex = 0;

  @override
  Future<void> start() async {
    startCalls++;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<File> stop() async => recordings[_stopIndex++];

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.host,
    required this.authorization,
    required this.model,
  });

  final String host;
  final String? authorization;
  final String? model;
}

class _CapturingFailureAdapter implements HttpClientAdapter {
  final requests = <_CapturedRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final form = options.data as FormData;
    final fields = Map<String, String>.fromEntries(form.fields);
    requests.add(
      _CapturedRequest(
        host: options.uri.host,
        authorization: options.headers['Authorization'] as String?,
        model: fields['model'],
      ),
    );
    await requestStream?.drain<void>();
    return ResponseBody.fromString(
      'controlled transcription failure',
      503,
      headers: {
        Headers.contentTypeHeader: ['text/plain'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
