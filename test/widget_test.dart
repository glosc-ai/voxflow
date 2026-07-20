import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/app.dart';
import 'package:voxflow/features/history/models/history_record.dart';
import 'package:voxflow/features/history/providers/history_provider.dart';
import 'package:voxflow/features/history/services/history_repository.dart';
import 'package:voxflow/features/history/views/history_screen.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/tts/providers/tts_provider.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';

void main() {
  testWidgets('移动端使用底部导航', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        child: const VoxFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('桌面端使用侧边导航', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        child: const VoxFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  testWidgets('历史记录可搜索并确认删除', (tester) async {
    final repository = _MemoryHistoryRepository();
    repository.records.add(
      HistoryRecord(
        id: 1,
        type: HistoryType.stt,
        text: '需要查找的转录',
        audioPath: 'external.wav',
        createdAt: DateTime.utc(2026, 7, 20),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(repository),
          historyPlaybackManagerProvider.overrideWithValue(
            const _SilentPlaybackController(),
          ),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('需要查找的转录'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('historySearchField')), '不存在');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('暂无历史记录'), findsOneWidget);

    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(repository.records, isEmpty);
    expect(find.text('暂无历史记录'), findsOneWidget);
  });
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

class _MemoryHistoryRepository extends HistoryRepository {
  final records = <HistoryRecord>[];

  @override
  Future<void> close() async {}

  @override
  Future<void> delete(int id) async {
    records.removeWhere((record) => record.id == id);
  }

  @override
  Future<HistoryRecord> insert(HistoryRecord record) async {
    final inserted = HistoryRecord(
      id: records.length + 1,
      type: record.type,
      text: record.text,
      audioPath: record.audioPath,
      createdAt: record.createdAt,
    );
    records.add(inserted);
    return inserted;
  }

  @override
  Future<List<HistoryRecord>> search([String query = '']) async {
    return records
        .where((record) => record.text.contains(query))
        .toList(growable: false);
  }
}
