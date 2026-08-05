import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../models/settings_state.dart';
import 'api_key_store.dart';

class SettingsRepository {
  SettingsRepository(this._preferences, [ApiKeyStore? apiKeyStore])
    : _apiKeyStore = apiKeyStore ?? const MethodChannelApiKeyStore(),
      _apiKey = '';

  static const _legacyApiKeyKey = 'settings.api_key';
  static const _credentialUpdatePendingKey =
      'settings.credentials_update_pending';
  static const _credentialEnvelopePrefix = 'voxflow-credential-v2:';
  static const _baseUrlKey = 'settings.base_url';
  static const _sttModelKey = 'settings.stt_model';
  static const _ttsModelKey = 'settings.tts_model';
  static const _themeModeKey = 'settings.theme_mode';
  static const _localeKey = 'settings.locale';

  final SharedPreferences _preferences;
  final ApiKeyStore _apiKeyStore;
  String _apiKey;
  bool _credentialsFailClosed = false;

  Future<void> initialize() async {
    try {
      await _preferences.reload();
      _credentialsFailClosed =
          _preferences.getBool(_credentialUpdatePendingKey) == true;
      if (_credentialsFailClosed) {
        _apiKey = '';
        await _removeLegacyApiKeyVerified();
        return;
      }
      final secureValue = await _apiKeyStore.read();
      final legacyApiKey = _preferences.getString(_legacyApiKeyKey);
      if (secureValue != null) {
        if (legacyApiKey != null) {
          await _removeLegacyApiKeyVerified();
        }
        final persistedBaseUrl = _normalizedPersistedBaseUrl();
        if (persistedBaseUrl == null) {
          await _enterCredentialFailClosed();
          return;
        }
        final envelope = _decodeCredentialEnvelope(secureValue);
        if (envelope != null && envelope.baseUrl != persistedBaseUrl) {
          await _enterCredentialFailClosed();
          return;
        }
        final secureApiKey = envelope?.apiKey ?? secureValue;
        if (envelope == null) {
          await _writeCredentialBundleVerified(secureApiKey, persistedBaseUrl);
        }
        _apiKey = secureApiKey;
        return;
      }
      if (legacyApiKey != null && legacyApiKey.trim().isNotEmpty) {
        final persistedBaseUrl = _normalizedPersistedBaseUrl();
        if (persistedBaseUrl == null) {
          await _removeLegacyApiKeyVerified();
          await _enterCredentialFailClosed();
          return;
        }
        await _writeCredentialBundleVerified(legacyApiKey, persistedBaseUrl);
        await _removeLegacyApiKeyVerified();
        _apiKey = legacyApiKey;
        return;
      }
      _apiKey = '';
      if (legacyApiKey != null) {
        await _removeLegacyApiKeyVerified();
      }
    } on AppException {
      rethrow;
    } catch (_) {
      throw _storageFailure('无法读取本机安全凭据。');
    }
  }

