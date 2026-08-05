import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/core/constants/app_constants.dart';
import 'package:voxflow/core/constants/volcengine_tts_voice_catalog.dart';
import 'package:voxflow/core/errors/app_exception.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/tts/models/tts_request.dart';
import 'package:voxflow/features/tts/providers/tts_provider.dart';
import 'package:voxflow/features/tts/services/audio_playback_manager.dart';
import 'package:voxflow/features/tts/services/tts_api_service.dart';

const _representativeVolcengineSpeakerId = 'zh_female_vv_uranus_bigtts';
const _lastVolcengineSpeakerId = 'zh_female_shaoergushi_uranus_bigtts';

void main() {
  group('ByteDance TTS voice catalog', () {
    test('normalized Seed-TTS 2.0 model IDs use Volcengine speaker IDs', () {
      for (final model in const [
        'bytedance/seed-tts-2.0',
        ' BYTEDANCE/seed-tts-2.0 ',
      ]) {
        final voices = AppConstants.ttsVoicesForModel(model);

        expect(
          voices,
          contains(_representativeVolcengineSpeakerId),
          reason: '$model should use the Volcengine speaker catalog.',
        );
        expect(voices, isNot(contains('alloy')));
      }
    });

    test('other provider resources do not reuse the Seed-TTS 2.0 catalog', () {
      for (final model in const [
        'notbytedance/seed-tts-2.0',
        'bytedancex/seed-tts-2.0',
        'bytedance',
        'bytedance/a-future-tts-model',
        'bytedance/seed-icl-2.0',
        'bytedance/seed-tts-1.0',
      ]) {
        expect(
          AppConstants.ttsVoicesForModel(model),
          AppConstants.voices,
          reason: '$model must not reuse the Seed-TTS 2.0 voice catalog.',
        );
      }
    });

    test('the embedded standard catalog is complete and duplicate-free', () {
      expect(VolcengineTtsVoiceCatalog.voices, hasLength(93));
      expect(AppConstants.bytedanceTtsVoices, hasLength(93));
      expect(AppConstants.bytedanceTtsVoices.toSet(), hasLength(93));
      expect(
        AppConstants.bytedanceTtsVoices,
        everyElement(endsWith('_uranus_bigtts')),
      );
      expect(
        AppConstants.bytedanceTtsVoices.first,
        'zh_female_cancan_uranus_bigtts',
      );
      expect(AppConstants.bytedanceTtsVoices.last, _lastVolcengineSpeakerId);
      expect(
        AppConstants.bytedanceTtsVoices,
        VolcengineTtsVoiceCatalog.voices
            .map((voice) => voice.speakerId)
            .toList(),
        reason: 'Request IDs must be derived from the typed catalog.',
      );
    });

    test('typed metadata exactly matches the researched official snapshot', () {
      final source =
          jsonDecode(
                File(
                  'docs/research/volcengine-seed-tts-2.0-voices.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final sourceVoices = source['voices'] as List<dynamic>;
      final sourceBySpeakerId = <String, Map<String, dynamic>>{
        for (final entry in sourceVoices.cast<Map<String, dynamic>>())
          entry['speakerId'] as String: entry,
      };

      expect(sourceBySpeakerId, hasLength(93));
      for (final voice in VolcengineTtsVoiceCatalog.voices) {
        final official = sourceBySpeakerId[voice.speakerId];
        expect(official, isNotNull, reason: voice.speakerId);
        expect(voice.displayName, official!['displayName']);
        expect(voice.language, official['language']);
        expect(voice.scenario, official['scenario']);
      }

      final productDefault = VolcengineTtsVoiceCatalog.voices.first;
      expect(
        productDefault.speakerId,
        VolcengineTtsVoiceCatalog.productDefaultSpeakerId,
      );
      expect(source['productDefaultSpeakerId'], productDefault.speakerId);
      expect(
        source['officialExampleSpeakerId'],
        _representativeVolcengineSpeakerId,
      );
      expect(productDefault.displayName, '知性灿灿 2.0');
      expect(productDefault.language, '中文');
      expect(productDefault.scenario, '角色扮演');
    });
  });

  group('TtsNotifier model changes', () {
    test('switching providers falls back to a compatible default voice', () {
      final notifier = _createNotifier(model: 'tts-1');
      addTearDown(notifier.dispose);

      notifier.setVoice('nova');
      expect(notifier.state.voice, 'nova');

      notifier.updateModel('bytedance/seed-tts-2.0');
      expect(
        notifier.state.voice,
        AppConstants.defaultTtsVoiceForModel('bytedance/seed-tts-2.0'),
      );
      expect(notifier.availableVoices, isNot(contains('nova')));

      notifier.updateModel('tts-1');
      expect(notifier.state.voice, 'alloy');
      expect(notifier.availableVoices, AppConstants.voices);
    });

    test(
      'normalizing the Seed-TTS model preserves a compatible speaker ID',
      () {
        final notifier = _createNotifier(model: 'bytedance/seed-tts-2.0');
        addTearDown(notifier.dispose);

        notifier.setVoice(_representativeVolcengineSpeakerId);
        expect(notifier.state.voice, _representativeVolcengineSpeakerId);

        notifier.updateModel(' BYTEDANCE/SEED-TTS-2.0 ');
        expect(notifier.state.voice, _representativeVolcengineSpeakerId);
        expect(
          notifier.availableVoices,
          contains(_representativeVolcengineSpeakerId),
        );
      },
    );
  });

  group('TtsRequest provider voice validation', () {
    test('non-default and final Volcengine speaker IDs are accepted', () {
      for (final speakerId in const [
        _representativeVolcengineSpeakerId,
        _lastVolcengineSpeakerId,
      ]) {
        final validated = TtsRequest(
          text: 'Voice catalog regression',
          model: ' BYTEDANCE/seed-tts-2.0 ',
          voice: speakerId,
          speed: 1,
        ).validated();

        expect(validated.model, 'BYTEDANCE/seed-tts-2.0');
        expect(validated.voice, speakerId);
      }
    });

    test('OpenAI models reject Volcengine speaker IDs', () {
      expect(
        () => const TtsRequest(
          text: 'Voice catalog regression',
          model: 'tts-1',
          voice: _representativeVolcengineSpeakerId,
          speed: 1,
        ).validated(),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            AppErrorCode.invalidConfiguration,
          ),
        ),
      );
    });
  });
}

TtsNotifier _createNotifier({required String model}) {
  return TtsNotifier(
    apiService: TtsApiService(DioClient(const SettingsState())),
    playback: const _SilentPlaybackController(),
    historyWriter: ({required text, required audioPath}) async {},
    model: model,
  );
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
