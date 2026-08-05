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

  static const seedTtsVoices = <String>[
    'zh_female_cancan_uranus_bigtts',
  ];

  static List<String> ttsVoicesForModel(String model) {
    return model.trim().toLowerCase() == seedTtsModel ? seedTtsVoices : voices;
  }

  static String defaultTtsVoiceForModel(String model) {
    return ttsVoicesForModel(model).first;
  }
}
