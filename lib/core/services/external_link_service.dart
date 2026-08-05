import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../errors/app_exception.dart';

final externalLinkServiceProvider = Provider<ExternalLinkService>(
  (ref) => const ExternalLinkService(),
);

/// Opens trusted web destinations through the platform's default browser.
///
/// Both this boundary and the native implementations only allow VoxFlow's
/// fixed API-key page.
class ExternalLinkService {
  const ExternalLinkService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'ai.glosc.voxflow/external_links/v1';
  static const _openMethod = 'open';
  static const _allowedUrl = AppConstants.apiKeyPageUrl;

  final MethodChannel _channel;

  Future<void> open(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (!_isAllowed(uri)) {
      throw _invalidUrl();
    }

    try {
      await _channel.invokeMethod<void>(_openMethod, {'url': _allowedUrl});
    } on PlatformException catch (error) {
      throw _mapPlatformError(error.code);
    } on MissingPluginException {
      throw _unavailable();
    } catch (_) {
      throw _unavailable();
    }
  }

  static bool _isAllowed(Uri? uri) =>
      uri != null &&
      uri.isAbsolute &&
      uri.scheme.toLowerCase() == 'https' &&
      uri.hasAuthority &&
      uri.host.toLowerCase() == 'www.glosc.ai' &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      uri.path == '/keys' &&
      !uri.hasQuery &&
      !uri.hasFragment;

  static AppException _mapPlatformError(String code) {
    if (code == 'invalid_url') {
      return _invalidUrl();
    }
    return _unavailable();
  }

  static AppException _invalidUrl() => const AppException(
    AppErrorCode.invalidConfiguration,
    '只能打开指定的 API 密钥页面。',
    englishMessage: 'Only the configured API key page can be opened.',
  );

  static AppException _unavailable() => const AppException(
    AppErrorCode.serviceUnavailable,
    '无法使用系统浏览器打开此链接。',
    englishMessage: 'This link could not be opened in the system browser.',
  );
}
