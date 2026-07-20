enum TtsPhase {
  idle,
  generating,
  ready,
  playing,
  paused,
  completed,
  failure,
}

class TtsState {
  const TtsState({
    this.phase = TtsPhase.idle,
    this.voice = 'alloy',
    this.speed = 1.0,
    this.volume = 1.0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.audioPath,
    this.errorMessage,
  });

  final TtsPhase phase;
  final String voice;
  final double speed;
  final double volume;
  final Duration position;
  final Duration duration;
  final String? audioPath;
  final String? errorMessage;

  bool get hasAudio => audioPath != null;
  bool get isPlaying => phase == TtsPhase.playing;
  bool get isGenerating => phase == TtsPhase.generating;

  TtsState copyWith({
    TtsPhase? phase,
    String? voice,
    double? speed,
    double? volume,
    Duration? position,
    Duration? duration,
    String? audioPath,
    bool clearAudio = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TtsState(
      phase: phase ?? this.phase,
      voice: voice ?? this.voice,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      audioPath: clearAudio ? null : (audioPath ?? this.audioPath),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
