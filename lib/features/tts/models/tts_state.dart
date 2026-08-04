import 'dart:ui' show Locale;

import '../../../core/errors/app_exception.dart';

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
    this.playbackRate = 1.0,
    this.volume = 1.0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.audioPath,
    this.error,
    String? errorMessage,
  }) : _legacyErrorMessage = errorMessage;

  final TtsPhase phase;
  final String voice;
  final double speed;
  final double playbackRate;
  final double volume;
  final Duration position;
  final Duration duration;
  final String? audioPath;
  final AppMessage? error;
  final String? _legacyErrorMessage;

  /// Chinese compatibility getter used by the current views.
  String? get errorMessage =>
      error?.resolve(const Locale('zh')) ?? _legacyErrorMessage;

  String? errorMessageFor(Locale locale) =>
      error?.resolve(locale) ?? _legacyErrorMessage;

  bool get hasAudio => audioPath != null;
  bool get isPlaying => phase == TtsPhase.playing;
  bool get isGenerating => phase == TtsPhase.generating;

  TtsState copyWith({
    TtsPhase? phase,
    String? voice,
    double? speed,
    double? playbackRate,
    double? volume,
    Duration? position,
    Duration? duration,
    String? audioPath,
    bool clearAudio = false,
    AppMessage? error,
    String? errorMessage,
    bool clearError = false,
  }) {
    final nextError = clearError
        ? null
        : (error ?? (errorMessage == null ? this.error : null));
    final nextLegacyError = clearError || error != null
        ? null
        : (errorMessage ?? (this.error == null ? _legacyErrorMessage : null));
    return TtsState(
      phase: phase ?? this.phase,
      voice: voice ?? this.voice,
      speed: speed ?? this.speed,
      playbackRate: playbackRate ?? this.playbackRate,
      volume: volume ?? this.volume,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      audioPath: clearAudio ? null : (audioPath ?? this.audioPath),
      error: nextError,
      errorMessage: nextLegacyError,
    );
  }
}
