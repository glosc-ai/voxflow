import 'package:dio/dio.dart';

import '../../features/settings/models/settings_state.dart';
import '../errors/app_exception.dart';

class DioClient {
  DioClient(this.settings, {Dio? dio}) : dio = dio ?? Dio() {
    this.dio.options = BaseOptions(
      baseUrl: settings.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 5),
      receiveTimeout: const Duration(minutes: 5),
      headers: const {'Accept': 'application/json'},
    );
    this.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final apiKey = settings.apiKey.trim();
              if (apiKey.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $apiKey';
              }
              handler.next(options);
            },
            onError: (error, handler) {
              handler.next(error);
            },
          ),
        );
  }

  final SettingsState settings;
  final Dio dio;

  String endpoint(String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '${settings.baseUrl}/$cleanPath';
  }

  Future<void> testConnection() async {
    final validSettings = settings.validated();
    try {
      await dio.get<void>('${validSettings.baseUrl}/models');
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

  static AppException mapException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const AppException(
          AppErrorCode.networkTimeout,
          '请求超时，请检查网络后重试。',
        );
      case DioExceptionType.connectionError:
        return const AppException(
          AppErrorCode.serviceUnavailable,
          '无法连接 API 服务，请检查地址和网络。',
        );
      case DioExceptionType.cancel:
        return const AppException(AppErrorCode.unknown, '请求已取消。');
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == 401 || status == 403) {
          return const AppException(
            AppErrorCode.unauthorized,
            'API Key 无效或无权访问该服务。',
          );
        }
        if (status == 413) {
          return const AppException(
            AppErrorCode.fileTooLarge,
            '上传文件超过服务允许的大小。',
          );
        }
        if (status == 429) {
          return const AppException(
            AppErrorCode.rateLimited,
            '请求过于频繁或额度不足，请稍后重试。',
          );
        }
        if (status != null && status >= 500) {
          return const AppException(
            AppErrorCode.serviceUnavailable,
            'API 服务暂时不可用，请稍后重试。',
          );
        }
        return AppException(
          AppErrorCode.serviceUnavailable,
          status == 404
              ? 'API 地址不兼容：未找到请求接口。'
              : 'API 请求失败${status == null ? '' : '（$status）'}。',
        );
      case DioExceptionType.badCertificate:
        return const AppException(
          AppErrorCode.serviceUnavailable,
          'API 服务的 HTTPS 证书无效。',
        );
      case DioExceptionType.unknown:
        return const AppException(
          AppErrorCode.unknown,
          '请求失败，请稍后重试。',
        );
    }
  }
}
