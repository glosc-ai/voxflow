import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/stt/models/stt_state.dart';
import 'package:voxflow/features/stt/models/transcription_result.dart';
import 'package:voxflow/features/stt/providers/stt_provider.dart';
import 'package:voxflow/features/stt/services/audio_record_manager.dart';
import 'package:voxflow/features/stt/services/transcription_service.dart';
import 'package:voxflow/features/stt/services/whisper_api_service.dart';

void main() {
  test('成功结果存在时不能直接开始新任务', () {
    const state = SttState(
      phase: SttPhase.success,
      result: TranscriptionResult(text: '已完成的转录', segments: []),
      editedText: '已编辑的转录',
    );

    expect(state.canStart, isFalse);
  });

  test('失败的临时录音在明确放弃前不能被新任务覆盖', () {
    const retainedRecording = SttState(
      phase: SttPhase.failure,
      selectedFilePath: 'temporary-recording.wav',
      selectedSourceIsTemporaryRecording: true,
    );
    const importedFile = SttState(
      phase: SttPhase.failure,
      selectedFilePath: 'user-import.wav',
    );

    expect(retainedRecording.hasRetainedTemporaryRecording, isTrue);
    expect(retainedRecording.canRetrySelectedSource, isTrue);
    expect(retainedRecording.canStart, isFalse);
    expect(importedFile.hasRetainedTemporaryRecording, isFalse);
    expect(importedFile.canStart, isTrue);
  });

  test('未知转录错误保留中英文 fallback', () async {
    final directory = await Directory.systemTemp.createTemp('voxflow_stt_');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}input.wav');
    await input.writeAsBytes([1, 2, 3]);
    final notifier = SttNotifier(
      recorder: _FakeRecorder(),
      apiService: _FailingWhisperService(),
      historyWriter:
          ({required type, required text, required audioPath}) async {},
    );
    addTearDown(notifier.dispose);

    await notifier.transcribeFile(input);

    expect(notifier.state.errorMessage, '音频转录失败，请稍后重试。');
    expect(
      notifier.state.errorMessageFor(const Locale('en')),
      'Audio transcription failed. Try again later.',
    );
  });

  test('录音计时使用注入时钟并排除暂停时长', () async {
    final recorder = _FakeRecorder();
    final clock = _FakeClock(DateTime.utc(2026, 7, 22));
    final notifier = SttNotifier(
      recorder: recorder,
      apiService: WhisperApiService(DioClient(const SettingsState())),
      historyWriter:
          ({required type, required text, required audioPath}) async {},
      nowUtc: clock.read,
    );
    addTearDown(notifier.dispose);

    await notifier.startRecording();
    expect(recorder.startCalls, 1);
    expect(notifier.state.phase, SttPhase.recording);

    clock.autoAdvance = false;
    clock.advance(const Duration(seconds: 2));
    await notifier.pauseRecording();
    expect(notifier.state.phase, SttPhase.paused);
    expect(notifier.state.elapsed, const Duration(seconds: 2));

    clock.advance(const Duration(seconds: 30));
    await notifier.resumeRecording();
    clock.advance(const Duration(seconds: 3));
    await notifier.pauseRecording();
    expect(notifier.state.elapsed, const Duration(seconds: 5));
  });

  test('录音转录失败保留临时源，重试成功后才删除', () async {
    final directory = await Directory.systemTemp.createTemp('voxflow_stt_');
    addTearDown(() => directory.delete(recursive: true));
    final recording = File(
      '${directory.path}${Platform.pathSeparator}recording.wav',
    );
    final managed = File(
      '${directory.path}${Platform.pathSeparator}managed.wav',
    );
    await recording.writeAsBytes([1, 2, 3]);
    final recorder = _FakeRecorder(stopFile: recording);
    final service = _FailOnceWhisperService();
    String? historyAudioPath;
    final notifier = SttNotifier(
      recorder: recorder,
      apiService: service,
      historyWriter:
          ({required type, required text, required audioPath}) async {
            historyAudioPath = audioPath;
          },
      nowUtc: _FakeClock(DateTime.utc(2026, 7, 22)).read,
      persistManagedAudio: (source, {required category}) =>
          source.copy(managed.path),
    );
    addTearDown(notifier.dispose);

    await notifier.startRecording();
    await notifier.stopRecording();

    expect(notifier.state.phase, SttPhase.failure);
    expect(notifier.state.selectedFilePath, recording.path);
    expect(notifier.state.selectedSourceIsTemporaryRecording, isTrue);
    expect(notifier.state.canRetrySelectedSource, isTrue);
    expect(await recording.exists(), isTrue);

    await notifier.retrySelectedSource();

    expect(service.calls, 2);
    expect(notifier.state.phase, SttPhase.success);
    expect(notifier.state.selectedFilePath, managed.path);
    expect(notifier.state.selectedSourceIsTemporaryRecording, isFalse);
    expect(historyAudioPath, managed.path);
    expect(await managed.exists(), isTrue);
    expect(await recording.exists(), isFalse);
  });

  test('新来源替换失败录音时清理临时源但保留用户文件', () async {
    final directory = await Directory.systemTemp.createTemp('voxflow_stt_');
    addTearDown(() => directory.delete(recursive: true));
    final recording = File(
      '${directory.path}${Platform.pathSeparator}recording.wav',
    );
    final imported = File(
      '${directory.path}${Platform.pathSeparator}imported.wav',
    );
    await recording.writeAsBytes([1, 2, 3]);
    await imported.writeAsBytes([4, 5, 6]);
    final notifier = SttNotifier(
      recorder: _FakeRecorder(stopFile: recording),
      apiService: _FailingWhisperService(),
      historyWriter:
          ({required type, required text, required audioPath}) async {},
      nowUtc: _FakeClock(DateTime.utc(2026, 7, 22)).read,
    );
    addTearDown(notifier.dispose);

    await notifier.startRecording();
    await notifier.stopRecording();
    expect(await recording.exists(), isTrue);

    await notifier.transcribeFile(imported);

    expect(await recording.exists(), isFalse);
    expect(await imported.exists(), isTrue);
    expect(notifier.state.selectedFilePath, imported.path);
    expect(notifier.state.selectedSourceIsTemporaryRecording, isFalse);

    await notifier.startRecording();

    expect(await imported.exists(), isTrue);
  });
}

class _FakeClock {
  _FakeClock(this.current);

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

class _FakeRecorder implements AudioRecordManager {
  _FakeRecorder({this.stopFile});

  final File? stopFile;
  int startCalls = 0;

  @override
  Future<void> start() async {
    startCalls++;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<File> stop() async => stopFile ?? File('unused');

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

class _FailingWhisperService extends WhisperApiService {
  _FailingWhisperService() : super(DioClient(const SettingsState()));

  @override
  Future<TranscriptionResult> transcribe(
    File file, {
    UploadProgressCallback? onUploadProgress,
    SettingsState? requestSettings,
  }) async {
    throw StateError('internal failure');
  }
}

class _FailOnceWhisperService extends WhisperApiService {
  _FailOnceWhisperService() : super(DioClient(const SettingsState()));

  int calls = 0;

  @override
  Future<TranscriptionResult> transcribe(
    File file, {
    UploadProgressCallback? onUploadProgress,
    SettingsState? requestSettings,
  }) async {
    calls++;
    if (calls == 1) {
      throw StateError('temporary failure');
    }
    onUploadProgress?.call(1);
    return const TranscriptionResult(text: '重试成功', segments: []);
  }
}
