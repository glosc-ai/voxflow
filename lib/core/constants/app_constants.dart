class AppConstants {
  AppConstants._();

  static const appName = '声流 VoxFlow';
  static const defaultBaseUrl = 'https://api.openai.com/v1';
  static const defaultSttModel = 'whisper-1';
  static const defaultTtsModel = 'tts-1';
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
}