  SettingsState load() {
    try {
      return SettingsState(
        apiKey: _credentialsFailClosed ? '' : _apiKey,
        baseUrl:
            _preferences.getString(_baseUrlKey) ?? AppConstants.defaultBaseUrl,
        sttModel:
            _preferences.getString(_sttModelKey) ??
            AppConstants.defaultSttModel,
        ttsModel:
            _preferences.getString(_ttsModelKey) ??
            AppConstants.defaultTtsModel,
        themePreference: AppThemePreference.fromStorage(
          _preferences.getString(_themeModeKey),
        ),
        localePreference: AppLocalePreference.fromStorage(
          _preferences.getString(_localeKey),
        ),
        credentialRecoveryRequired: _credentialsFailClosed,
      );
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法读取本机设置。',
        englishMessage: 'Local settings could not be loaded.',
      );
    }
  }

  Future<void> save(SettingsState settings) async {
    final previousApiKey = _apiKey;
    final apiKeyChanged = settings.apiKey != previousApiKey;
    final previousBaseUrl =
        _preferences.getString(_baseUrlKey) ?? AppConstants.defaultBaseUrl;
    final credentialsChanged =
        apiKeyChanged || settings.baseUrl != previousBaseUrl;
    try {
      if (credentialsChanged) {
        await _setCredentialUpdatePendingVerified();
        _credentialsFailClosed = true;
      }
      if (credentialsChanged) {
        await _replaceCredential(settings.apiKey, settings.baseUrl);
      }
      await _removeLegacyApiKeyVerified();
      final results = await Future.wait([
        _preferences.setString(_baseUrlKey, settings.baseUrl),
        _preferences.setString(_sttModelKey, settings.sttModel),
        _preferences.setString(_ttsModelKey, settings.ttsModel),
        _preferences.setString(_themeModeKey, settings.themePreference.name),
        _preferences.setString(_localeKey, settings.localePreference.name),
      ]);
      if (results.any((success) => !success)) {
        throw const AppException(
          AppErrorCode.storageFailure,
          '设置保存失败，请重试。',
          englishMessage: 'Settings could not be saved. Try again.',
        );
      }
      if (credentialsChanged) {
        await _clearCredentialUpdatePendingVerified();
        _apiKey = settings.apiKey;
        _credentialsFailClosed = false;
      }
    } on AppException {
      if (credentialsChanged) {
        await _restoreCredentialBestEffort(previousApiKey, previousBaseUrl);
      }
      if (credentialsChanged) {
        _credentialsFailClosed = true;
        await _setCredentialUpdatePendingBestEffort();
      }
      rethrow;
    } catch (_) {
      if (credentialsChanged) {
        await _restoreCredentialBestEffort(previousApiKey, previousBaseUrl);
      }
      if (credentialsChanged) {
        _credentialsFailClosed = true;
        await _setCredentialUpdatePendingBestEffort();
      }
      throw const AppException(
        AppErrorCode.storageFailure,
        '设置保存失败，请重试。',
        englishMessage: 'Settings could not be saved. Try again.',
      );
    }
  }

  /// Removes only VoxFlow's configurable preferences.
  ///
  /// Privacy acknowledgement, history, managed audio, and diagnostics use
  /// separate storage and must not be affected by this operation.
  Future<void> resetLocalPreferences() async {
    final snapshot = load();
    try {
      await _apiKeyStore.delete();
      _apiKey = '';
      final results = await Future.wait([
        _preferences.remove(_legacyApiKeyKey),
        _preferences.remove(_credentialUpdatePendingKey),
        _preferences.remove(_baseUrlKey),
        _preferences.remove(_sttModelKey),
        _preferences.remove(_ttsModelKey),
        _preferences.remove(_themeModeKey),
        _preferences.remove(_localeKey),
      ]);
      if (results.any((success) => !success)) {
        throw const AppException(
          AppErrorCode.storageFailure,
          '无法重置本机偏好，请重试。',
          englishMessage: 'Local preferences could not be reset. Try again.',
        );
      }
      _credentialsFailClosed = false;
    } on AppException {
      try {
        await save(snapshot);
      } catch (_) {
        // Best-effort rollback keeps the original failure actionable.
      }
      rethrow;
    } catch (_) {
      try {
        await save(snapshot);
      } catch (_) {
        // Best-effort rollback keeps the original failure actionable.
      }
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法重置本机偏好，请重试。',
        englishMessage: 'Local preferences could not be reset. Try again.',
      );
    }
  }

  /// Makes a corrupt platform credential recoverable before the main app can
  /// bootstrap. The fail-closed marker is committed first, so even a platform
  /// deletion failure cannot expose or migrate a retained key on the retry.
  Future<void> clearCredentialForRecovery() async {
    try {
      await _setCredentialUpdatePendingVerified();
      _credentialsFailClosed = true;
      _apiKey = '';
      Object? deletionFailure;
      try {
        await _apiKeyStore.delete();
      } catch (error) {
        deletionFailure = error;
      }
      try {
        await _removeLegacyApiKeyVerified();
      } catch (error) {
        deletionFailure ??= error;
      }
      if (deletionFailure != null) {
        if (deletionFailure is AppException) {
          throw deletionFailure;
        }
        throw _storageFailure('无法清除本机安全凭据。');
      }
      await _clearCredentialUpdatePendingVerified();
      _credentialsFailClosed = false;
    } on AppException {
      rethrow;
    } catch (_) {
      throw _storageFailure('无法清除本机安全凭据。');
    }
  }

  Future<void> _replaceCredential(String apiKey, String baseUrl) {
    return apiKey.isEmpty
        ? _apiKeyStore.delete()
        : _writeCredentialBundleVerified(apiKey, baseUrl);
  }

  Future<void> _restoreCredentialBestEffort(
    String apiKey,
    String baseUrl,
  ) async {
    try {
      await _replaceCredential(apiKey, baseUrl);
      _apiKey = apiKey;
    } catch (_) {
      // Preserve the original actionable storage failure.
    }
  }

  Future<void> _removeLegacyApiKeyVerified() async {
    if (!_preferences.containsKey(_legacyApiKeyKey)) {
      return;
    }
    final removed = await _preferences.remove(_legacyApiKeyKey);
    await _preferences.reload();
    if (!removed || _preferences.containsKey(_legacyApiKeyKey)) {
      throw _storageFailure('无法清理旧版 API 凭据。');
    }
  }

  Future<void> _setCredentialUpdatePendingVerified() async {
    final saved = await _preferences.setBool(_credentialUpdatePendingKey, true);
    await _preferences.reload();
    if (!saved || _preferences.getBool(_credentialUpdatePendingKey) != true) {
      throw _storageFailure('无法安全地更新 API 凭据配置。');
    }
  }

  Future<void> _clearCredentialUpdatePendingVerified() async {
    final removed = await _preferences.remove(_credentialUpdatePendingKey);
    await _preferences.reload();
    if (!removed || _preferences.containsKey(_credentialUpdatePendingKey)) {
      throw _storageFailure('无法确认 API 凭据配置已保存。');
    }
  }

  Future<void> _setCredentialUpdatePendingBestEffort() async {
    try {
      await _preferences.setBool(_credentialUpdatePendingKey, true);
      await _preferences.reload();
    } catch (_) {
      // The in-memory fail-closed flag still prevents credential use in this
      // process; the original storage failure remains the actionable error.
    }
  }

  Future<void> _enterCredentialFailClosed() async {
    await _setCredentialUpdatePendingVerified();
    _credentialsFailClosed = true;
    _apiKey = '';
  }

  Future<void> _writeCredentialBundleVerified(
    String apiKey,
    String baseUrl,
  ) async {
    final normalizedBaseUrl = SettingsState.normalizeBaseUrl(baseUrl);
    final encoded = _encodeCredentialEnvelope(apiKey, normalizedBaseUrl);
    await _apiKeyStore.write(encoded);
    if (await _apiKeyStore.read() != encoded) {
      throw _storageFailure('无法验证安全保存的 API 凭据配置。');
    }
  }

  static String _encodeCredentialEnvelope(String apiKey, String baseUrl) {
    final payload = jsonEncode({
      'version': 2,
      'api_key': apiKey,
      'base_url': baseUrl,
    });
    return '$_credentialEnvelopePrefix${base64Url.encode(utf8.encode(payload))}';
  }

  static _SecureCredentialEnvelope? _decodeCredentialEnvelope(String value) {
    if (!value.startsWith(_credentialEnvelopePrefix)) {
      return null;
    }
    try {
      final encoded = value.substring(_credentialEnvelopePrefix.length);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(encoded)));
      if (decoded is! Map ||
          decoded['version'] != 2 ||
          decoded['api_key'] is! String ||
          decoded['base_url'] is! String) {
        throw const FormatException();
      }
      final apiKey = decoded['api_key'] as String;
      final baseUrl = decoded['base_url'] as String;
      final normalizedBaseUrl = SettingsState.normalizeBaseUrl(baseUrl);
      if (apiKey.isEmpty || baseUrl != normalizedBaseUrl) {
        throw const FormatException();
      }
      return _SecureCredentialEnvelope(
        apiKey: apiKey,
        baseUrl: normalizedBaseUrl,
      );
    } catch (_) {
      throw _storageFailure('本机保存的 API 凭据绑定已损坏。');
    }
  }

  String? _normalizedPersistedBaseUrl() {
    final value = _preferences.getString(_baseUrlKey);
    if (value == null) {
      return null;
    }
    try {
      return SettingsState.normalizeBaseUrl(value);
    } on AppException {
      return null;
    }
  }

  static AppException _storageFailure(String message) => AppException(
    AppErrorCode.storageFailure,
    message,
    englishMessage: 'Local credentials could not be loaded securely.',
  );
}

class _SecureCredentialEnvelope {
  const _SecureCredentialEnvelope({
    required this.apiKey,
    required this.baseUrl,
  });

  final String apiKey;
  final String baseUrl;
}
