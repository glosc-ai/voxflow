import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/theme/app_theme.dart';
import 'package:voxflow/features/history/models/history_record.dart';
import 'package:voxflow/features/history/providers/history_provider.dart';
import 'package:voxflow/features/history/services/history_repository.dart';
import 'package:voxflow/features/history/views/history_screen.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/stt/views/stt_screen.dart';
import 'package:voxflow/features/tts/providers/tts_provider.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';
import 'package:voxflow/features/tts/views/tts_screen.dart';
import 'package:voxflow/l10n/app_localizations.dart';

void main() {
  group('English pages at 360x640 and 200% text scale', () {
    testWidgets('speech-to-text page has no overflow', (tester) async {
      await _pumpLocalizedPage(
        tester,
        locale: AppLocalizations.englishLocale,
        page: const SttScreen(),
      );

      expect(find.text('Speech to text'), findsOneWidget);
      expect(find.text('Start recording'), findsOneWidget);
      expect(find.text('Choose file'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byKey(const Key('mobileSttScrollView')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('text-to-speech page has no overflow', (tester) async {
      await _pumpLocalizedPage(
        tester,
        locale: AppLocalizations.englishLocale,
        page: const TtsScreen(),
      );

      expect(find.text('Text to speech'), findsOneWidget);
      expect(find.text('Choose a voice'), findsOneWidget);
      expect(find.text('Generate speech'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byKey(const Key('mobileTtsWorkspace')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('history page renders its empty state without overflow',
        (tester) async {
      await _pumpLocalizedPage(
        tester,
        locale: AppLocalizations.englishLocale,
        page: const HistoryScreen(),
      );

      expect(find.text('History'), findsOneWidget);
      expect(find.text('Search history'), findsOneWidget);
      expect(find.text('LIBRARY · LOCAL ARCHIVE'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byTooltip('Refresh'), findsOneWidget);
      await tester.fling(
        find.byKey(const Key('mobileHistoryScrollView')),
        const Offset(0, -500),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('No history yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('zh-Hans locale renders Chinese page copy', (tester) async {
    await _pumpLocalizedPage(
      tester,
      locale: AppLocalizations.simplifiedChineseLocale,
      page: const SttScreen(),
      textScaleFactor: 1,
    );

    expect(
      Localizations.localeOf(tester.element(find.byType(SttScreen))),
      AppLocalizations.simplifiedChineseLocale,
    );
    expect(find.text('语音转文字'), findsOneWidget);
    expect(find.text('点按开始录音'), findsOneWidget);
    expect(find.text('自动识别'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLocalizedPage(
  WidgetTester tester, {
  required Locale locale,
  required Widget page,
  double textScaleFactor = 2,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();

  await tester.binding.setSurfaceSize(const Size(360, 640));
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        ttsPlaybackManagerProvider.overrideWithValue(
          const _SilentPlaybackController(),
        ),
        historyPlaybackManagerProvider.overrideWithValue(
          const _SilentPlaybackController(),
        ),
        historyRepositoryProvider.overrideWithValue(
          _MemoryHistoryRepository(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback:
            AppLocalizations.localeListResolutionCallback,
        localizationsDelegates: AppLocalizations.delegates,
        theme: AppTheme.light,
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
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
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}

class _MemoryHistoryRepository extends HistoryRepository {
  final List<HistoryRecord> _records = [];

  @override
  Future<void> close() async {}

  @override
  Future<void> delete(int id) async {
    _records.removeWhere((record) => record.id == id);
  }

  @override
  Future<HistoryRecord> insert(HistoryRecord record) async {
    final inserted = HistoryRecord(
      id: _records.length + 1,
      type: record.type,
      text: record.text,
      audioPath: record.audioPath,
      createdAt: record.createdAt,
    );
    _records.add(inserted);
    return inserted;
  }

  @override
  Future<List<HistoryRecord>> search([String query = '']) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return List.unmodifiable(_records);
    }
    return _records
        .where(
          (record) => record.text.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
  }
}
