import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/core/theme/app_theme.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/tts/providers/tts_provider.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';
import 'package:voxflow/features/tts/services/tts_api_service.dart';
import 'package:voxflow/features/tts/views/tts_screen.dart';
import 'package:voxflow/l10n/app_localizations.dart';

void main() {
  testWidgets('Windows TTS voice row scrolls with a horizontal mouse drag', (
    tester,
  ) async {
    final voiceRow = await _pumpDesktopTtsScreen(tester);

    expect(voiceRow.position.maxScrollExtent, greaterThan(0));
    expect(voiceRow.position.pixels, 0);

    final gesture = await tester.startGesture(
      tester.getCenter(voiceRow.finder),
      kind: PointerDeviceKind.mouse,
    );
    for (var step = 0; step < 6; step++) {
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      voiceRow.position.pixels,
      greaterThan(0),
      reason: 'The overflowing voice row must respond to a Windows mouse drag.',
    );

    await tester.tap(find.text('Echo'));
    await tester.pumpAndSettle();
    expect(voiceRow.notifier.state.voice, 'echo');
  });

  testWidgets('Windows TTS voice row retains horizontal touch dragging', (
    tester,
  ) async {
    final voiceRow = await _pumpDesktopTtsScreen(tester);

    expect(voiceRow.position.maxScrollExtent, greaterThan(0));
    expect(voiceRow.position.pixels, 0);

    final gesture = await tester.startGesture(
      tester.getCenter(voiceRow.finder),
      kind: PointerDeviceKind.touch,
    );
    for (var step = 0; step < 6; step++) {
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(voiceRow.position.pixels, greaterThan(0));
  });

  testWidgets('selecting a voice preserves the horizontal scroll offset', (
    tester,
  ) async {
    final voiceRow = await _pumpDesktopTtsScreen(tester);

    expect(voiceRow.position.maxScrollExtent, greaterThan(0));
    voiceRow.position.jumpTo(voiceRow.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final offsetBeforeSelection = voiceRow.position.pixels;
    expect(offsetBeforeSelection, greaterThan(0));

    await tester.tap(find.text('Shimmer'));
    await tester.pumpAndSettle();

    final positionAfterSelection = _horizontalScrollablePosition(tester);
    expect(voiceRow.notifier.state.voice, 'shimmer');
    expect(
      positionAfterSelection.pixels,
      closeTo(offsetBeforeSelection, 1),
      reason: 'Selecting a card must not rebuild the list at offset zero.',
    );
  });

}

Future<_VoiceRowHarness> _pumpDesktopTtsScreen(
  WidgetTester tester, {
  String model = 'tts-1',
}) {
  return _pumpTtsScreen(
    tester,
    size: const Size(1200, 800),
    model: model,
    platform: TargetPlatform.windows,
  );
}

Future<_VoiceRowHarness> _pumpTtsScreen(
  WidgetTester tester, {
  required Size size,
  required String model,
  required TargetPlatform platform,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final notifier = _TestTtsNotifier(model: model);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        ttsProvider.overrideWith((ref) => notifier),
      ],
      child: MaterialApp(
        locale: AppLocalizations.englishLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.delegates,
        theme: AppTheme.light.copyWith(platform: platform),
        home: const TtsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final scrollableFinder = _horizontalScrollableFinder(tester);
  final scrollable = tester.state<ScrollableState>(scrollableFinder);
  return _VoiceRowHarness(
    finder: scrollableFinder,
    position: scrollable.position,
    notifier: notifier,
  );
}

class _VoiceRowHarness {
  const _VoiceRowHarness({
    required this.finder,
    required this.position,
    required this.notifier,
  });

  final Finder finder;
  final ScrollPosition position;
  final _TestTtsNotifier notifier;
}

class _TestTtsNotifier extends TtsNotifier {
  _TestTtsNotifier({required super.model})
    : super(
        apiService: TtsApiService(DioClient(const SettingsState())),
        playback: const _SilentPlaybackController(),
        historyWriter: ({required text, required audioPath}) async {},
      );
}

Finder _horizontalScrollableFinder(
  WidgetTester tester, {
  bool requireOverflow = false,
}) {
  final candidates = find
      .byType(Scrollable)
      .evaluate()
      .where((element) {
        final scrollable = element.widget as Scrollable;
        return scrollable.axisDirection == AxisDirection.right ||
            scrollable.axisDirection == AxisDirection.left;
      })
      .where((element) {
        if (!requireOverflow) {
          return true;
        }
        final state = (element as StatefulElement).state as ScrollableState;
        return state.position.hasContentDimensions &&
            state.position.maxScrollExtent > 0;
      })
      .toList();
  expect(candidates, hasLength(1));
  return find.byWidget(candidates.single.widget);
}

class _SilentPlaybackController implements PlaybackController {
  const _SilentPlaybackController();

  @override
  Stream<void> get completions => const Stream.empty();

ScrollPosition _horizontalScrollablePosition(WidgetTester tester) {
  return tester
      .state<ScrollableState>(
        _horizontalScrollableFinder(tester, requireOverflow: true),
      )
      .position;
}

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
