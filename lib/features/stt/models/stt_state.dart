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
    this.result,
    this.editedText = '',
    this.errorMessage,
  });

  final SttPhase phase;
  final int countdown;
  final Duration elapsed;
  final double uploadProgress;
  final String? selectedFilePath;
  final TranscriptionResult? result;
  final String editedText;
  final String? errorMessage;

  bool get isRecording =>
      phase == SttPhase.recording || phase == SttPhase.paused;
  bool get isProcessing =>
      phase == SttPhase.uploading || phase == SttPhase.transcribing;
  bool get canStart =>
      !isRecording && !isProcessing && phase != SttPhase.countdown;
  bool get canExport => result != null && editedText.trim().isNotEmpty;
  bool get canExportSrt => result?.hasSegments ?? false;

  SttState copyWith({
    SttPhase? phase,
    int? countdown,
    Duration? elapsed,
    double? uploadProgress,
    String? selectedFilePath,
    bool clearSelectedFile = false,
    TranscriptionResult? result,
    bool clearResult = false,
    String? editedText,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SttState(
      phase: phase ?? this.phase,
      countdown: countdown ?? this.countdown,
      elapsed: elapsed ?? this.elapsed,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      selectedFilePath: clearSelectedFile
          ? null
          : (selectedFilePath ?? this.selectedFilePath),
      result: clearResult ? null : (result ?? this.result),
      editedText: editedText ?? this.editedText,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
