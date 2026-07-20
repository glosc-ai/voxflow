import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/dio_client.dart';
import '../models/transcription_result.dart';
import 'audio_file_validator.dart';

typedef UploadProgressCallback = void Function(double progress);

class WhisperApiService {
  const WhisperApiService(
    this._client, {
    AudioFileValidator validator = const AudioFileValidator(),
  }) : _validator = validator;

  final DioClient _client;
  final AudioFileValidator _validator;

  Future<TranscriptionResult> transcribe(
    File file, {
    UploadProgressCallback? onUploadProgress,
  }) async {
    final settings = _client.settings.validated();
    await _validator.validate(file);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'model': settings.sttModel,
        'response_format': 'verbose_json',
        'timestamp_granularities[]': 'segment',
      });
      final response = await _client.dio.post<Object?>(
        _client.endpoint('audio/transcriptions'),
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) {
            onUploadProgress?.call((sent / total).clamp(0, 1));
          }
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw const AppException(
          AppErrorCode.serviceUnavailable,
          '转录服务返回了无法识别的数据。',
        );
      }
      final json = data.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final result = TranscriptionResult.fromJson(json);
      if (result.text.isEmpty) {
        throw const AppException(
          AppErrorCode.serviceUnavailable,
          '转录服务未返回文字。',
        );
      }
      return result;
    } on DioException catch (error) {
      throw DioClient.mapException(error);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.unknown,
        '音频转录失败，请稍后重试。',
      );
    }
  }
}
