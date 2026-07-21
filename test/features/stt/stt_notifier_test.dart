import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/stt/models/stt_state.dart';
import 'package:voxflow/features/stt/providers/stt_provider.dart';
import 'package:voxflow/features/stt/services/audio_record_manager.dart';
import 'package:voxflow/features/stt/services/whisper_api_service.dart';

void main() {
  test('录音计时使用注入时钟并排除暂停时长', () async {
    final recorder = _FakeRecorder();
    final clock = _FakeClock(DateTime.utc(2026, 7, 22));
    final notifier = SttNotifier(
      recorder: recorder,
      apiService: WhisperApiService(DioClient(const SettingsState())),
      historyWriter: (
          {required type, required text, required audioPath}) async {},
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
  Future<File> stop() async => File('unused');

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}
