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
      );
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法读取本机设置。',
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
      ]);
      if (results.any((success) => !success)) {
        throw const AppException(
          AppErrorCode.storageFailure,
          '设置保存失败，请重试。',
        );
      }
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '设置保存失败，请重试。',
      );
    }
  }
}
