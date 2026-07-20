import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/errors/app_exception.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/services/settings_repository.dart';

void main() {
  group('SettingsState', () {
    test('规范化 HTTPS API Root', () {
      expect(
        SettingsState.normalizeBaseUrl(' https://proxy.example/v1/// '),
        'https://proxy.example/v1',
      );
    });

    test('拒绝明文 HTTP 地址', () {
      expect(
        () => SettingsState.normalizeBaseUrl('http://proxy.example/v1'),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            AppErrorCode.invalidConfiguration,
          ),
        ),
      );
    });
  });

  test('设置可持久化并恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);
    const settings = SettingsState(
      apiKey: 'test-secret',
      baseUrl: 'https://proxy.example/v1',
      sttModel: 'whisper-1',
      ttsModel: 'tts-1',
    );

    await repository.save(settings);
    final restored = repository.load();

    expect(restored.apiKey, 'test-secret');
    expect(restored.baseUrl, 'https://proxy.example/v1');
  });

  test('Dio 错误映射不包含服务端正文或密钥', () {
    final request = RequestOptions(
      path: '/models',
      headers: const {'Authorization': 'Bearer test-secret'},
    );
    final exception = DioClient.mapException(
      DioException(
        requestOptions: request,
        type: DioExceptionType.badResponse,
        response: Response<Object?>(
          requestOptions: request,
          statusCode: 401,
          data: const {'error': 'test-secret should never surface'},
        ),
      ),
    );

    expect(exception.code, AppErrorCode.unauthorized);
    expect(exception.message, isNot(contains('test-secret')));
  });
}
