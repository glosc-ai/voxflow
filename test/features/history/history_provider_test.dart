import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/features/history/models/history_record.dart';
import 'package:voxflow/features/history/providers/history_provider.dart';
import 'package:voxflow/features/history/services/history_repository.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';

void main() {
  test('reset reload wins over an older in-flight history search', () async {
    final repository = _ControlledHistoryRepository();
    final notifier = HistoryNotifier(repository);
    addTearDown(notifier.dispose);

    final olderLoad = notifier.load(query: 'before reset');
    final resetLoad = notifier.reloadAfterDataReset();

    repository.requests[1].complete(const []);
    await resetLoad;
    repository.requests[0].complete([
      HistoryRecord(
        id: 1,
        type: HistoryType.stt,
        text: 'stale result',
        audioPath: 'managed.wav',
        createdAt: DateTime.utc(2026, 8, 5),
      ),
    ]);
    await olderLoad;

    expect(repository.queries, ['before reset', '']);
    expect(notifier.state.valueOrNull, isEmpty);
  });

  test(
    'reset reload failure does not expose records cached before reset',
    () async {
      final repository = _ControlledHistoryRepository();
      final notifier = HistoryNotifier(repository);
      addTearDown(notifier.dispose);
      final cachedRecord = HistoryRecord(
        id: 1,
        type: HistoryType.stt,
        text: 'sensitive cached result',
        audioPath: 'managed.wav',
        createdAt: DateTime.utc(2026, 8, 5),
      );

      final initialLoad = notifier.load();
      repository.requests.single.complete([cachedRecord]);
      await initialLoad;
      expect(notifier.state.valueOrNull, [cachedRecord]);

      final resetLoad = notifier.reloadAfterDataReset();
      repository.requests.last.completeError(
        StateError('database unavailable'),
      );
      await resetLoad;

      expect(notifier.state.hasError, isTrue);
      expect(notifier.state.hasValue, isFalse);
      expect(notifier.state.valueOrNull, isNull);
    },
  );

  test('stop invalidates an older delayed history playback command', () async {
    final playback = _DelayedPlaybackController();
    final notifier = HistoryPlaybackNotifier(playback);
    addTearDown(notifier.dispose);
    final record = HistoryRecord(
      id: 1,
      type: HistoryType.tts,
      text: 'audio',
      audioPath: 'managed.mp3',
      createdAt: DateTime.utc(2026, 8, 5),
    );

    final toggle = notifier.toggle(record);
    await playback.loadStarted.future;
    final stop = notifier.stop();
    playback.allowLoad.complete();
    await Future.wait([toggle, stop]);

    expect(playback.playCalls, 0);
    expect(playback.stopCalls, 1);
    expect(notifier.state.recordId, isNull);
    expect(notifier.state.isPlaying, isFalse);
  });
}

class _ControlledHistoryRepository extends HistoryRepository {
  final queries = <String>[];
  final requests = <Completer<List<HistoryRecord>>>[];

  @override
  Future<List<HistoryRecord>> search([String query = '']) {
    queries.add(query);
    final request = Completer<List<HistoryRecord>>();
    requests.add(request);
    return request.future;
  }
}

class _DelayedPlaybackController implements PlaybackController {
  final loadStarted = Completer<void>();
  final allowLoad = Completer<void>();
  int playCalls = 0;
  int stopCalls = 0;

  @override
  Stream<void> get completions => const Stream.empty();

  @override
  Stream<Duration> get durationChanges => const Stream.empty();

  @override
  Stream<Duration> get positionChanges => const Stream.empty();

  @override
  Future<void> load(String path) async {
    loadStarted.complete();
    await allowLoad.future;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {
    playCalls += 1;
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }
}
