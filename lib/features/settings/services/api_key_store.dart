import 'package:flutter/services.dart';

import '../../../core/errors/app_exception.dart';

abstract interface class ApiKeyStore {
  Future<String?> read();

  Future<void> write(String value);

  Future<void> delete();
}

class MethodChannelApiKeyStore implements ApiKeyStore {
  const MethodChannelApiKeyStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'ai.glosc.voxflow/secure_credentials/v1';

  final MethodChannel _channel;

  @override
  Future<String?> read() async {
    try {
      final value = await _channel.invokeMethod<String>('readApiKey');
      if (value != null && value.isEmpty) {
        throw _corruptStorage();
      }
      return value;
    } on AppException {
      rethrow;
    } on PlatformException catch (error) {
      throw _mapPlatformError(error.code);
    } on MissingPluginException {
      throw _unavailableStorage();
    } catch (_) {
      throw _unavailableStorage();
    }
  }

  @override
  Future<void> write(String value) async {
    if (value.isEmpty) {
      throw const AppException(
        AppErrorCode.invalidConfiguration,
        'API Key 不能为空。',
        englishMessage: 'The API key cannot be empty.',
      );
    }
    try {
      await _channel.invokeMethod<void>('writeApiKey', {'value': value});
    } on PlatformException catch (error) {
      throw _mapPlatformError(error.code);
    } on MissingPluginException {
      throw _unavailableStorage();
    } catch (_) {
      throw _unavailableStorage();
    }
  }

  @override
  Future<void> delete() async {
    try {
      await _channel.invokeMethod<void>('deleteApiKey');
    } on PlatformException catch (error) {
      throw _mapPlatformError(error.code);
    } on MissingPluginException {
      throw _unavailableStorage();
    } catch (_) {
      throw _unavailableStorage();
    }
  }

  static AppException _mapPlatformError(String code) {
    if (code == 'secure_storage_corrupt') {
      return _corruptStorage();
    }
    return _unavailableStorage();
  }

  static AppException _unavailableStorage() => const AppException(
    AppErrorCode.storageFailure,
    '无法访问系统安全凭据存储。',
    englishMessage: 'The system credential store is unavailable.',
  );

  static AppException _corruptStorage() => const AppException(
    AppErrorCode.storageFailure,
    '本机保存的 API 凭据已损坏，请清空应用数据后重新配置。',
    englishMessage:
        'The saved API credential is corrupt. Reset app data and configure it again.',
  );
}
