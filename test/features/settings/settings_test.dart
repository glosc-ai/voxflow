import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/errors/app_exception.dart';
import 'package:voxflow/core/logging/app_logger.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/models/model_catalog.dart';
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

  test('重置本地偏好只移除设置键并保留隐私确认', () async {
    SharedPreferences.setMockInitialValues({
      'privacy_notice.acknowledged.v1': true,
      'settings.api_key': 'test-secret',
      'settings.base_url': 'https://proxy.example/v1',
      'settings.stt_model': 'gpt-4o-transcribe',
      'settings.tts_model': 'gpt-4o-mini-tts',
      'settings.theme_mode': AppThemePreference.dark.name,
      'settings.locale': AppLocalePreference.english.name,
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);

    await repository.resetLocalPreferences();

    final restored = repository.load();
    const defaults = SettingsState();
    expect(restored.apiKey, defaults.apiKey);
    expect(restored.baseUrl, defaults.baseUrl);
    expect(restored.sttModel, defaults.sttModel);
    expect(restored.ttsModel, defaults.ttsModel);
    expect(restored.themePreference, defaults.themePreference);
    expect(restored.localePreference, defaults.localePreference);
    expect(preferences.getBool('privacy_notice.acknowledged.v1'), isTrue);
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

  test('Dio 错误映射显示代理原因、错误码并保持脱敏', () {
    const secret = 'sk-example-secret-123456';
    final request = RequestOptions(
      path: '/audio/speech',
      headers: const {'Authorization': 'Bearer $secret'},
    );
    final exception = DioClient.mapException(
      DioException(
        requestOptions: request,
        type: DioExceptionType.badResponse,
        response: Response<Object?>(
          requestOptions: request,
          statusCode: 403,
          data: const {
            'error': {
              'message':
                  'Model bytedance/seed-tts-2.0 is not enabled for $secret',
              'code': 'model_not_allowed',
              'type': 'permission_error',
            },
          },
        ),
      ),
    );

    expect(exception.code, AppErrorCode.unauthorized);
    expect(exception.message, contains('bytedance/seed-tts-2.0'));
    expect(exception.message, contains('code=model_not_allowed'));
    expect(exception.message, contains('type=permission_error'));
    expect(exception.message, isNot(contains(secret)));
    expect(exception.message, contains('[REDACTED]'));
  });

  test('Dio 错误映射可解析 TTS 字节响应中的代理原因', () {
    final request = RequestOptions(path: '/audio/speech');
    final responseBytes = utf8.encode(
      jsonEncode({
        'error': {
          'message': 'The requested model is not enabled',
          'code': 'model_not_allowed',
          'type': 'permission_error',
        },
      }),
    );
    final exception = DioClient.mapException(
      DioException(
        requestOptions: request,
        type: DioExceptionType.badResponse,
        response: Response<List<int>>(
          requestOptions: request,
          statusCode: 403,
          data: responseBytes,
        ),
      ),
    );

    expect(exception.code, AppErrorCode.unauthorized);
    expect(exception.message, contains('The requested model is not enabled'));
    expect(exception.message, contains('code=model_not_allowed'));
    expect(exception.message, contains('type=permission_error'));
  });

  test('模型目录按音频能力分类、去重并排序', () {
    final catalog = ModelCatalog.fromIds([
      'tts-1',
      'gpt-4o-transcribe',
      'chat-model',
      'whisper-1',
      'tts-1',
      ' gpt-4o-mini-tts ',
    ]);

    expect(catalog.stt, ['gpt-4o-transcribe', 'whisper-1']);
    expect(catalog.tts, ['gpt-4o-mini-tts', 'tts-1']);
    expect(catalog.all, contains('chat-model'));
  });

  test('Dio 获取模型列表并注入认证', () async {
    final adapter = _ModelsAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    const settings = SettingsState(
      apiKey: 'test-key',
      baseUrl: 'https://proxy.example/v1',
    );

    final ids = await DioClient(settings, dio: dio).fetchModelIds();

    expect(ids, ['whisper-1', 'tts-1']);
    expect(adapter.options!.path, 'https://proxy.example/v1/models');
    expect(adapter.options!.headers['Authorization'], 'Bearer test-key');
  });

  test('Dio 失败请求写入脱敏日志且不记录请求正文', () async {
    final directory = await Directory.systemTemp.createTemp('voxflow_dio_log_');
    addTearDown(() => directory.delete(recursive: true));
    final logFile = File(
      '${directory.path}${Platform.pathSeparator}voxflow.log',
    );
    final logger = AppLogger(fileResolver: () async => logFile);
    final dio = Dio()..httpClientAdapter = _ForbiddenAdapter();
    const secret = 'test-secret-token';
    const sensitiveInput = '这段文字绝不能进入日志';
    const settings = SettingsState(
      apiKey: secret,
      baseUrl: 'https://proxy.example/v1',
      ttsModel: 'bytedance/seed-tts-2.0',
    );
    final client = DioClient(settings, dio: dio, logger: logger);

    await expectLater(
      client.dio.post<Object?>(
        client.endpoint('audio/speech'),
        data: const {
          'model': 'bytedance/seed-tts-2.0',
          'input': sensitiveInput,
        },
      ),
      throwsA(isA<DioException>()),
    );
    await logger.flush();
    final contents = await logger.readAll();

    expect(contents, contains('request_failed'));
    expect(contents, contains('bytedance/seed-tts-2.0'));
    expect(contents, contains('403'));
    expect(contents, isNot(contains(secret)));
    expect(contents, isNot(contains(sensitiveInput)));
  });
}

class _ModelsAdapter implements HttpClientAdapter {
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromString(
      jsonEncode({
        'object': 'list',
        'data': [
          {'id': 'whisper-1', 'object': 'model'},
          {'id': 'tts-1', 'object': 'model'},
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ForbiddenAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'error': {
          'message': 'model is not enabled for test-secret-token',
          'code': 'model_not_allowed',
        },
      }),
      403,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
