import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../features/settings/models/settings_state.dart';
import '../errors/app_exception.dart';
import '../logging/app_logger.dart';

typedef SettingsReader = SettingsState Function();

class DioClient {
  DioClient(
    SettingsState settings, {
    Dio? dio,
    AppLogger? logger,
  }) : this.withSettings(
          () => settings,
          dio: dio,
          logger: logger,
        );

  DioClient.withSettings(
    this._settingsReader, {
    Dio? dio,
    AppLogger? logger,
  })  : dio = dio ?? Dio(),
        logger = logger ?? AppLogger.instance {
    final initialSettings = settings;
    this.dio.options = BaseOptions(
      baseUrl: initialSettings.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 5),
      receiveTimeout: const Duration(minutes: 5),
      headers: const {'Accept': 'application/json'},
    );
    this.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final apiKey = settings.apiKey.trim();
              if (apiKey.isNotEmpty &&
                  !options.headers.containsKey('Authorization')) {
                options.headers['Authorization'] = 'Bearer $apiKey';
              }
              unawaited(
                this.logger.info(
                      'network',
                      'request_started',
                      fields: _requestFields(options),
                    ),
              );
              handler.next(options);
            },
            onResponse: (response, handler) {
              unawaited(
                this.logger.info(
                      'network',
                      'request_completed',
                      fields: _responseFields(response),
                    ),
              );
              handler.next(response);
            },
            onError: (error, handler) {
              final reason = extractServerReason(error);
              unawaited(
                this.logger.error(
                  'network',
                  'request_failed',
                  fields: {
                    ..._requestFields(error.requestOptions),
                    'status': error.response?.statusCode,
                    'dio_type': error.type.name,
                    ..._requestIdFields(error.response?.headers),
                    if (reason != null) 'reason': reason,
                  },
                ),
              );
              handler.next(error);
            },
          ),
        );
  }

  static const _modelExtraKey = 'voxflow.request_model';

  final SettingsReader _settingsReader;
  final Dio dio;
  final AppLogger logger;

  SettingsState get settings => _settingsReader();

  Map<String, Object?> _requestFields(RequestOptions options) {
    final path = options.uri.path;
    return {
      'method': options.method,
      'host': options.uri.host,
      'path': path,
      if (options.extra[_modelExtraKey] case final String model) 'model': model,
      if (!options.extra.containsKey(_modelExtraKey) &&
          path.endsWith('/audio/speech'))
        'model': settings.ttsModel,
      if (!options.extra.containsKey(_modelExtraKey) &&
          path.endsWith('/audio/transcriptions'))
        'model': settings.sttModel,
    };
  }

  Map<String, Object?> _responseFields(Response<Object?> response) {
    return {
      ..._requestFields(response.requestOptions),
      'status': response.statusCode,
      ..._requestIdFields(response.headers),
    };
  }

  static Map<String, Object?> _requestIdFields(Headers? headers) {
    final id = _requestId(headers);
    return id == null ? const {} : {'request_id': id};
  }

  static String? _requestId(Headers? headers) {
    if (headers == null) {
      return null;
    }
    for (final name in const [
      'x-request-id',
      'request-id',
      'x-correlation-id',
      'trace-id',
      'cf-ray',
    ]) {
      final value = headers.value(name)?.trim();
      if (value != null && value.isNotEmpty) {
        return AppLogger.redact(value, maxLength: 120);
      }
    }
    return null;
  }

  String endpoint(String path, {SettingsState? requestSettings}) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final baseUrl = SettingsState.normalizeBaseUrl(
      (requestSettings ?? settings).baseUrl,
    );
    return '$baseUrl/$cleanPath';
  }

  Options requestOptions(
    SettingsState requestSettings, {
    String? model,
    ResponseType? responseType,
  }) {
    final apiKey = requestSettings.apiKey.trim();
    return Options(
      responseType: responseType,
      headers: {
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      },
      extra: {
        if (model != null) _modelExtraKey: model,
      },
    );
  }

  Future<void> testConnection() async {
    final validSettings = settings.validated();
    try {
      await dio.get<void>(
        '${validSettings.baseUrl}/models',
        options: requestOptions(validSettings),
      );
    } on DioException catch (error) {
      throw mapException(error);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.unknown,
        'API 连通性测试失败，请检查配置。',
      );
    }
  }

  Future<List<String>> fetchModelIds() async {
    final validSettings = settings.credentialsValidated();
    try {
      final response = await dio.get<Object?>(
        '${validSettings.baseUrl}/models',
        options: requestOptions(validSettings),
      );
      final payload = response.data;
      if (payload is! Map) {
        throw const AppException(
          AppErrorCode.invalidConfiguration,
          '模型列表响应格式不兼容。',
        );
      }
      final data = payload['data'];
      if (data is! List) {
        throw const AppException(
          AppErrorCode.invalidConfiguration,
          '模型列表响应缺少 data 数组。',
        );
      }
      final ids = <String>[];
      for (final item in data) {
        if (item is Map) {
          final id = item['id'];
          if (id is String && id.trim().isNotEmpty) {
            ids.add(id.trim());
          }
        }
      }
      if (ids.isEmpty) {
        throw const AppException(
          AppErrorCode.invalidConfiguration,
          '服务未返回可用模型。',
        );
      }
      return ids;
    } on DioException catch (error) {
      throw mapException(error);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.unknown,
        '无法获取模型列表，请稍后重试。',
      );
    }
  }

  static AppException mapException(
    DioException error, {
    Iterable<String> sensitiveValues = const [],
  }) {
    final detail = extractServerReason(
      error,
      sensitiveValues: sensitiveValues,
    );
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return AppException(
          AppErrorCode.networkTimeout,
          _withDetail('请求超时，请检查网络后重试。', detail),
        );
      case DioExceptionType.connectionError:
        return AppException(
          AppErrorCode.serviceUnavailable,
          _withDetail('无法连接 API 服务，请检查地址和网络。', detail),
        );
      case DioExceptionType.cancel:
        return AppException(
          AppErrorCode.unknown,
          _withDetail('请求已取消。', detail),
        );
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == 401 || status == 403) {
          return AppException(
            AppErrorCode.unauthorized,
            _withDetail('API Key 无效或无权访问该服务。', detail),
          );
        }
        if (status == 413) {
          return AppException(
            AppErrorCode.fileTooLarge,
            _withDetail('上传文件超过服务允许的大小。', detail),
          );
        }
        if (status == 429) {
          return AppException(
            AppErrorCode.rateLimited,
            _withDetail('请求过于频繁或额度不足，请稍后重试。', detail),
          );
        }
        if (status != null && status >= 500) {
          return AppException(
            AppErrorCode.serviceUnavailable,
            _withDetail('API 服务暂时不可用，请稍后重试。', detail),
          );
        }
        final baseMessage = status == 404
            ? 'API 地址不兼容：未找到请求接口。'
            : 'API 请求失败${status == null ? '' : '（$status）'}。';
        return AppException(
          AppErrorCode.serviceUnavailable,
          _withDetail(baseMessage, detail),
        );
      case DioExceptionType.badCertificate:
        return AppException(
          AppErrorCode.serviceUnavailable,
          _withDetail('API 服务的 HTTPS 证书无效。', detail),
        );
      case DioExceptionType.unknown:
        return AppException(
          AppErrorCode.unknown,
          _withDetail('请求失败，请稍后重试。', detail),
        );
    }
  }

  static String? extractServerReason(
    DioException error, {
    Iterable<String> sensitiveValues = const [],
  }) {
    final values = <String>[...sensitiveValues];
    final authorization = error.requestOptions.headers['Authorization'];
    if (authorization != null) {
      final header = authorization.toString();
      values.add(header);
      if (header.toLowerCase().startsWith('bearer ')) {
        values.add(header.substring(7));
      }
    }

    final parts = <String>[];
    void add(Object? value, {String? label}) {
      if (value == null || value is Map || value is Iterable) {
        return;
      }
      final text = value.toString().trim();
      if (text.isEmpty ||
          text.startsWith('<!DOCTYPE') ||
          text.startsWith('<html')) {
        return;
      }
      final sanitized = AppLogger.redact(
        text,
        sensitiveValues: values,
        maxLength: 300,
      );
      final rendered = label == null ? sanitized : '$label=$sanitized';
      if (sanitized.isNotEmpty && !parts.contains(rendered)) {
        parts.add(rendered);
      }
    }

    final data = _decodeErrorPayload(error.response?.data);
    if (data is Map) {
      final nestedError = data['error'];
      if (nestedError is Map) {
        add(nestedError['message']);
        add(nestedError['detail']);
        add(nestedError['code'], label: 'code');
        add(nestedError['type'], label: 'type');
      } else {
        add(nestedError);
      }
      add(data['message']);
      add(data['detail']);
      add(data['code'], label: 'code');
      add(data['type'], label: 'type');
    } else {
      add(data);
    }
    return parts.isEmpty ? null : parts.join('；');
  }

  static Object? _decodeErrorPayload(Object? data) {
    if (data is List<int>) {
      return _decodeErrorText(utf8.decode(data, allowMalformed: true));
    }
    if (data is String) {
      return _decodeErrorText(data);
    }
    return data;
  }

  static Object? _decodeErrorText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(trimmed);
    } on FormatException {
      return trimmed;
    }
  }

  static String _withDetail(String message, String? detail) {
    if (detail == null || detail.isEmpty) {
      return message;
    }
    return '$message 服务返回：$detail';
  }
}
