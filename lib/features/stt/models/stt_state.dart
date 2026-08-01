import 'dart:ui' show Locale;

import '../../../core/errors/app_exception.dart';
import 'transcription_result.dart';

enum SttPhase {
  idle,
  countdown,
  recording,
  paused,
  uploading,
  transcribing,
  success,
  failure,
}

class SttState {
  const SttState({
    this.phase = SttPhase.idle,
    this.countdown = 0,
    this.elapsed = Duration.zero,
    this.uploadProgress = 0,
    this.selectedFilePath,
    this.selectedSourceIsTemporaryRecording = false,
    this.result,
    this.editedText = '',
    this.error,
    String? errorMessage,
  }) : _legacyErrorMessage = errorMessage;

  final SttPhase phase;
  final int countdown;
  final Duration elapsed;
  final double uploadProgress;
  final String? selectedFilePath;
  final bool selectedSourceIsTemporaryRecording;
  final TranscriptionResult? result;
  final String editedText;
  final AppMessage? error;
  final String? _legacyErrorMessage;

  /// Chinese compatibility getter used by the current views.
  String? get errorMessage =>
      error?.resolve(const Locale('zh')) ?? _legacyErrorMessage;

  String? errorMessageFor(Locale locale) =>
      error?.resolve(locale) ?? _legacyErrorMessage;

  bool get isRecording =>
      phase == SttPhase.recording || phase == SttPhase.paused;
  bool get hasActiveRecordingSession =>
      phase == SttPhase.countdown || isRecording;
  bool get isProcessing =>
      phase == SttPhase.uploading || phase == SttPhase.transcribing;
  bool get hasRetainedTemporaryRecording =>
      phase == SttPhase.failure &&
      result == null &&
      selectedSourceIsTemporaryRecording &&
      selectedFilePath != null;
  bool get canStart =>
      result == null &&
      !isRecording &&
      !isProcessing &&
      phase != SttPhase.countdown &&
      !hasRetainedTemporaryRecording;
  bool get canRetrySelectedSource =>
      phase == SttPhase.failure && result == null && selectedFilePath != null;
  bool get canExport => result != null && editedText.trim().isNotEmpty;
  bool get canExportSrt => result?.hasSegments ?? false;

  SttState copyWith({
    SttPhase? phase,
    int? countdown,
    Duration? elapsed,
    double? uploadProgress,
    String? selectedFilePath,
    bool clearSelectedFile = false,
    bool? selectedSourceIsTemporaryRecording,
    TranscriptionResult? result,
    bool clearResult = false,
    String? editedText,
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
    return SttState(
      phase: phase ?? this.phase,
      countdown: countdown ?? this.countdown,
      elapsed: elapsed ?? this.elapsed,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      selectedFilePath: clearSelectedFile
          ? null
          : (selectedFilePath ?? this.selectedFilePath),
      selectedSourceIsTemporaryRecording: clearSelectedFile
          ? false
          : (selectedSourceIsTemporaryRecording ??
              this.selectedSourceIsTemporaryRecording),
      result: clearResult ? null : (result ?? this.result),
      editedText: editedText ?? this.editedText,
      error: nextError,
      errorMessage: nextLegacyError,
    );
  }
}
