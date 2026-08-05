import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_exception.dart';

class PrivacyNoticeRepository {
  const PrivacyNoticeRepository(this._preferences);

  static const _acknowledgedKey = 'privacy_notice.acknowledged.v1';

  final SharedPreferences _preferences;

  bool isAcknowledged() {
    try {
      return _preferences.getBool(_acknowledgedKey) ?? false;
    } catch (_) {
      throw const AppException(AppErrorCode.storageFailure, '无法读取数据与隐私说明状态。');
    }
  }

  Future<void> acknowledge() async {
    try {
      final saved = await _preferences.setBool(_acknowledgedKey, true);
      if (!saved) {
        throw const AppException(AppErrorCode.storageFailure, '无法保存数据与隐私说明状态。');
      }
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(AppErrorCode.storageFailure, '无法保存数据与隐私说明状态。');
    }
  }
}
