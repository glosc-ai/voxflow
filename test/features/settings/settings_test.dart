import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/errors/app_exception.dart';
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
