import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/constants/app_constants.dart';
import 'package:voxflow/core/errors/app_exception.dart';
import 'package:voxflow/core/logging/app_logger.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/settings/models/model_catalog.dart';
import 'package:voxflow/features/settings/providers/settings_provider.dart';
import 'package:voxflow/features/settings/services/settings_repository.dart';
import 'package:voxflow/features/settings/services/api_key_store.dart';

import '../../support/memory_api_key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsState', () {
    test('默认使用 Glosc API Root 和密钥页面', () {
      expect(const SettingsState().baseUrl, 'https://one.gloscai.com/v1');
      expect(AppConstants.apiKeyPageUrl, 'https://www.glosc.ai/keys');
    });

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
    final apiKeyStore = MemoryApiKeyStore();
    final repository = SettingsRepository(preferences, apiKeyStore);
    const settings = SettingsState(
      apiKey: 'test-secret',
      baseUrl: 'https://proxy.example/v1',
      sttModel: 'whisper-1',
      ttsModel: 'tts-1',
    );

    await repository.save(settings);
    final restoredRepository = SettingsRepository(preferences, apiKeyStore);
    await restoredRepository.initialize();
    final restored = restoredRepository.load();

    expect(restored.apiKey, 'test-secret');
    expect(restored.baseUrl, 'https://proxy.example/v1');
    expect(preferences.getString('settings.api_key'), isNull);
    expect(
      preferences.getKeys().map<Object?>((key) => preferences.get(key)),
      isNot(contains('test-secret')),
    );
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
    final apiKeyStore = MemoryApiKeyStore();
    final repository = SettingsRepository(preferences, apiKeyStore);

    await repository.initialize();

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
    expect(apiKeyStore.value, isNull);
  });

  test('旧版明文 API Key 会迁移到安全存储后再删除', () async {
    SharedPreferences.setMockInitialValues({
      'settings.api_key': 'legacy-secret',
      'settings.base_url': 'https://proxy.example/v1',
    });
    final preferences = await SharedPreferences.getInstance();
    final apiKeyStore = MemoryApiKeyStore();
    final repository = SettingsRepository(preferences, apiKeyStore);

    await repository.initialize();

    expect(repository.load().apiKey, 'legacy-secret');
    expect(preferences.getString('settings.api_key'), isNull);

    final restoredRepository = SettingsRepository(preferences, apiKeyStore);
    await restoredRepository.initialize();
    expect(restoredRepository.load().apiKey, 'legacy-secret');
    expect(restoredRepository.load().baseUrl, 'https://proxy.example/v1');
  });

  test('旧格式安全 Key 与有效 Root 会升级绑定且拒绝后续单侧替换', () async {
    SharedPreferences.setMockInitialValues({
      'settings.base_url': 'https://provider-a.example/v1',
    });
    final preferences = await SharedPreferences.getInstance();
    final apiKeyStore = MemoryApiKeyStore(initialValue: 'legacy-secure-key');
    final repository = SettingsRepository(preferences, apiKeyStore);

    await repository.initialize();
    expect(repository.load().apiKey, 'legacy-secure-key');
    expect(repository.load().credentialRecoveryRequired, isFalse);

    await preferences.setString(
      'settings.base_url',
      'https://provider-b.example/v1',
    );
    final mismatchedRepository = SettingsRepository(preferences, apiKeyStore);
    await mismatchedRepository.initialize();

    expect(mismatchedRepository.load().apiKey, isEmpty);
    expect(mismatchedRepository.load().credentialRecoveryRequired, isTrue);
  });

  test('未完成的凭据配置事务会保持关闭且不暴露安全存储中的 Key', () async {
    SharedPreferences.setMockInitialValues({
      'settings.credentials_update_pending': true,
      'settings.base_url': 'https://changed.example/v1',
      'settings.api_key': 'legacy-secret',
    });
    final preferences = await SharedPreferences.getInstance();
    final apiKeyStore = MemoryApiKeyStore(initialValue: 'retained-secret');
    final repository = SettingsRepository(preferences, apiKeyStore);

    await repository.initialize();

    expect(repository.load().apiKey, isEmpty);
    expect(repository.load().baseUrl, 'https://changed.example/v1');
    expect(apiKeyStore.value, 'retained-secret');
    expect(preferences.getString('settings.api_key'), isNull);
    await _expectNoStartupConnection(repository);
  });

  test('凭据恢复期间保存其他偏好不会解除关闭状态', () async {
    SharedPreferences.setMockInitialValues({
      'settings.credentials_update_pending': true,
      'settings.base_url': 'https://provider.example/v1',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(
      preferences,
      MemoryApiKeyStore(initialValue: 'retained-secret'),
    );
    await repository.initialize();

    await repository.save(
      repository.load().copyWith(themePreference: AppThemePreference.dark),
    );

    expect(repository.load().credentialRecoveryRequired, isTrue);
    expect(repository.load().apiKey, isEmpty);
    expect(preferences.getBool('settings.credentials_update_pending'), isTrue);
  });

  test('安全存储有 Key 但 API Root 丢失时保持关闭且不暴露 Key', () async {
    SharedPreferences.setMockInitialValues({
      'settings.api_key': 'legacy-secret',
    });
    final preferences = await SharedPreferences.getInstance();
    final apiKeyStore = MemoryApiKeyStore(initialValue: 'retained-secret');
    final repository = SettingsRepository(preferences, apiKeyStore);

    await repository.initialize();

    expect(repository.load().apiKey, isEmpty);
    expect(repository.load().credentialRecoveryRequired, isTrue);
    expect(preferences.getString('settings.api_key'), isNull);
    expect(preferences.getBool('settings.credentials_update_pending'), isTrue);
    await _expectNoStartupConnection(repository);
  });

  test('仅有旧版明文 Key 且 API Root 丢失时删除明文并保持关闭', () async {
    SharedPreferences.setMockInitialValues({
      'settings.api_key': 'legacy-secret',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences, MemoryApiKeyStore());

    await repository.initialize();

    expect(repository.load().apiKey, isEmpty);
    expect(repository.load().credentialRecoveryRequired, isTrue);
    expect(preferences.getString('settings.api_key'), isNull);
    expect(preferences.getBool('settings.credentials_update_pending'), isTrue);
    await _expectNoStartupConnection(repository);
  });

  test('安全 Key 与单侧恢复的 API Root 不匹配时保持关闭', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final apiKeyStore = MemoryApiKeyStore();
    final writer = SettingsRepository(preferences, apiKeyStore);
    await writer.save(
      const SettingsState(
        apiKey: 'provider-a-secret',
        baseUrl: 'https://provider-a.example/v1',
      ),
    );
    await preferences.setString(
      'settings.base_url',
      'https://provider-b.example/v1',
    );
    await preferences.setString('settings.api_key', 'legacy-secret');

    final restored = SettingsRepository(preferences, apiKeyStore);
    await restored.initialize();

    expect(restored.load().apiKey, isEmpty);
    expect(restored.load().credentialRecoveryRequired, isTrue);
    expect(preferences.getString('settings.api_key'), isNull);
    await _expectNoStartupConnection(restored);
  });

  test('启动恢复在平台删除失败时保留关闭标记并允许安全重试', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final apiKeyStore = MemoryApiKeyStore(initialValue: 'retained-secret')
      ..deleteError = StateError('platform failure');
    final repository = SettingsRepository(preferences, apiKeyStore);

    await expectLater(
      repository.clearCredentialForRecovery(),
      throwsA(isA<AppException>()),
    );
    expect(preferences.getBool('settings.credentials_update_pending'), isTrue);

    await repository.initialize();
    expect(repository.load().apiKey, isEmpty);
    expect(apiKeyStore.value, 'retained-secret');
  });

  test('启动恢复在安全存储删除失败时仍清理旧版明文', () async {
    SharedPreferences.setMockInitialValues({
      'settings.api_key': 'legacy-secret',
      'settings.base_url': 'https://provider.example/v1',
    });
    final preferences = await SharedPreferences.getInstance();
    final apiKeyStore = MemoryApiKeyStore(initialValue: 'retained-secret')
      ..deleteError = StateError('platform failure');
    final repository = SettingsRepository(preferences, apiKeyStore);

    await expectLater(
      repository.clearCredentialForRecovery(),
      throwsA(isA<AppException>()),
    );

    expect(preferences.getString('settings.api_key'), isNull);
    expect(preferences.getBool('settings.credentials_update_pending'), isTrue);
    expect(repository.load().credentialRecoveryRequired, isTrue);
  });

  test('安全凭据读取失败时不会回退到旧版明文', () async {
    SharedPreferences.setMockInitialValues({
      'settings.api_key': 'legacy-secret',
    });
    final preferences = await SharedPreferences.getInstance();
    final apiKeyStore = MemoryApiKeyStore()
      ..readError = StateError('sentinel-secret');
    final repository = SettingsRepository(preferences, apiKeyStore);

    await expectLater(
      repository.initialize(),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.storageFailure)
            .having(
              (error) => error.toString(),
              'message',
              isNot(contains('sentinel-secret')),
            ),
      ),
    );

    expect(preferences.getString('settings.api_key'), 'legacy-secret');
    expect(repository.load().apiKey, isEmpty);
  });

  test('安全凭据 MethodChannel 使用固定契约且不泄露平台错误正文', () async {
    const channel = MethodChannel(
      'ai.glosc.voxflow/secure_credentials/v1.test',
    );
    final calls = <MethodCall>[];
    String? stored;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'readApiKey':
              return stored;
            case 'writeApiKey':
              stored =
                  (call.arguments as Map<Object?, Object?>)['value'] as String;
              return null;
            case 'deleteApiKey':
              stored = null;
              return null;
          }
          throw PlatformException(code: 'not_implemented');
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    const store = MethodChannelApiKeyStore(channel: channel);

    await store.write('test-secret');
    expect(await store.read(), 'test-secret');
    await store.delete();
    expect(await store.read(), isNull);
    expect(calls.map((call) => call.method), [
      'writeApiKey',
      'readApiKey',
      'deleteApiKey',
      'readApiKey',
    ]);
    expect(calls.first.arguments, {'value': 'test-secret'});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(
            code: 'secure_storage_unavailable',
            message: 'sentinel-secret',
            details: 'sentinel-secret',
          );
        });
    await expectLater(
      store.read(),
      throwsA(
        isA<AppException>().having(
          (error) => error.toString(),
          'message',
          isNot(contains('sentinel-secret')),
        ),
      ),
    );
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

Future<void> _expectNoStartupConnection(SettingsRepository repository) async {
  var connectionCalls = 0;
  final notifier = SettingsNotifier(
    repository,
    connectionTester: (_) async => connectionCalls += 1,
  );
  try {
    expect(notifier.state.apiKey, isEmpty);
    expect(notifier.state.credentialRecoveryRequired, isTrue);
    await notifier.checkStoredConnectionOnLaunch();
    expect(connectionCalls, 0);
  } finally {
    notifier.dispose();
  }
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
