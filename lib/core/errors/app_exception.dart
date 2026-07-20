enum AppErrorCode {
  missingApiKey,
  invalidConfiguration,
  permissionDenied,
  fileNotFound,
  invalidFile,
  fileTooLarge,
  networkTimeout,
  unauthorized,
  rateLimited,
  serviceUnavailable,
  recordingUnavailable,
  playbackFailed,
  storageFailure,
  unknown,
}

class AppException implements Exception {
  const AppException(this.code, this.message);

  final AppErrorCode code;
  final String message;

  @override
  String toString() => message;
}
