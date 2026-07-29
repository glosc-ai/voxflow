import 'dart:io';

import '../models/transcription_result.dart';

typedef UploadProgressCallback = void Function(double progress);

abstract interface class TranscriptionService {
  Future<TranscriptionResult> transcribe(
    File file, {
    UploadProgressCallback? onUploadProgress,
  });
}
