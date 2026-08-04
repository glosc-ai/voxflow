import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/core/theme/app_colors.dart';
import 'package:voxflow/core/theme/app_theme.dart';
import 'package:voxflow/features/history/models/history_record.dart';
import 'package:voxflow/features/history/providers/history_provider.dart';
import 'package:voxflow/features/history/services/history_repository.dart';
import 'package:voxflow/features/history/views/history_screen.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';
import 'package:voxflow/l10n/app_localizations.dart';
import 'package:voxflow/widgets/mobile_design.dart';

void main() {
  testWidgets('Android 历史页使用移动交付结构并可按类型筛选', (tester) async {
    final repository = _MemoryHistoryRepository([
      HistoryRecord(
        id: 1,
        type: HistoryType.stt,
        text: '产品周会纪要\n本周重点是优化移动端转写体验。',
        audioPath: 'meeting.wav',
        createdAt: DateTime.utc(2026, 8, 2, 14, 30),
      ),
      HistoryRecord(
        id: 2,
        type: HistoryType.tts,
        text: '视频开场旁白',
        audioPath: 'intro.mp3',
        createdAt: DateTime.utc(2026, 8, 2, 11, 5),
      ),
    ]);
    await _pumpHistory(tester, repository: repository);

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('LIBRARY · 本地存档'), findsOneWidget);
    expect(find.text('历史记录'), findsOneWidget);
    expect(find.byKey(const Key('historySearchField')), findsOneWidget);
    expect(find.byKey(const Key('historyFilterAll')), findsOneWidget);
    expect(find.byKey(const Key('historyFilterStt')), findsOneWidget);
    expect(find.byKey(const Key('historyFilterTts')), findsOneWidget);
    expect(find.text('产品周会纪要'), findsOneWidget);
    expect(find.text('本周重点是优化移动端转写体验。'), findsOneWidget);
    expect(find.text('视频开场旁白'), findsOneWidget);
    expect(find.text('whisper-1'), findsNothing);

    final hiddenActions = tester.widget<IgnorePointer>(
      find.byKey(const ValueKey('mobileHistoryActions:1')),
    );
    expect(hiddenActions.ignoring, isTrue);

    await tester.tap(find.byKey(const ValueKey('mobileHistoryCard:1')));
    await tester.pumpAndSettle();

    final shownActions = tester.widget<IgnorePointer>(
      find.byKey(const ValueKey('mobileHistoryActions:1')),
    );
    expect(shownActions.ignoring, isFalse);
    final actionButtons = find.descendant(
      of: find.byKey(const ValueKey('mobileHistoryActions:1')),
      matching: find.byType(IconButton),
    );
    expect(actionButtons, findsNWidgets(3));
    for (final element in actionButtons.evaluate()) {
      expect(tester.getSize(find.byElementPredicate((e) => e == element)),
          const Size.square(48));
    }

    await tester.tap(find.byKey(const Key('historyFilterTts')));
    await tester.pumpAndSettle();
    expect(find.text('产品周会纪要'), findsNothing);
    expect(find.text('视频开场旁白'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('historyFilterTts'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android 历史页在 360x640 与 200% 英文字体下无溢出', (tester) async {
    final repository = _MemoryHistoryRepository([
      HistoryRecord(
        id: 7,
        type: HistoryType.stt,
        text:
            'Interview notes\nA longer transcript excerpt remains readable at large text sizes.',
        audioPath: 'interview.wav',
        createdAt: DateTime.utc(2026, 8, 1, 16, 42),
      ),
    ]);
    await _pumpHistory(
      tester,
      repository: repository,
      locale: AppLocalizations.englishLocale,
      size: const Size(360, 640),
      textScaleFactor: 2,
    );

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('LIBRARY · LOCAL ARCHIVE'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Search history'), findsOneWidget);
    expect(find.text('STT transcripts'), findsOneWidget);
    expect(find.text('TTS speech'), findsOneWidget);
    await tester.fling(
      find.byKey(const Key('mobileHistoryScrollView')),
      const Offset(0, -500),
      1000,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mobileHistoryActions:7')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android Tab focus gives history filters and cards a 2px ring',
      (tester) async {
    final repository = _MemoryHistoryRepository([
      HistoryRecord(
        id: 11,
        type: HistoryType.stt,
        text: '键盘焦点测试',
        audioPath: 'focus.wav',
        createdAt: DateTime.utc(2026, 8, 4, 10),
      ),
    ]);
    await _pumpHistory(tester, repository: repository);

    final filter = find.byKey(const Key('historyFilterAll'));
    await _tabUntilFocused(tester, filter);
    final focusColor = tester.element(filter).semanticColors.focus;
    final filterContainer = tester.widget<AnimatedContainer>(
      find.descendant(
        of: filter,
        matching: find.byType(AnimatedContainer),
      ),
    );
    final filterBorder =
        (filterContainer.decoration! as BoxDecoration).border! as Border;
    expect(filterBorder.top.color, focusColor);
    expect(filterBorder.top.width, 2);
    expect(tester.getSize(filter).height, greaterThanOrEqualTo(48));

    final card = find.byKey(const ValueKey('mobileHistoryCard:11'));
    await _tabUntilFocused(tester, card);
    final surface = tester.widget<MobileSurfaceCard>(
      find.descendant(of: card, matching: find.byType(MobileSurfaceCard)),
    );
    expect(surface.borderColor, focusColor);
    expect(surface.borderWidth, 2);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHistory(
  WidgetTester tester, {
  required _MemoryHistoryRepository repository,
  Locale locale = AppLocalizations.simplifiedChineseLocale,
  Size size = const Size(412, 892),
  double textScaleFactor = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  final notifier = HistoryNotifier(repository);
  await notifier.load();

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
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.delegates,
        theme: AppTheme.lightFor(TargetPlatform.android),
        home: const HistoryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tabUntilFocused(
  WidgetTester tester,
  Finder target, {
  int maxTabs = 20,
}) async {
  for (var index = 0; index < maxTabs; index++) {
    if (_primaryFocusIsWithin(target)) {
      return;
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  throw TestFailure('Tab focus did not reach $target.');
}

bool _primaryFocusIsWithin(Finder target) {
  final targetElements = target.evaluate().toList(growable: false);
  if (targetElements.length != 1) {
    return false;
  }
  final targetElement = targetElements.single;
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext == null) {
    return false;
  }
  if (identical(focusContext, targetElement)) {
    return true;
  }
  var within = false;
  focusContext.visitAncestorElements((element) {
    if (identical(element, targetElement)) {
      within = true;
      return false;
    }
    return true;
  });
  return within;
}

class _MemoryHistoryRepository extends HistoryRepository {
  _MemoryHistoryRepository(this.records);

  final List<HistoryRecord> records;

  @override
  Future<List<HistoryRecord>> search([String query = '']) async {
    final normalized = query.trim().toLowerCase();
    return records
        .where(
          (record) =>
              normalized.isEmpty ||
              record.text.toLowerCase().contains(normalized),
        )
        .toList(growable: false);
  }

  @override
  Future<void> delete(int id) async {
    records.removeWhere((record) => record.id == id);
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
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}
