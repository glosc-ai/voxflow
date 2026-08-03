import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../models/settings_state.dart';

class SettingsRepository {
  const SettingsRepository(this._preferences);

  static const _apiKeyKey = 'settings.api_key';
  static const _baseUrlKey = 'settings.base_url';
  static const _sttModelKey = 'settings.stt_model';
  static const _ttsModelKey = 'settings.tts_model';
  static const _themeModeKey = 'settings.theme_mode';
  static const _localeKey = 'settings.locale';

  final SharedPreferences _preferences;

  SettingsState load() {
    try {
      return SettingsState(
        apiKey: _preferences.getString(_apiKeyKey) ?? '',
        baseUrl:
            _preferences.getString(_baseUrlKey) ?? AppConstants.defaultBaseUrl,
        sttModel: _preferences.getString(_sttModelKey) ??
            AppConstants.defaultSttModel,
        ttsModel: _preferences.getString(_ttsModelKey) ??
            AppConstants.defaultTtsModel,
        themePreference: AppThemePreference.fromStorage(
          _preferences.getString(_themeModeKey),
        ),
        localePreference: AppLocalePreference.fromStorage(
          _preferences.getString(_localeKey),
        ),
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
    try {
      final results = await Future.wait([
        _preferences.setString(_apiKeyKey, settings.apiKey),
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
    } on AppException {
      rethrow;
    } catch (_) {
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
      final results = await Future.wait([
        _preferences.remove(_apiKeyKey),
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
}
