import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/features/history/models/history_record.dart';
import 'package:voxflow/features/history/providers/history_provider.dart';
import 'package:voxflow/features/history/services/history_repository.dart';
import 'package:voxflow/features/history/views/history_screen.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';
import 'package:voxflow/l10n/app_localizations.dart';

void main() {
  test('refresh and search failures retain cached records and retry query',
      () async {
    final record = _record(text: 'cached transcript');
    final repository = _ControllableHistoryRepository(records: [record]);
    final notifier = HistoryNotifier(repository);
    addTearDown(notifier.dispose);

    await notifier.load();
    expect(notifier.state.valueOrNull, [record]);

    repository.failure = StateError('database unavailable');
    await notifier.load();
    expect(notifier.state.hasError, isTrue);
    expect(notifier.state.hasValue, isTrue);
    expect(notifier.state.valueOrNull, [record]);

    await notifier.load(query: 'cached');
    expect(repository.lastQuery, 'cached');
    expect(notifier.state.hasError, isTrue);
    expect(notifier.state.valueOrNull, [record]);

    repository.failure = null;
    await notifier.load();
    expect(repository.lastQuery, 'cached');
    expect(notifier.state.hasError, isFalse);
    expect(notifier.state.valueOrNull, [record]);
  });

  test('first load failure without cache remains a full error', () async {
    final repository = _ControllableHistoryRepository(
      failure: StateError('database unavailable'),
    );
    final notifier = HistoryNotifier(repository);
    addTearDown(notifier.dispose);

    await notifier.load();

    expect(notifier.state.hasError, isTrue);
    expect(notifier.state.hasValue, isFalse);
    expect(notifier.state.valueOrNull, isNull);
  });

  testWidgets('cached refresh failure is non-blocking and can be retried',
      (tester) async {
    final record = _record(text: 'cached transcript');
    final repository = _ControllableHistoryRepository(records: [record]);
    final notifier = HistoryNotifier(repository);
    await notifier.load();
    repository.failure = StateError('database unavailable');
    await notifier.load();

    await _pumpHistory(tester, notifier);

    expect(find.text('cached transcript'), findsOneWidget);
    expect(find.byKey(const Key('historyRefreshErrorMessage')), findsOneWidget);
    expect(find.byKey(const Key('historyFullErrorState')), findsNothing);

    repository.failure = null;
    await tester.tap(find.byKey(const Key('historyRefreshRetryButton')));
    await tester.pumpAndSettle();

    expect(find.text('cached transcript'), findsOneWidget);
    expect(find.byKey(const Key('historyRefreshErrorMessage')), findsNothing);
    expect(find.byKey(const Key('historyFullErrorState')), findsNothing);
  });

  testWidgets('first load failure renders the full error state',
      (tester) async {
    final repository = _ControllableHistoryRepository(
      failure: StateError('database unavailable'),
    );
    final notifier = HistoryNotifier(repository);
    await notifier.load();

    await _pumpHistory(tester, notifier);

    expect(find.byKey(const Key('historyFullErrorState')), findsOneWidget);
    expect(find.byKey(const Key('historyRefreshErrorMessage')), findsNothing);
  });

  testWidgets('history date follows the en-GB regional order', (tester) async {
    final repository = _ControllableHistoryRepository(
      records: [
        _record(
          text: 'regional date',
          createdAt: DateTime(2026, 1, 31, 9, 5),
        ),
      ],
    );
    final notifier = HistoryNotifier(repository);
    await notifier.load();

    await _pumpHistory(
      tester,
      notifier,
      locale: const Locale('en', 'GB'),
      supportedLocales: const [Locale('en', 'GB')],
    );

    expect(find.textContaining('31/01/2026'), findsOneWidget);
    expect(find.textContaining('1/31/2026'), findsNothing);
  });
}

Future<void> _pumpHistory(
  WidgetTester tester,
  HistoryNotifier notifier, {
  Locale locale = const Locale('zh', 'Hans'),
  List<Locale> supportedLocales = AppLocalizations.supportedLocales,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        historyProvider.overrideWith((ref) => notifier),
        historyPlaybackManagerProvider.overrideWithValue(
          const _SilentPlaybackController(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: supportedLocales,
        localizationsDelegates: AppLocalizations.delegates,
        home: const HistoryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

HistoryRecord _record({
  required String text,
  DateTime? createdAt,
}) {
  return HistoryRecord(
    id: 1,
    type: HistoryType.stt,
    text: text,
    audioPath: 'cached.wav',
    createdAt: createdAt ?? DateTime(2026, 1, 1, 9),
  );
}

class _ControllableHistoryRepository extends HistoryRepository {
  _ControllableHistoryRepository({
    this.records = const [],
    this.failure,
  });

  List<HistoryRecord> records;
  Object? failure;
  String? lastQuery;

  @override
  Future<List<HistoryRecord>> search([String query = '']) async {
    lastQuery = query;
    final currentFailure = failure;
    if (currentFailure != null) {
      throw currentFailure;
    }
    return List.unmodifiable(records);
  }

  @override
  Future<void> close() async {}
}

class _SilentPlaybackController implements PlaybackController {
  const _SilentPlaybackController();

  @override
  Stream<void> get completions => const Stream.empty();

  @override
  Stream<Duration> get durationChanges => const Stream.empty();

  @override
  Stream<Duration> get positionChanges => const Stream.empty();

  @override
  Future<void> load(String path) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}
