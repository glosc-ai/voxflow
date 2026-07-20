import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../errors/app_exception.dart';

class PermissionService {
  const PermissionService();

  Future<bool> ensureMicrophoneAccess() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      var status = await Permission.microphone.status;
      if (status.isGranted) {
        return true;
      }
      status = await Permission.microphone.request();
      if (status.isGranted) {
        return true;
      }
      throw const AppException(
        AppErrorCode.permissionDenied,
        '未获得麦克风权限，请在系统设置中允许声流使用麦克风。',
      );
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.permissionDenied,
        '无法检查麦克风权限，请稍后重试。',
      );
    }
  }
}
