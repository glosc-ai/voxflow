import 'dart:ui' show Locale;

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

/// User-facing copy that can be resolved without depending on a BuildContext.
///
/// [technicalDetail] is intended only for short, already-redacted diagnostics.
/// Callers handling network or platform errors must sanitize it before creating
/// an [AppMessage].
class AppMessage {
  const AppMessage({
    required this.zh,
    required this.en,
    this.technicalDetail,
  });

  const AppMessage.same(
    String message, {
    this.technicalDetail,
  })  : zh = message,
        en = message;

  final String zh;
  final String en;
  final String? technicalDetail;

  String resolve(Locale locale) {
    final useChinese = locale.languageCode.toLowerCase() == 'zh';
    final base = useChinese ? zh : en;
    final detail = technicalDetail?.trim();
    if (detail == null || detail.isEmpty) {
      return base;
    }
    // A provider may return human-readable copy in a language that does not
    // match the active UI. Keep the redacted detail available for diagnostics,
    // but do not leak untranslated Chinese payloads into the English surface.
    if (!useChinese && _containsHan(detail)) {
      return base;
    }
    return useChinese
        ? '$base 服务返回：$detail'
        : '$base Service response: $detail';
  }
}

bool _containsHan(String value) => RegExp(r'[\u3400-\u9fff]').hasMatch(value);

class AppException implements Exception {
  const AppException(
    this.code,
    String message, {
    String? englishMessage,
    this.technicalDetail,
  })  : _chineseMessage = message,
        _englishMessage = englishMessage;

  AppException.localized(this.code, AppMessage message)
      : _chineseMessage = message.zh,
        _englishMessage = message.en,
        technicalDetail = message.technicalDetail;

  final AppErrorCode code;
  final String _chineseMessage;
  final String? _englishMessage;

  /// A short diagnostic that has already been stripped of credentials and
  /// other known secrets by the originating boundary.
  final String? technicalDetail;

  /// Compatibility getter for the existing Chinese UI.
  String get message => localizedMessage.resolve(const Locale('zh'));

  /// English rendering, including an optional redacted service detail.
  String get englishMessage => localizedMessage.resolve(const Locale('en'));

  AppMessage get localizedMessage => AppMessage(
        zh: _chineseMessage,
        en: _englishMessage ?? code.defaultEnglishMessage,
        technicalDetail: technicalDetail,
      );

  String messageFor(Locale locale) => localizedMessage.resolve(locale);

  @override
  String toString() => message;
}

extension on AppErrorCode {
  String get defaultEnglishMessage => switch (this) {
        AppErrorCode.missingApiKey =>
          'An API key is required before using this feature.',
        AppErrorCode.invalidConfiguration =>
          'The current configuration is invalid.',
        AppErrorCode.permissionDenied =>
          'The required system permission was not granted.',
        AppErrorCode.fileNotFound => 'The requested file could not be found.',
        AppErrorCode.invalidFile =>
          'The selected file is invalid or unsupported.',
        AppErrorCode.fileTooLarge => 'The selected file is too large.',
        AppErrorCode.networkTimeout =>
          'The request timed out. Check the network and try again.',
        AppErrorCode.unauthorized =>
          'The credentials are invalid or lack permission.',
        AppErrorCode.rateLimited =>
          'Too many requests were sent. Try again later.',
        AppErrorCode.serviceUnavailable =>
          'The service is temporarily unavailable. Try again later.',
        AppErrorCode.recordingUnavailable =>
          'Audio recording is currently unavailable.',
        AppErrorCode.playbackFailed => 'Audio playback failed.',
        AppErrorCode.storageFailure =>
          'The local file or storage operation failed.',
        AppErrorCode.unknown => 'Something went wrong. Try again in a moment.',
      };
}
