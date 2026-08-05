import 'dart:io';

import '../../settings/models/settings_state.dart';
import '../models/transcription_result.dart';

typedef UploadProgressCallback = void Function(double progress);

abstract interface class TranscriptionService {
  Future<TranscriptionResult> transcribe(
    File file, {
    UploadProgressCallback? onUploadProgress,
    SettingsState? requestSettings,
  });
}
