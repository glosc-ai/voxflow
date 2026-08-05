import 'volcengine_tts_voice_catalog.dart';

class AppConstants {
  AppConstants._();

  static const appName = '声流';
  static const defaultBaseUrl = 'https://one.gloscai.com/v1';
  static const apiKeyPageUrl = 'https://www.glosc.ai/keys';
  static const defaultSttModel = 'whisper-1';
  static const defaultTtsModel = 'tts-1';
  static const seedTtsModel = 'bytedance/seed-tts-2.0';
  static const navigationBreakpoint = 720.0;
  static const maxTranscriptionBytes = 25 * 1024 * 1024;
  static const maxTtsCharacters = 4096;

  static const supportedImportExtensions = <String>[
    'mp3',
    'mp4',
    'mpeg',
    'mpga',
    'm4a',
    'wav',
    'webm',
  ];

  static const voices = <String>[
    'alloy',
    'echo',
    'fable',
    'onyx',
    'nova',
    'shimmer',
  ];

  /// Seed-TTS 2.0 Speaker IDs derived from the single typed catalog.
  ///
  /// Keep the public string list for request validation and provider state; UI
  /// metadata is resolved from [VolcengineTtsVoiceCatalog.voices].
  static final List<String> bytedanceTtsVoices = List.unmodifiable(
    VolcengineTtsVoiceCatalog.voices.map((voice) => voice.speakerId),
  );

  static bool usesVolcengineSeedTtsVoiceCatalog(String model) {
    return model.trim().toLowerCase() == seedTtsModel;
  }

  static List<String> ttsVoicesForModel(String model) {
    return usesVolcengineSeedTtsVoiceCatalog(model)
        ? bytedanceTtsVoices
        : voices;
  }

  static String defaultTtsVoiceForModel(String model) {
    return ttsVoicesForModel(model).first;
  }
}
